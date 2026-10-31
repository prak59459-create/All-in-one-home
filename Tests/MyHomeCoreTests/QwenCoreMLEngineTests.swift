#if canImport(CoreML) && compiler(>=6.0)
import CoreML
import Foundation
import XCTest
@testable import MyHomeCore

/// 追加フェーズ A: 変換した Core ML の Qwen を、アプリと同じ Swift のエンジンで動かす。
/// CI の Mac（.github/workflows/coreml-qwen.yml）で、QWEN_COREML_DIR に .mlpackage のフォルダを渡した時だけ動く。
/// Linux と、普段の CI では飛ばす（モデルがないため）。
final class QwenCoreMLEngineTests: XCTestCase {
    /// emit から受け取った文字を集める（別のタスクから呼ばれるのでロックで守る）。
    private final class Collected: @unchecked Sendable {
        private let lock = NSLock()
        private var parts: [String] = []

        func add(_ text: String) {
            lock.lock()
            parts.append(text)
            lock.unlock()
        }

        var text: String {
            lock.lock()
            defer { lock.unlock() }
            return parts.joined()
        }
    }

    func testTheSwiftEngineAnswersLikeTheReference() async throws {
        guard let folder = ProcessInfo.processInfo.environment["QWEN_COREML_DIR"] else {
            throw XCTSkip("QWEN_COREML_DIR がない（CI の coreml-qwen だけで動かす）")
        }
        guard #available(macOS 15.0, iOS 18.0, *) else {
            throw XCTSkip("Core ML の状態（MLState）は macOS 15 以降")
        }
        let compiled: URL = try await compile(URL(fileURLWithPath: folder))
        defer { try? FileManager.default.removeItem(at: compiled.deletingLastPathComponent()) }

        let loading = Date()
        let engine = try QwenCoreMLEngine(compiledDirectory: compiled)
        let tokenizer = try QwenTokenizer(directory: QwenTokenizerTests.modelDirectory)
        print("読み込み: \(String(format: "%.1f", Date().timeIntervalSince(loading))) 秒")

        // Python の確認（check_coreml.py）と同じ質問を、貪欲に答えさせる
        let question = LLMMessage(role: .user, text: "日本の首都はどこですか？", isStub: false)
        let prompt: [Int] = QwenPrompt.tokens(system: "You are a helpful assistant.", messages: [question], tokenizer: tokenizer)
        var random = SeededRandom(seed: 1)
        var logits: [Float] = try engine.feed(prompt)
        var generated: [Int] = []
        let started = Date()
        for _ in 0..<16 {
            let token: Int = QwenSampler.next(logits: logits, previous: prompt + generated, options: .greedy, random: &random)
            if token == QwenTokenizer.imEnd || token == QwenTokenizer.endOfText {
                break
            }
            generated.append(token)
            logits = try engine.feed([token])
        }
        let seconds: Double = max(Date().timeIntervalSince(started), 0.001)
        let text: String = tokenizer.decode(generated)
        print("Swift のエンジンの答え: \(text)（\(generated.count) トークン、\(String(format: "%.1f", Double(generated.count) / seconds)) トークン/秒）")
        XCTAssertTrue(text.contains("東京"), text)
        XCTAssertTrue(logits.allSatisfy { (value: Float) -> Bool in value.isFinite })

        // アプリと同じ会話の流れ（日本語の指示・少しずつ受け取る・2 回目は前の会話を覚えている）
        let session = QwenCoreMLSession(engine: engine, tokenizer: tokenizer, options: .greedy, seed: 1)
        let first = Collected()
        try await session.respond(to: "こんにちは。あなたは誰ですか？", maxTokens: 48) { (part: String) in first.add(part) }
        print("会話 1: \(first.text)")
        XCTAssertFalse(first.text.isEmpty)
        let second = Collected()
        try await session.respond(to: "今の答えを英語で短く言って。", maxTokens: 48) { (part: String) in second.add(part) }
        print("会話 2: \(second.text)")
        XCTAssertFalse(second.text.isEmpty)
    }

    /// アプリと同じく、端末の上で .mlpackage をコンパイルする（MLModel.compileModel）。
    @available(macOS 15.0, iOS 18.0, *)
    private func compile(_ folder: URL) async throws -> URL {
        let output: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("QwenCompiled-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("compiled", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for name in QwenCoreMLEngine.names {
            let started = Date()
            let source: URL = folder.appendingPathComponent(name + ".mlpackage", isDirectory: true)
            let compiled: URL = try await MLModel.compileModel(at: source)
            try FileManager.default.moveItem(at: compiled, to: output.appendingPathComponent(name + ".mlmodelc", isDirectory: true))
            print("コンパイル \(name): \(String(format: "%.1f", Date().timeIntervalSince(started))) 秒")
        }
        return output
    }
}
#endif
