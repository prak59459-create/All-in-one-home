import XCTest
@testable import MyHomeCore

final class LLMSessionControllerTests: XCTestCase {
    /// セッションを作っただけでは何も読み込まない（ホーム起動時や AI 画面を開いただけで重い処理が走らない）。
    @MainActor
    func testCreatingSessionLoadsNothing() async {
        let session = LLMSessionController()
        XCTAssertEqual(session.phase, .notLoaded)
        XCTAssertNil(session.loadedModel)
        XCTAssertTrue(session.messages.isEmpty)
    }

    @MainActor
    func testModelIsLoadedOnlyWhenRequested() async {
        let log = CallLog()
        let provider = SpyProvider(log: log)
        let session = LLMSessionController()
        XCTAssertEqual(log.count(of: "load"), 0)

        await session.load(using: provider)
        XCTAssertEqual(log.count(of: "load"), 1)
        XCTAssertEqual(session.phase, .ready)
        XCTAssertEqual(session.loadedModel?.id, "spy")

        await session.load(using: provider)
        XCTAssertEqual(log.count(of: "load"), 1, "読み込み済みなら二重に読み込まない")
    }

    @MainActor
    func testSendBeforeLoadIsIgnored() async {
        let session = LLMSessionController()
        session.send("こんにちは")
        XCTAssertTrue(session.messages.isEmpty)
        XCTAssertEqual(session.phase, .notLoaded)
    }

    @MainActor
    func testStubReplyIsClearlyLabeled() async {
        let session = LLMSessionController()
        await session.load(using: StubLocalLLMProvider(chunkDelay: .zero))
        session.send("  こんにちは  ")
        await session.waitForGeneration()

        XCTAssertEqual(session.phase, .ready)
        XCTAssertEqual(session.messages.count, 2)
        XCTAssertEqual(session.messages[0].text, "こんにちは")
        XCTAssertTrue(session.messages[1].isStub)
        XCTAssertTrue(session.messages[1].text.hasPrefix(StubLoadedLLM.replyPrefix))
        XCTAssertTrue(session.messages[1].text.contains("5 文字"))
    }

    @MainActor
    func testCancelStopsGenerationButKeepsModel() async {
        let log = CallLog()
        let session = LLMSessionController()
        await session.load(using: SpyProvider(log: log))
        session.send("止めるテスト")
        XCTAssertEqual(session.phase, .generating)

        session.cancelGeneration()
        await session.waitForGeneration()

        XCTAssertEqual(log.count(of: "terminated"), 1, "生成側に取り消しが伝わること")
        XCTAssertEqual(session.phase, .ready)
        XCTAssertNotNil(session.loadedModel)
        XCTAssertTrue(session.messages.last?.text.hasSuffix(LLMSessionController.interruptedSuffix) ?? false)
    }

    /// 画面を離れたら推論を続けず、モデルも解放する。
    @MainActor
    func testUnloadStopsGenerationAndReleasesModel() async {
        let log = CallLog()
        let session = LLMSessionController()
        await session.load(using: SpyProvider(log: log))
        session.send("続かないこと")

        await session.unload()
        await session.waitForGeneration()

        XCTAssertEqual(log.count(of: "unload"), 1)
        XCTAssertEqual(log.count(of: "terminated"), 1)
        XCTAssertEqual(session.phase, .notLoaded)
        XCTAssertNil(session.loadedModel)
    }

    /// 読み込み中に画面を離れた場合、読み込み完了後すぐに解放し、セッションには残さない。
    @MainActor
    func testUnloadDuringLoadingDiscardsLateModel() async {
        let log = CallLog()
        let provider = GatedProvider(log: log)
        let session = LLMSessionController()

        let loading = Task { @MainActor in
            await session.load(using: provider)
        }
        while log.count(of: "load-started") == 0 {
            await Task.yield()
        }
        await session.unload()
        provider.release()
        await loading.value

        XCTAssertEqual(session.phase, .notLoaded)
        XCTAssertNil(session.loadedModel)
        XCTAssertEqual(log.count(of: "unload"), 1)
    }

    @MainActor
    func testLoadFailureIsReported() async {
        let session = LLMSessionController()
        await session.load(using: FailingProvider())
        XCTAssertEqual(session.phase, .notLoaded)
        XCTAssertNotNil(session.errorMessage)
    }

    @MainActor
    func testLongPromptIsTruncated() async {
        let session = LLMSessionController()
        await session.load(using: StubLocalLLMProvider(chunkDelay: .zero))
        session.send(String(repeating: "あ", count: LLMSessionController.maximumPromptLength + 100))
        await session.waitForGeneration()
        XCTAssertEqual(session.messages.first?.text.count, LLMSessionController.maximumPromptLength)
    }

    func testStubChunksRespectLimit() {
        let request = LLMGenerationRequest(prompt: "abc", maxTokens: 2)
        XCTAssertEqual(StubLoadedLLM.replyChunks(for: request).count, 2)
    }
}
