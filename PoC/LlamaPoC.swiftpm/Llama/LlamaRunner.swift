import Foundation
import llama

/// llama.cpp の C API を、PoC に必要なだけ包む（llama.cpp b11998 の llama.h に合わせている）。
/// 読み込み・生成はメインスレッドの外から、1つずつ順番に呼ぶ（同時には使わない）。
final class LlamaRunner: @unchecked Sendable {
    enum RunnerError: Error, CustomStringConvertible {
        case modelLoadFailed
        case contextFailed
        case tokenizeFailed
        case promptTooLong(tokens: Int, limit: Int)
        case decodeFailed(Int32)

        var description: String {
            switch self {
            case .modelLoadFailed: return "モデルを読み込めませんでした（GGUF でない、壊れている、メモリが足りない、など）。"
            case .contextFailed: return "推論の準備（コンテキスト）を作れませんでした。メモリが足りない可能性があります。"
            case .tokenizeFailed: return "プロンプトをトークンに分けられませんでした。"
            case .promptTooLong(let tokens, let limit): return "プロンプトが長すぎます（\(tokens) トークン。生成の分を含めて \(limit) トークンまで）。"
            case .decodeFailed(let code): return "推論に失敗しました（llama_decode の戻り値 \(code)）。"
            }
        }
    }

    struct Stats: Sendable {
        let promptTokens: Int
        let generatedTokens: Int
        let promptSeconds: Double
        let generationSeconds: Double

        var tokensPerSecond: Double {
            generationSeconds > 0 ? Double(generatedTokens) / generationSeconds : 0
        }
    }

    /// llama_backend_init はプロセスで1回だけ呼ぶ。
    private static let backend: Void = {
        llama_backend_init()
    }()

    private let model: OpaquePointer
    private let context: OpaquePointer
    private let vocab: OpaquePointer
    private let contextLength: Int
    /// 1回の llama_decode に渡せるトークン数の上限（n_batch）。長いプロンプトはこの長さに分けて渡す。
    private let batchSize: Int = 512

    init(modelPath: String, contextLength: UInt32 = 2048) throws {
        _ = LlamaRunner.backend
        var modelParams = llama_model_default_params()
        // すべての層を GPU（Metal）に載せる。載らない分は llama.cpp が CPU に回す
        modelParams.n_gpu_layers = 99
        guard let loadedModel = llama_model_load_from_file(modelPath, modelParams) else {
            throw RunnerError.modelLoadFailed
        }
        var contextParams = llama_context_default_params()
        contextParams.n_ctx = contextLength
        contextParams.n_batch = UInt32(batchSize)
        let threads: Int32 = Int32(max(1, min(4, ProcessInfo.processInfo.activeProcessorCount - 1)))
        contextParams.n_threads = threads
        contextParams.n_threads_batch = threads
        guard let createdContext = llama_init_from_model(loadedModel, contextParams) else {
            llama_model_free(loadedModel)
            throw RunnerError.contextFailed
        }
        guard let loadedVocab = llama_model_get_vocab(loadedModel) else {
            llama_free(createdContext)
            llama_model_free(loadedModel)
            throw RunnerError.modelLoadFailed
        }
        model = loadedModel
        context = createdContext
        vocab = loadedVocab
        self.contextLength = Int(contextLength)
    }

    deinit {
        llama_free(context)
        llama_model_free(model)
    }

    /// プロンプトにモデルのチャットの形式を付けて、続きを生成する（1問1答。前の会話は消す）。
    /// onPiece に増えた文字を渡し、false が返ったら止める。
    func generate(prompt: String, maxTokens: Int, onPiece: (String) -> Bool) throws -> Stats {
        llama_memory_clear(llama_get_memory(context), true)
        var tokens: [llama_token] = try tokenize(applyChatTemplate(prompt))
        // コンテキストからあふれると llama_decode が失敗するので、生成の分を1トークン以上残す
        guard tokens.count < contextLength else {
            throw RunnerError.promptTooLong(tokens: tokens.count, limit: contextLength)
        }
        let tokenLimit: Int = min(maxTokens, contextLength - tokens.count)
        // サンプラーの組み方は llama.cpp の examples/simple-chat と同じ（min-p → 温度 → 乱数で選ぶ）
        let sampler = llama_sampler_chain_init(llama_sampler_chain_default_params())
        llama_sampler_chain_add(sampler, llama_sampler_init_min_p(0.05, 1))
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.8))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(UInt32.random(in: 0..<UInt32.max)))
        defer { llama_sampler_free(sampler) }

        let promptStart: Date = Date()
        try decodePrompt(&tokens)
        let promptSeconds: Double = Date().timeIntervalSince(promptStart)

        var accumulator = UTF8Accumulator()
        var generated: Int = 0
        let generationStart: Date = Date()
        while generated < tokenLimit {
            var token: llama_token = llama_sampler_sample(sampler, context, -1)
            if llama_vocab_is_eog(vocab, token) {
                break
            }
            generated += 1
            let text: String = accumulator.append(pieceBytes(token))
            if !text.isEmpty && !onPiece(text) {
                break
            }
            let status: Int32 = withUnsafeMutablePointer(to: &token) { (pointer: UnsafeMutablePointer<llama_token>) -> Int32 in
                llama_decode(context, llama_batch_get_one(pointer, 1))
            }
            guard status == 0 else { throw RunnerError.decodeFailed(status) }
        }
        let rest: String = accumulator.flush()
        if !rest.isEmpty {
            _ = onPiece(rest)
        }
        return Stats(
            promptTokens: tokens.count,
            generatedTokens: generated,
            promptSeconds: promptSeconds,
            generationSeconds: Date().timeIntervalSince(generationStart)
        )
    }

    /// プロンプトを n_batch ずつに分けて読ませる。
    private func decodePrompt(_ tokens: inout [llama_token]) throws {
        let batchSize: Int = self.batchSize
        let status: Int32 = tokens.withUnsafeMutableBufferPointer { (buffer: inout UnsafeMutableBufferPointer<llama_token>) -> Int32 in
            guard let base = buffer.baseAddress else { return 0 }
            var start: Int = 0
            while start < buffer.count {
                let count: Int = min(batchSize, buffer.count - start)
                let result: Int32 = llama_decode(context, llama_batch_get_one(base + start, Int32(count)))
                if result != 0 {
                    return result
                }
                start += count
            }
            return 0
        }
        guard status == 0 else { throw RunnerError.decodeFailed(status) }
    }

    private func tokenize(_ text: String) throws -> [llama_token] {
        let length: Int32 = Int32(text.utf8.count)
        let capacity: Int = Int(length) + 8
        var tokens: [llama_token] = [llama_token](repeating: 0, count: capacity)
        let count: Int32 = llama_tokenize(vocab, text, length, &tokens, Int32(capacity), true, true)
        guard count > 0 else { throw RunnerError.tokenizeFailed }
        return Array(tokens.prefix(Int(count)))
    }

    /// トークン1つ分のバイト列（文字の途中で切れていることがある）。
    private func pieceBytes(_ token: llama_token) -> [UInt8] {
        var buffer: [CChar] = [CChar](repeating: 0, count: 64)
        var count: Int32 = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, false)
        if count < 0 {
            buffer = [CChar](repeating: 0, count: Int(-count))
            count = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, false)
        }
        guard count > 0 else { return [] }
        return buffer.prefix(Int(count)).map { (value: CChar) -> UInt8 in UInt8(bitPattern: value) }
    }

    /// モデルに入っているチャットの形式（テンプレート）で包む。テンプレートがなければそのまま。
    private func applyChatTemplate(_ prompt: String) -> String {
        guard let template = llama_model_chat_template(model, nil) else { return prompt }
        return prompt.withCString { (content: UnsafePointer<CChar>) -> String in
            "user".withCString { (role: UnsafePointer<CChar>) -> String in
                var message = llama_chat_message(role: role, content: content)
                var buffer: [CChar] = [CChar](repeating: 0, count: prompt.utf8.count * 2 + 512)
                var length: Int32 = llama_chat_apply_template(template, &message, 1, true, &buffer, Int32(buffer.count))
                if length > Int32(buffer.count) {
                    buffer = [CChar](repeating: 0, count: Int(length) + 1)
                    length = llama_chat_apply_template(template, &message, 1, true, &buffer, Int32(buffer.count))
                }
                guard length > 0 else { return prompt }
                let bytes: [UInt8] = buffer.prefix(Int(length)).map { (value: CChar) -> UInt8 in UInt8(bitPattern: value) }
                return String(decoding: bytes, as: UTF8.self)
            }
        }
    }
}

/// トークンの区切りが文字（UTF-8）の途中になることがあるので、完成した文字の分だけを文字列にする。
struct UTF8Accumulator {
    private var pending: [UInt8] = []

    mutating func append(_ bytes: [UInt8]) -> String {
        pending.append(contentsOf: bytes)
        let cut: Int = UTF8Accumulator.completePrefixLength(pending)
        let text: String = String(decoding: pending[0..<cut], as: UTF8.self)
        pending.removeFirst(cut)
        return text
    }

    mutating func flush() -> String {
        let text: String = String(decoding: pending, as: UTF8.self)
        pending = []
        return text
    }

    /// 最後の文字が途中で切れていたら、その手前までの長さ。切れていなければ全体の長さ。
    static func completePrefixLength(_ bytes: [UInt8]) -> Int {
        var index: Int = bytes.count - 1
        var continuations: Int = 0
        while index >= 0 && continuations < 3 && bytes[index] & 0xC0 == 0x80 {
            continuations += 1
            index -= 1
        }
        guard index >= 0 else { return bytes.count }
        let lead: UInt8 = bytes[index]
        let needed: Int
        if lead & 0x80 == 0 {
            needed = 1
        } else if lead & 0xE0 == 0xC0 {
            needed = 2
        } else if lead & 0xF0 == 0xE0 {
            needed = 3
        } else if lead & 0xF8 == 0xF0 {
            needed = 4
        } else {
            needed = 1
        }
        return bytes.count - index < needed ? index : bytes.count
    }
}
