import Foundation
import XCTest
@testable import MyHomeCore

/// T2-3: 保存の間引き・失敗の通知・やり直し、起動時の読み込み（メモリ上の保存先を使う）。
final class PersistenceControllerTests: XCTestCase {
    @MainActor
    private func waitUntilSettled(_ controller: PersistenceController, timeout: TimeInterval = 5) async {
        let deadline: Date = Date().addingTimeInterval(timeout)
        while controller.status == .pending && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @MainActor
    func testChangesAreCoalescedIntoOneWrite() async throws {
        let storage = MemoryArchiveStorage()
        let boot: AppBootstrap = AppBootstrap.make(storage: storage, delay: .milliseconds(50))
        boot.settings.appearance = .dark
        boot.settings.themeID = "forest"
        try boot.home.remove(itemID: DefaultLayout.make().pages[0].items[0].id)
        XCTAssertEqual(boot.persistence.status, .pending)
        await waitUntilSettled(boot.persistence)
        XCTAssertEqual(boot.persistence.status, .saved)
        XCTAssertEqual(storage.writeCount, 1, "続けて変えた分は1回にまとめる")
        let saved: SavedHome = try HomeArchiveCodec.decode(try XCTUnwrap(storage.data))
        XCTAssertEqual(saved.settings, SavedSettings(themeID: "forest", appearance: .dark))
        XCTAssertNotNil(boot.persistence.lastSavedAt)
    }

    @MainActor
    func testNothingIsWrittenWithoutChanges() async {
        let storage = MemoryArchiveStorage()
        let boot: AppBootstrap = AppBootstrap.make(storage: storage, delay: .milliseconds(1))
        boot.settings.appearance = .system
        await boot.persistence.flush()
        XCTAssertEqual(storage.writeCount, 0, "同じ値の代入や初回起動だけでは書かない")
    }

    @MainActor
    func testFlushWritesImmediately() async {
        let storage = MemoryArchiveStorage()
        let boot: AppBootstrap = AppBootstrap.make(storage: storage, delay: .seconds(60))
        boot.settings.appearance = .light
        await boot.persistence.flush()
        XCTAssertEqual(storage.writeCount, 1)
        XCTAssertEqual(boot.persistence.status, .saved)
    }

    @MainActor
    func testWriteFailureIsReportedAndRetried() async {
        let storage = MemoryArchiveStorage()
        storage.failWrites(true)
        let boot: AppBootstrap = AppBootstrap.make(storage: storage, delay: .milliseconds(1))
        boot.settings.appearance = .dark
        await boot.persistence.flush()
        guard case .failed(let message) = boot.persistence.status else {
            return XCTFail("失敗を表示するはず: \(boot.persistence.status)")
        }
        XCTAssertTrue(message.contains("保存できませんでした"), message)

        storage.failWrites(false)
        await boot.persistence.flush()
        XCTAssertEqual(boot.persistence.status, .saved, "やり直しで保存できる")
        XCTAssertEqual(storage.writeCount, 1)
    }

    @MainActor
    func testDisabledControllerNeverWrites() async {
        let controller = PersistenceController(storage: nil, disabledReason: "検証用")
        let home = HomeStore()
        let settings = SettingsStore()
        controller.attach(home: home, settings: settings)
        settings.appearance = .dark
        await controller.flush()
        XCTAssertEqual(controller.status, .disabled("検証用"))
    }

    @MainActor
    func testSampleLaunchDoesNotPersist() async {
        let options = LaunchOptions(arguments: ["MyHome", "-MyHomeSampleItems", "10"])
        let boot: AppBootstrap = AppBootstrap.make(options: options)
        guard case .disabled = boot.persistence.status else {
            return XCTFail("検証用の起動では保存しない")
        }
        XCTAssertEqual(boot.home.layout.pages[0].items.count, 10)
    }

    @MainActor
    func testFirstLaunchUsesDefaults() async {
        let boot: AppBootstrap = AppBootstrap.make(storage: MemoryArchiveStorage())
        XCTAssertEqual(boot.home.layout, DefaultLayout.make())
        XCTAssertEqual(boot.settings.saved, .defaults)
        XCTAssertNil(boot.startupNotice)
    }

    @MainActor
    func testNewerVersionIsSetAsideNotOverwritten() async {
        let storage = MemoryArchiveStorage(data: PersistenceFixtures.json(#"{"schemaVersion": 99}"#))
        let boot: AppBootstrap = AppBootstrap.make(storage: storage, delay: .milliseconds(1))
        XCTAssertEqual(storage.setAsideNames.count, 1)
        XCTAssertTrue(boot.startupNotice?.contains("新しい版") ?? false)
        XCTAssertEqual(boot.home.layout, DefaultLayout.make())
    }

    @MainActor
    func testSavingStopsWhenBrokenFileCannotBeSetAside() async {
        let storage = MemoryArchiveStorage(data: PersistenceFixtures.json("not json"))
        storage.failSetAside(true)
        let boot: AppBootstrap = AppBootstrap.make(storage: storage, delay: .milliseconds(1))
        boot.settings.appearance = .dark
        await boot.persistence.flush()
        XCTAssertEqual(storage.writeCount, 0, "読めなかったファイルを上書きしない")
        XCTAssertEqual(storage.data, PersistenceFixtures.json("not json"))
        guard case .disabled = boot.persistence.status else {
            return XCTFail("保存を止めるはず")
        }
        XCTAssertTrue(boot.startupNotice?.contains("保存しません") ?? false)
    }

    @MainActor
    func testWriterIgnoresOlderRevisions() async throws {
        let storage = MemoryArchiveStorage()
        let writer = HomeArchiveWriter(storage: storage)
        let newer = SavedHome(layout: DefaultLayout.make(), settings: SavedSettings(themeID: "mono", appearance: .dark))
        try await writer.write(newer, revision: 2)
        try await writer.write(.initial(), revision: 1)
        let saved: SavedHome = try HomeArchiveCodec.decode(try XCTUnwrap(storage.data))
        XCTAssertEqual(saved.settings.themeID, "mono")
        XCTAssertEqual(storage.writeCount, 1)
    }
}
