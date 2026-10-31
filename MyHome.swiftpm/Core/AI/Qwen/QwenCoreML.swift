// MLState（KV キャッシュの状態）は iOS 18 SDK からの API。iOS 17 SDK の Swift Playgrounds（Swift 5.10）ではビルドから外す
#if canImport(CoreML) && compiler(>=6.0)
import Accelerate
import CoreML
import Foundation

/// Core ML に変換した Qwen2.5-0.5B-Instruct を動かす（追加フェーズ A）。モデルは 9 つ（埋め込み・層 4 つずつ × 6・
/// 出力を語彙の前半と後半の 2 つ）で、層の KV キャッシュは Core ML の状態（MLState）に持つ。そのため iOS 18 / macOS 15 以降でだけ使える。
/// 変換は scripts/coreml/convert_qwen.py。入出力の名前と形はそこで決めている。
/// 1 つの生成が終わるまで次の feed を呼ばない（QwenCoreMLSession が順番を守る）。
@available(iOS 18.0, macOS 15.0, *)
final class QwenCoreMLEngine: @unchecked Sendable {
    static let names: [String] = QwenModelManifest.packages
    static let maximumContext: Int = 2048
    static let maximumQuery: Int = 512
    /// float16 の -10000（見てはいけない位置の値。scripts/coreml の causal_mask と同じ）。
    private static let maskedBits: UInt16 = 0xF0E2

    private let embedding: MLModel
    private let layers: [MLModel]
    /// 出力（語彙を分けたもの。順につなぐと 151,936 個の logits になる）。
    private let heads: [MLModel]
    private var states: [MLState]
    /// KV キャッシュに入っているトークンの数。
    private(set) var length: Int = 0

    /// compiledDirectory の中の <名前>.mlmodelc を読む。
    init(compiledDirectory: URL, computeUnits: MLComputeUnits = .cpuAndGPU) throws {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = computeUnits
        func load(_ name: String) throws -> MLModel {
            let url: URL = compiledDirectory.appendingPathComponent(name + ".mlmodelc", isDirectory: true)
            return try MLModel(contentsOf: url, configuration: configuration)
        }
        embedding = try load(QwenModelManifest.embeddingPackage)
        layers = try QwenModelManifest.layerPackages.map(load)
        heads = try QwenModelManifest.headPackages.map(load)
        states = layers.map { (model: MLModel) -> MLState in model.makeState() }
    }

    /// KV キャッシュを空にする（新しい質問の前）。
    func reset() {
        states = layers.map { (model: MLModel) -> MLState in model.makeState() }
        length = 0
    }

    /// トークンを入れて、最後の位置の logits（151,936 個）を返す。長い時は 512 個ずつに分けて入れる。
    func feed(_ tokens: [Int]) throws -> [Float] {
        guard !tokens.isEmpty else { throw QwenCoreMLError.emptyInput }
        var logits: [Float] = []
        var start: Int = 0
        while start < tokens.count {
            let end: Int = min(start + QwenCoreMLEngine.maximumQuery, tokens.count)
            logits = try feedChunk(Array(tokens[start..<end]))
            start = end
        }
        return logits
    }

    private func feedChunk(_ tokens: [Int]) throws -> [Float] {
        guard length + tokens.count <= QwenCoreMLEngine.maximumContext else {
            throw QwenCoreMLError.contextFull
        }
        var hidden: MLMultiArray = try output(
            of: embedding, inputs: ["input_ids": try QwenCoreMLEngine.ids(tokens)], name: "hidden", state: nil
        )
        let positions: MLMultiArray = try QwenCoreMLEngine.positions(from: length, count: tokens.count)
        let mask: MLMultiArray = try QwenCoreMLEngine.mask(count: tokens.count, past: length)
        for (model, state) in zip(layers, states) {
            let inputs: [String: MLMultiArray] = ["hidden": hidden, "position_ids": positions, "causal_mask": mask]
            hidden = try output(of: model, inputs: inputs, name: "output_hidden", state: state)
        }
        length += tokens.count
        var logits: [Float] = []
        logits.reserveCapacity(151_936)
        for head in heads {
            let part: MLMultiArray = try output(of: head, inputs: ["hidden": hidden], name: "logits", state: nil)
            logits.append(contentsOf: QwenCoreMLEngine.floats(part))
        }
        return logits
    }

    private func output(of model: MLModel, inputs: [String: MLMultiArray], name: String, state: MLState?) throws -> MLMultiArray {
        let values: [String: Any] = inputs.mapValues { (array: MLMultiArray) -> Any in MLFeatureValue(multiArray: array) }
        let provider = try MLDictionaryFeatureProvider(dictionary: values)
        let result: MLFeatureProvider
        if let state {
            result = try model.prediction(from: provider, using: state)
        } else {
            result = try model.prediction(from: provider)
        }
        guard let array = result.featureValue(for: name)?.multiArrayValue else {
            throw QwenCoreMLError.missingOutput(name)
        }
        return array
    }

    // MARK: - 入力の作り方

    private static func ids(_ tokens: [Int]) throws -> MLMultiArray {
        let array = try MLMultiArray(shape: [1, NSNumber(value: tokens.count)], dataType: .int32)
        let pointer: UnsafeMutablePointer<Int32> = array.dataPointer.bindMemory(to: Int32.self, capacity: tokens.count)
        for (index, token) in tokens.enumerated() {
            pointer[index] = Int32(token)
        }
        return array
    }

    private static func positions(from start: Int, count: Int) throws -> MLMultiArray {
        let array = try MLMultiArray(shape: [NSNumber(value: count)], dataType: .int32)
        let pointer: UnsafeMutablePointer<Int32> = array.dataPointer.bindMemory(to: Int32.self, capacity: count)
        for index in 0..<count {
            pointer[index] = Int32(start + index)
        }
        return array
    }

    /// (1, 1, count, past + count)。行 r は、past + r より後ろを隠す。
    private static func mask(count: Int, past: Int) throws -> MLMultiArray {
        let end: Int = past + count
        let shape: [NSNumber] = [1, 1, NSNumber(value: count), NSNumber(value: end)]
        let array = try MLMultiArray(shape: shape, dataType: .float16)
        let pointer: UnsafeMutablePointer<UInt16> = array.dataPointer.bindMemory(to: UInt16.self, capacity: count * end)
        for row in 0..<count {
            for column in 0..<end {
                pointer[row * end + column] = column > past + row ? maskedBits : 0
            }
        }
        return array
    }

    /// float16 の logits を Float にする（Accelerate。Intel の Mac でも動くように Float16 型は使わない）。
    private static func floats(_ array: MLMultiArray) -> [Float] {
        let count: Int = array.count
        var result: [Float] = Array(repeating: 0, count: count)
        if array.dataType == .float32 {
            let pointer: UnsafeMutablePointer<Float> = array.dataPointer.bindMemory(to: Float.self, capacity: count)
            for index in 0..<count {
                result[index] = pointer[index]
            }
            return result
        }
        var source = vImage_Buffer(data: array.dataPointer, height: 1, width: vImagePixelCount(count), rowBytes: count * 2)
        result.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) in
            var destination = vImage_Buffer(data: raw.baseAddress, height: 1, width: vImagePixelCount(count), rowBytes: count * 4)
            _ = vImageConvert_Planar16FtoPlanarF(&source, &destination, 0)
        }
        return result
    }
}

enum QwenCoreMLError: Error, Hashable, Sendable {
    case emptyInput
    case contextFull
    case missingOutput(String)

    var message: String {
        switch self {
        case .emptyInput: return "入力が空です。"
        case .contextFull: return "会話が長すぎます（\(QwenCoreMLEngine.maximumContextText)）。「新しい会話」で始め直してください。"
        case .missingOutput(let name): return "モデルの出力（\(name)）がありません。モデルのファイルが正しくない可能性があります。"
        }
    }
}

extension QwenCoreMLEngine {
    static var maximumContextText: String {
        "\(maximumContext) トークンまで"
    }
}

/// 1 つの会話。履歴を覚えていて、質問のたびに会話全体を入れ直して答える（KV キャッシュは質問ごとに作り直す）。
@available(iOS 18.0, macOS 15.0, *)
actor QwenCoreMLSession {
    private let engine: QwenCoreMLEngine
    private let tokenizer: QwenTokenizer
    private let options: QwenSamplingOptions
    private var history: [LLMMessage] = []
    private var random: SeededRandom

    init(engine: QwenCoreMLEngine, tokenizer: QwenTokenizer, options: QwenSamplingOptions = QwenSamplingOptions(), seed: UInt64) {
        self.engine = engine
        self.tokenizer = tokenizer
        self.options = options
        random = SeededRandom(seed: seed)
    }

    /// 質問に答える。できた文字は少しずつ emit に渡す。取り消されたら、そこまでの答えを履歴に残して止める。
    func respond(to prompt: String, maxTokens: Int, emit: @Sendable (String) -> Void) throws {
        history.append(LLMMessage(role: .user, text: prompt, isStub: false))
        let room: Int = max(QwenCoreMLEngine.maximumContext - maxTokens, 256)
        let tokens: [Int] = QwenPrompt.tokens(system: QwenPrompt.defaultSystem, messages: history, tokenizer: tokenizer, limit: room)
        var generated: [Int] = []
        defer {
            history.append(LLMMessage(role: .assistant, text: tokenizer.decode(generated), isStub: false))
        }
        engine.reset()
        var logits: [Float] = try engine.feed(tokens)
        var decoder = QwenStreamDecoder()
        for _ in 0..<maxTokens {
            try Task.checkCancellation()
            let token: Int = QwenSampler.next(logits: logits, previous: tokens + generated, options: options, random: &random)
            if token == QwenTokenizer.imEnd || token == QwenTokenizer.endOfText {
                break
            }
            generated.append(token)
            let text: String = decoder.append(tokenizer.bytes(for: [token]))
            if !text.isEmpty {
                emit(text)
            }
            if engine.length >= QwenCoreMLEngine.maximumContext {
                break
            }
            logits = try engine.feed([token])
        }
        let rest: String = decoder.finish()
        if !rest.isEmpty {
            emit(rest)
        }
    }
}

/// 読み込んだ Qwen（LoadedLLM）。
@available(iOS 18.0, macOS 15.0, *)
struct QwenLoadedLLM: LoadedLLM {
    let session: QwenCoreMLSession

    func generate(_ request: LLMGenerationRequest) -> AsyncThrowingStream<String, Error> {
        let session: QwenCoreMLSession = self.session
        return AsyncThrowingStream { (continuation: AsyncThrowingStream<String, Error>.Continuation) in
            let task = Task {
                do {
                    try await session.respond(to: request.prompt, maxTokens: request.maxTokens) { (text: String) in
                        continuation.yield(text)
                    }
                    continuation.finish()
                } catch let error as QwenCoreMLError {
                    continuation.finish(throwing: LLMError(message: error.message))
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { (_: AsyncThrowingStream<String, Error>.Continuation.Termination) in
                task.cancel()
            }
        }
    }

    func unload() async {}
}

/// Core ML の Qwen のプロバイダー。directory は入れたモデルのフォルダ（compiled/ と vocab.json・merges.txt）。
@available(iOS 18.0, macOS 15.0, *)
struct QwenCoreMLProvider: LocalLLMProvider {
    static let descriptor = LLMModelDescriptor(id: "qwen2.5-0.5b-coreml", displayName: "Qwen2.5 0.5B（Core ML）", format: .coreML)
    let directory: URL
    var computeUnits: MLComputeUnits = .cpuAndGPU

    var descriptor: LLMModelDescriptor {
        QwenCoreMLProvider.descriptor
    }

    func load() async throws -> any LoadedLLM {
        let directory: URL = self.directory
        let units: MLComputeUnits = computeUnits
        let parts: (QwenCoreMLEngine, QwenTokenizer) = try await Task.detached(priority: .userInitiated) { () throws -> (QwenCoreMLEngine, QwenTokenizer) in
            let engine = try QwenCoreMLEngine(compiledDirectory: directory.appendingPathComponent("compiled", isDirectory: true), computeUnits: units)
            let tokenizer = try QwenTokenizer(directory: directory)
            return (engine, tokenizer)
        }.value
        let seed: UInt64 = UInt64(Date().timeIntervalSince1970 * 1000)
        return QwenLoadedLLM(session: QwenCoreMLSession(engine: parts.0, tokenizer: parts.1, seed: seed))
    }
}
#endif
