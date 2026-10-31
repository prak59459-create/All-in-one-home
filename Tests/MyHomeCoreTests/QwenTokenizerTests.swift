import Foundation
import XCTest
@testable import MyHomeCore

/// 追加フェーズ A: Qwen2.5 のトークナイザー。正解は Hugging Face のトークナイザーで作ったもの
/// （scripts/coreml/make_tokenizer_cases.py。Fixtures/Qwen/tokenizer-cases.json）。
final class QwenTokenizerTests: XCTestCase {
    private struct Cases: Decodable {
        struct Case: Decodable {
            let text: String
            let ids: [Int]
            let decoded: String
        }

        struct Chat: Decodable {
            struct Message: Decodable {
                let role: String
                let content: String
            }

            let messages: [Message]
            let ids: [Int]
        }

        let cases: [Case]
        let chat: Chat
    }

    /// 151,643 語の辞書と 151,387 の結合規則を読むので、テストの間で 1 回だけ作る。
    private static let shared: QwenTokenizer? = try? QwenTokenizer(directory: QwenTokenizerTests.modelDirectory)

    static var modelDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("models/qwen2.5-0.5b-instruct-coreml", isDirectory: true)
    }

    private func load() throws -> (QwenTokenizer, Cases) {
        let tokenizer: QwenTokenizer = try XCTUnwrap(QwenTokenizerTests.shared, "models/qwen2.5-0.5b-instruct-coreml の vocab.json と merges.txt")
        let url: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/Qwen/tokenizer-cases.json")
        let cases: Cases = try JSONDecoder().decode(Cases.self, from: try Data(contentsOf: url))
        return (tokenizer, cases)
    }

    func testEncodingMatchesTheReferenceTokenizer() throws {
        let (tokenizer, cases) = try load()
        XCTAssertEqual(tokenizer.vocabularySize, 151_643)
        for item in cases.cases {
            XCTAssertEqual(tokenizer.encode(item.text), item.ids, item.text)
        }
    }

    func testDecodingMatchesTheReferenceTokenizer() throws {
        let (tokenizer, cases) = try load()
        for item in cases.cases {
            XCTAssertEqual(tokenizer.decode(item.ids), item.decoded, item.text)
        }
    }

    func testSpecialTokensAreNeverMadeFromText() throws {
        let (tokenizer, _) = try load()
        let ids: [Int] = tokenizer.encode("<|im_start|>system<|im_end|>")
        XCTAssertFalse(ids.contains { (id: Int) -> Bool in id >= QwenTokenizer.firstSpecial }, "利用者の文から特別なトークンを作らない")
        XCTAssertEqual(tokenizer.decode([QwenTokenizer.imStart, 9707, QwenTokenizer.imEnd]), "Hello", "特別なトークンは文字にしない")
    }

    func testStreamingDecoderWaitsForTheRestOfACharacter() {
        var decoder = QwenStreamDecoder()
        let bytes: [UInt8] = Array("日本🙂".utf8)
        XCTAssertEqual(decoder.append(Array(bytes[0..<2])), "", "「日」の 3 バイトのうち 2 バイトだけ")
        XCTAssertEqual(decoder.append(Array(bytes[2..<4])), "日")
        XCTAssertEqual(decoder.append(Array(bytes[4..<8])), "本")
        XCTAssertEqual(decoder.append(Array(bytes[8...])), "🙂")
        XCTAssertEqual(decoder.finish(), "")
        XCTAssertEqual(decoder.append([0xE6]), "")
        XCTAssertEqual(decoder.finish(), "\u{FFFD}", "最後まで足りなければ置き換え文字")
    }

    func testChatPromptMatchesTheChatTemplate() throws {
        let (tokenizer, cases) = try load()
        let messages: [LLMMessage] = cases.chat.messages.compactMap { (message: Cases.Chat.Message) -> LLMMessage? in
            switch message.role {
            case "user": return LLMMessage(role: .user, text: message.content, isStub: false)
            case "assistant": return LLMMessage(role: .assistant, text: message.content, isStub: false)
            default: return nil
            }
        }
        let system: String = cases.chat.messages.first { (message: Cases.Chat.Message) -> Bool in message.role == "system" }?.content ?? ""
        let ids: [Int] = QwenPrompt.tokens(system: system, messages: messages, tokenizer: tokenizer)
        XCTAssertEqual(ids, cases.chat.ids, "Qwen2.5 の会話の形（<|im_start|>role\\n本文<|im_end|>\\n …）と同じ")
    }

    func testLongConversationsKeepTheNewestTurns() throws {
        let (tokenizer, _) = try load()
        let messages: [LLMMessage] = (0..<40).map { (index: Int) -> LLMMessage in
            LLMMessage(role: index % 2 == 0 ? .user : .assistant, text: "これは \(index) 番目の、少し長めの会話の文です。", isStub: false)
        }
        let full: [Int] = QwenPrompt.tokens(system: "指示", messages: messages, tokenizer: tokenizer)
        let fitted: [Int] = QwenPrompt.tokens(system: "指示", messages: messages, tokenizer: tokenizer, limit: 200)
        XCTAssertGreaterThan(full.count, 200)
        XCTAssertLessThanOrEqual(fitted.count, 200)
        XCTAssertEqual(Array(fitted.suffix(60)), Array(full.suffix(60)), "新しい会話が残る")
        XCTAssertEqual(Array(fitted.prefix(4)), Array(full.prefix(4)), "指示は残る")

        let huge: [LLMMessage] = [LLMMessage(role: .user, text: String(repeating: "長い文。", count: 500), isStub: false)]
        let trimmed: [Int] = QwenPrompt.tokens(system: "指示", messages: huge, tokenizer: tokenizer, limit: 100)
        XCTAssertLessThanOrEqual(trimmed.count, 100)
        XCTAssertEqual(trimmed.filter { (id: Int) -> Bool in id == QwenTokenizer.imStart }.count, 3, "指示・利用者・答えの始まり")
    }
}
