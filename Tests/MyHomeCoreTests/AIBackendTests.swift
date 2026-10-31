import Foundation
import XCTest
@testable import MyHomeCore

/// Phase 6: 端末内モデルの組み込み（差分の受け渡し、利用者向けのエラー、会話のリセット、AI の項目の状態）。
/// Foundation Models そのものは iOS 26 の端末でしか動かないため、ここでは境界の部分だけを確かめる。
final class AIBackendTests: XCTestCase {
    /// 決まった文を返すか、決まったエラーで失敗するモデル。
    private struct ScriptedModel: LoadedLLM {
        let chunks: [String]
        let failure: LLMError?

        func generate(_ request: LLMGenerationRequest) -> AsyncThrowingStream<String, Error> {
            let chunks: [String] = self.chunks
            let failure: LLMError? = self.failure
            return AsyncThrowingStream { continuation in
                for chunk in chunks {
                    continuation.yield(chunk)
                }
                continuation.finish(throwing: failure)
            }
        }

        func unload() async {}
    }

    private struct ScriptedProvider: LocalLLMProvider {
        let descriptor = LLMModelDescriptor(id: "scripted", displayName: "台本", format: .systemModel)
        let model: ScriptedModel
        var loadFailure: LLMError? = nil

        func load() async throws -> any LoadedLLM {
            if let loadFailure {
                throw loadFailure
            }
            return model
        }
    }

    func testDeltaTurnsSnapshotsIntoAppendedText() {
        XCTAssertEqual(LLMStreamText.delta(from: "", to: "こん"), "こん")
        XCTAssertEqual(LLMStreamText.delta(from: "こん", to: "こんにちは"), "にちは")
        XCTAssertEqual(LLMStreamText.delta(from: "こんにちは", to: "こんにちは"), "")
        XCTAssertEqual(LLMStreamText.delta(from: "abc", to: "abd"), "\nabd", "途中が書き換わったら、区切って全文を出す")
        var shown: String = ""
        var previous: String = ""
        for snapshot in ["今日", "今日は", "今日は晴れ", "今日は晴れです。"] {
            shown += LLMStreamText.delta(from: previous, to: snapshot)
            previous = snapshot
        }
        XCTAssertEqual(shown, "今日は晴れです。")
    }

    func testInstructionsStateWhatTheAssistantCannotDo() {
        XCTAssertTrue(AIInstructions.text.contains("操作できず"))
        XCTAssertTrue(AIInstructions.text.contains("インターネット"))
    }

    @MainActor
    func testFriendlyErrorsAreShownAsIs() async {
        let failing = ScriptedProvider(
            model: ScriptedModel(chunks: [], failure: nil),
            loadFailure: LLMError(message: "Apple Intelligence がオフになっています。")
        )
        let session = LLMSessionController()
        await session.load(using: failing)
        XCTAssertEqual(session.errorMessage, "Apple Intelligence がオフになっています。", "理由をそのまま見せる")
        XCTAssertEqual(session.phase, .notLoaded)

        let overflowing = ScriptedProvider(model: ScriptedModel(chunks: ["途中まで"], failure: LLMError(message: "会話が長くなりすぎました。")))
        await session.load(using: overflowing)
        session.send("質問")
        await session.waitForGeneration()
        XCTAssertEqual(session.errorMessage, "会話が長くなりすぎました。")
        XCTAssertEqual(session.messages.last?.text, "途中まで")
        XCTAssertEqual(session.messages.last?.isStub, false, "端末内モデルの回答はスタブと表示しない")
        XCTAssertEqual(session.phase, .ready)
    }

    @MainActor
    func testClearConversationKeepsTheModel() async {
        let session = LLMSessionController()
        await session.load(using: ScriptedProvider(model: ScriptedModel(chunks: ["はい"], failure: nil)))
        session.send("こんにちは")
        await session.waitForGeneration()
        XCTAssertEqual(session.messages.count, 2)
        session.clearConversation()
        XCTAssertTrue(session.messages.isEmpty)
        XCTAssertEqual(session.phase, .ready)
    }

    @MainActor
    func testClearConversationWaitsWhileGenerating() async {
        let log = CallLog()
        let session = LLMSessionController()
        await session.load(using: SpyProvider(log: log))
        session.send("終わらない質問")
        XCTAssertEqual(session.phase, .generating)
        session.clearConversation()
        XCTAssertEqual(session.messages.count, 2, "生成中は消さない")
        await session.unload()
    }

    func testAIItemShowsStubOnlyWithoutSystemModel() {
        let original: Bool = LLMRuntime.isSystemModelAvailable
        defer { LLMRuntime.isSystemModelAvailable = original }
        let item: HomeItem = DefaultLayout.item(for: .aiAssistant)

        LLMRuntime.isSystemModelAvailable = false
        XCTAssertEqual(AppFeature.aiAssistant.state, .stub)
        XCTAssertEqual(item.badge, .stub, "端末内モデルが使えない端末では「スタブ」の印を付ける")
        XCTAssertEqual(FeatureStatusCatalog.entries().first { (entry: FeatureStatusEntry) -> Bool in entry.id == "ai" }?.state, .stub)

        LLMRuntime.isSystemModelAvailable = true
        XCTAssertEqual(AppFeature.aiAssistant.state, .available)
        XCTAssertNil(item.badge)
        XCTAssertEqual(LaunchPlanner.plan(for: item.action), .openFeature(.aiAssistant))
        XCTAssertEqual(FeatureStatusCatalog.entries().first { (entry: FeatureStatusEntry) -> Bool in entry.id == "ai" }?.state, .available)
    }

    func testAvailabilityCarriesAReason() {
        XCTAssertTrue(LLMAvailability.available.isAvailable)
        XCTAssertNil(LLMAvailability.available.reason)
        let unavailable = LLMAvailability.unavailable("iPadOS 26 以降が必要です。")
        XCTAssertFalse(unavailable.isAvailable)
        XCTAssertEqual(unavailable.reason, "iPadOS 26 以降が必要です。")
    }
}
