import Foundation
import XCTest
@testable import MyHomeCore

/// Phase 9: 復元・すべての消去・端末内のバックアップ（F0828–F0832、F0839、F0868）。
final class BackupRestoreTests: XCTestCase {
    private var directory: URL!
    private let fixed = Date(timeIntervalSince1970: 1_793_275_200)

    override func setUpWithError() throws {
        directory = try MigrationFixtureTests.makeDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - 復元

    @MainActor
    func testRestoreReplacesTheDataKeepsASafetyCopyAndReloads() async throws {
        let session: AppSession = try makeSession(themeID: "mono", notes: "今のメモ", weatherConsent: false, imageName: "icon-now.jpg")
        let backup: BackupContents = try makeBackup(themeID: "forest", notes: "前のメモ", weatherConsent: true, imageName: "icon-old.jpg")
        let before: AppBootstrap = session.boot

        let safety: LocalBackup = try await session.restore(backup, parts: backup.allParts)

        XCTAssertEqual(session.generation, 1)
        XCTAssertFalse(session.boot.home === before.home, "読み直したストアに入れ替わる")
        XCTAssertEqual(session.boot.settings.themeID, "forest")
        XCTAssertEqual(try savedHome().settings.themeID, "forest")
        XCTAssertEqual(try savedNotes().notes.first?.title, "前のメモ")
        XCTAssertFalse(try savedWeather().isNetworkEnabled, "天気の通信の同意は今の端末のまま（オフ）")
        XCTAssertEqual(try savedWeather().temperatureUnit, .fahrenheit, "同意以外は戻る")
        XCTAssertTrue(imageExists("icon-old.jpg"))
        XCTAssertFalse(imageExists("icon-now.jpg"), "使われなくなった画像は、読み直しの時に消える（復元の前のバックアップには残る）")

        // 復元の前のデータが残っていて、それを復元すると元に戻る
        XCTAssertEqual(safety.kind, .beforeRestore)
        let store: LocalBackupStore = try XCTUnwrap(session.localBackups)
        XCTAssertEqual(store.list().map { (item: LocalBackup) -> String in item.fileName }, [safety.fileName])
        let undo: BackupContents = try BackupReader.read(try store.read(safety))
        XCTAssertEqual(undo.home.settings.themeID, "mono")
        try await session.restore(undo, parts: undo.allParts)
        XCTAssertEqual(session.boot.settings.themeID, "mono")
        XCTAssertEqual(try savedNotes().notes.first?.title, "今のメモ")
        XCTAssertTrue(imageExists("icon-now.jpg"))
    }

    @MainActor
    func testWeatherConsentIsNeverTurnedOnByARestore() async throws {
        let session: AppSession = try makeSession(themeID: "mono", notes: nil, weatherConsent: nil, imageName: nil)
        let backup: BackupContents = try makeBackup(themeID: "forest", notes: nil, weatherConsent: true, imageName: nil)
        try await session.restore(backup, parts: backup.allParts)
        XCTAssertFalse(try savedWeather().isNetworkEnabled, "天気のデータがなかった端末では、オフのまま")

        let consenting: AppSession = try makeSession(themeID: "mono", notes: nil, weatherConsent: true, imageName: nil)
        let offBackup: BackupContents = try makeBackup(themeID: "forest", notes: nil, weatherConsent: false, imageName: nil)
        try await consenting.restore(offBackup, parts: offBackup.allParts)
        XCTAssertTrue(try savedWeather().isNetworkEnabled, "今オンなら、オンのまま")
    }

    @MainActor
    func testPartialRestoreChangesOnlyTheChosenParts() async throws {
        let session: AppSession = try makeSession(themeID: "mono", notes: "今のメモ", weatherConsent: false, imageName: nil)
        let backup: BackupContents = try makeBackup(themeID: "forest", notes: "前のメモ", weatherConsent: false, imageName: nil)
        try await session.restore(backup, parts: [.miniApp("notes")])
        XCTAssertEqual(session.boot.settings.themeID, "mono", "ホーム画面は選んでいないので今のまま")
        XCTAssertEqual(try savedNotes().notes.first?.title, "前のメモ")
        XCTAssertEqual(try savedWeather().temperatureUnit, .celsius, "天気も選んでいないので今のまま")
    }

    @MainActor
    func testRunningTimersComeBackStopped() async throws {
        let session: AppSession = try makeSession(themeID: "mono", notes: nil, weatherConsent: nil, imageName: nil)
        var board: TimerBoard = .initial()
        board.countdowns[0].start(at: fixed)
        board.stopwatch.start(at: fixed)
        let saved = SavedHome(layout: DefaultLayout.make(), settings: .defaults, timers: board)
        let backup: BackupContents = try BackupReader.read(try archive(home: saved))
        try await session.restore(backup, parts: [.home])
        let restored: TimerBoard = session.boot.timers.board
        XCTAssertEqual(restored.countdowns[0].state, .idle)
        XCTAssertEqual(restored.countdowns[0].duration, board.countdowns[0].duration)
        XCTAssertFalse(restored.stopwatch.isRunning)
    }

    @MainActor
    func testTheOldStoresStopSavingAfterARestore() async throws {
        let session: AppSession = try makeSession(themeID: "mono", notes: "今のメモ", weatherConsent: nil, imageName: nil)
        let old: AppBootstrap = session.boot
        let oldNotes: MiniAppDocument<NoteBook> = old.miniApps.document(NoteBook.self)
        await oldNotes.load()
        let backup: BackupContents = try makeBackup(themeID: "forest", notes: "前のメモ", weatherConsent: nil, imageName: nil)
        try await session.restore(backup, parts: backup.allParts)

        // 古いストアを変えても、書き換えたファイルは上書きされない
        old.settings.themeID = "sunset"
        await old.persistence.flush()
        oldNotes.update { (book: inout NoteBook) in book.notes.removeAll() }
        await oldNotes.flush()
        XCTAssertTrue(old.persistence.isSuspended)
        XCTAssertEqual(try savedHome().settings.themeID, "forest")
        XCTAssertEqual(try savedNotes().notes.first?.title, "前のメモ")
    }

    @MainActor
    func testRestoreIsRefusedWhenSavingIsOff() async throws {
        let boot: AppBootstrap = AppBootstrap.make(options: LaunchOptions(arguments: [LaunchOptions.sampleItemsFlag, "10"]))
        let session = AppSession(boot: boot)
        XCTAssertNotNil(session.unavailableReason)
        XCTAssertNil(session.localBackups)
        let backup: BackupContents = try makeBackup(themeID: "forest", notes: nil, weatherConsent: nil, imageName: nil)
        do {
            try await session.restore(backup, parts: backup.allParts)
            XCTFail("保存しない起動では復元しない")
        } catch {
            XCTAssertTrue(BackupError.message(for: error).contains("検証用"))
        }
        XCTAssertEqual(session.generation, 0)
    }

    // MARK: - 書き換えの失敗

    func testFailedWritesAreRolledBack() throws {
        let base = DirectoryFileSystem(root: directory)
        try base.write(Data("old home".utf8), to: "home.json")
        try base.write(Data("old notes".utf8), to: "Apps/notes.json")
        let failing = PathFailingFileSystem(base: base, failingPath: "home.json")
        let changes: [BackupFileChange] = [
            BackupFileChange(path: "Images/new.jpg", data: Data("new image".utf8)),
            BackupFileChange(path: "Apps/notes.json", data: Data("new notes".utf8)),
            BackupFileChange(path: "home.json", data: Data("new home".utf8))
        ]
        XCTAssertThrowsError(try BackupRestorer.apply(changes, to: failing)) { (error: Error) in
            guard case .writeFailed(_, let rolledBack) = error as? BackupError else {
                return XCTFail("\(error)")
            }
            XCTAssertTrue(rolledBack)
        }
        XCTAssertEqual(try base.read("home.json"), Data("old home".utf8))
        XCTAssertEqual(try base.read("Apps/notes.json"), Data("old notes".utf8))
        XCTAssertFalse(base.exists("Images/new.jpg"), "新しく書いたファイルは消す")
    }

    func testFailedRollbackIsReported() throws {
        let base = DirectoryFileSystem(root: directory)
        try base.write(Data("old notes".utf8), to: "Apps/notes.json")
        let failing = PathFailingFileSystem(base: base, failingPath: "home.json", failsAfterWrites: ["Apps/notes.json"])
        let changes: [BackupFileChange] = [
            BackupFileChange(path: "Apps/notes.json", data: Data("new notes".utf8)),
            BackupFileChange(path: "home.json", data: Data("new home".utf8))
        ]
        XCTAssertThrowsError(try BackupRestorer.apply(changes, to: failing)) { (error: Error) in
            XCTAssertEqual(error as? BackupError, .writeFailed(PathFailingFileSystem.Failure().localizedDescription, rolledBack: false))
            XCTAssertTrue(BackupError.message(for: error).contains("端末内のバックアップ"))
        }
    }

    // MARK: - すべての消去

    @MainActor
    func testEraseRemovesUserDataButKeepsBackupsAndUpdateRecords() async throws {
        let session: AppSession = try makeSession(themeID: "mono", notes: "今のメモ", weatherConsent: true, imageName: "icon-now.jpg")
        let files = DirectoryFileSystem(root: directory)
        try files.write(Data("読めなかった".utf8), to: "home.unreadable-20261029-120000.json")
        try files.write(Data("{}".utf8), to: "update-state.json")
        let store: LocalBackupStore = try XCTUnwrap(session.localBackups)
        try store.save(Data("manual".utf8), kind: .manual, createdAt: fixed)

        let safety: LocalBackup = try await session.eraseAllData()

        XCTAssertEqual(safety.kind, .beforeErase)
        XCTAssertEqual(session.boot.home.layout, DefaultLayout.make())
        XCTAssertEqual(session.boot.settings.themeID, ThemeCatalog.defaultID)
        let remaining: [String] = try files.listFiles()
        XCTAssertFalse(remaining.contains("home.json"))
        XCTAssertFalse(remaining.contains("home.unreadable-20261029-120000.json"))
        XCTAssertFalse(remaining.contains { (path: String) -> Bool in path.hasPrefix("Apps/") || path.hasPrefix("Images/") })
        XCTAssertTrue(remaining.contains("update-state.json"), "アップデートの記録は消さない")
        XCTAssertEqual(store.list().count, 2, "手動のバックアップと、消去の前のバックアップは残す")
        let undo: BackupContents = try BackupReader.read(try store.read(safety))
        XCTAssertEqual(undo.home.settings.themeID, "mono")
        XCTAssertEqual(undo.images.keys.sorted(), ["icon-now.jpg"])
    }

    // MARK: - 端末内のバックアップの一覧

    func testLocalBackupsAreListedNewestFirstAndAutomaticOnesArePruned() throws {
        var store = LocalBackupStore(directory: directory.appendingPathComponent("Backups"))
        store.timeZone = TimeZone(identifier: "UTC")!
        let first: LocalBackup = try store.save(Data("a".utf8), kind: .manual, createdAt: fixed)
        XCTAssertEqual(first.fileName, "myhome-manual-20261029-120000.json")
        let same: LocalBackup = try store.save(Data("b".utf8), kind: .manual, createdAt: fixed)
        XCTAssertEqual(same.fileName, "myhome-manual-20261029-120000-2.json", "同じ時刻なら番号を付ける")
        for minute in 1...7 {
            try store.save(Data("auto".utf8), kind: .beforeRestore, createdAt: fixed.addingTimeInterval(TimeInterval(minute * 60)))
        }
        try Data("x".utf8).write(to: directory.appendingPathComponent("Backups/memo.txt"))

        let listed: [LocalBackup] = store.list()
        let automatic: [LocalBackup] = listed.filter { (item: LocalBackup) -> Bool in item.kind.isAutomatic }
        XCTAssertEqual(automatic.count, LocalBackupStore.maximumAutomatic, "自動のものは新しい 5 個だけ残す")
        XCTAssertEqual(automatic.first?.createdAt, fixed.addingTimeInterval(7 * 60))
        XCTAssertEqual(listed.count, 7, "手動の 2 個と自動の 5 個。名前の形が違うファイルは数えない")
        XCTAssertEqual(try store.read(first), Data("a".utf8))
        XCTAssertEqual(listed.last?.byteCount, 1)

        try store.delete(first)
        XCTAssertEqual(store.list().count, 6)
        try store.deleteAll()
        XCTAssertTrue(store.list().isEmpty)
    }

    func testManualBackupsHaveALimit() throws {
        let store = LocalBackupStore(directory: directory.appendingPathComponent("Backups"))
        for index in 0..<LocalBackupStore.maximumManual {
            try store.save(Data("m".utf8), kind: .manual, createdAt: fixed.addingTimeInterval(TimeInterval(index)))
        }
        XCTAssertThrowsError(try store.save(Data("m".utf8), kind: .manual, createdAt: fixed.addingTimeInterval(100)))
        XCTAssertNoThrow(try store.save(Data("a".utf8), kind: .beforeRestore, createdAt: fixed), "自動のものは上限に関係なく作る")
    }

    // MARK: - 補助

    @MainActor
    private func makeSession(themeID: String, notes: String?, weatherConsent: Bool?, imageName: String?) throws -> AppSession {
        let files = DirectoryFileSystem(root: directory)
        try files.write(try HomeArchiveCodec.encode(BackupTestData.home(themeID: themeID, imageName: imageName)), to: "home.json")
        if let imageName {
            try files.write(Data("JPEG \(imageName)".utf8), to: "Images/\(imageName)")
        }
        if let notes {
            try files.write(try BackupTestData.notes(notes), to: "Apps/notes.json")
        }
        if let weatherConsent {
            var weather: WeatherData = WeatherData.initial
            weather.isNetworkEnabled = weatherConsent
            try files.write(try MiniAppArchiveCodec.encode(weather), to: "Apps/weather.json")
        }
        let boot: AppBootstrap = AppBootstrap.make(directory: directory, delay: .milliseconds(1))
        let clock: Date = fixed
        return AppSession(
            boot: boot,
            load: { (folder: URL) -> AppBootstrap in AppBootstrap.make(directory: folder, delay: .milliseconds(1)) },
            clock: { clock }
        )
    }

    private func makeBackup(themeID: String, notes: String?, weatherConsent: Bool?, imageName: String?) throws -> BackupContents {
        var files: [BackupFile] = []
        if let imageName {
            files.append(BackupFile(path: "Images/\(imageName)", data: Data("JPEG \(imageName)".utf8)))
        }
        if let notes {
            files.append(BackupFile(path: "Apps/notes.json", data: try BackupTestData.notes(notes)))
        }
        if let weatherConsent {
            files.append(BackupFile(path: "Apps/weather.json", data: try BackupTestData.weather(consent: weatherConsent)))
        }
        return try BackupReader.read(try archive(home: BackupTestData.home(themeID: themeID, imageName: imageName), extra: files))
    }

    private func archive(home: SavedHome, extra: [BackupFile] = []) throws -> Data {
        let files: [BackupFile] = [BackupFile(path: "home.json", data: try HomeArchiveCodec.encode(home))] + extra
        return try BackupArchiveCodec.encode(BackupArchive(createdAt: fixed, appVersion: "0.1", files: files))
    }

    private func savedHome() throws -> SavedHome {
        try HomeArchiveCodec.decode(try Data(contentsOf: directory.appendingPathComponent("home.json")))
    }

    private func savedNotes() throws -> NoteBook {
        try MiniAppArchiveCodec.decode(NoteBook.self, from: try Data(contentsOf: directory.appendingPathComponent("Apps/notes.json")))
    }

    private func savedWeather() throws -> WeatherData {
        try MiniAppArchiveCodec.decode(WeatherData.self, from: try Data(contentsOf: directory.appendingPathComponent("Apps/weather.json")))
    }

    private func imageExists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: directory.appendingPathComponent("Images/\(name)").path)
    }
}

/// 決まったパスへの書き込みで失敗する保存先（書き換えの途中の失敗と、元に戻す処理を確かめる）。
/// 回数で失敗させる FailingFileSystem（UpdateTestSupport）と違い、元に戻す時の書き込みも失敗させられる。
struct PathFailingFileSystem: PackageFileSystem {
    struct Failure: Error, LocalizedError {
        var errorDescription: String? {
            "書き込みに失敗しました（テスト）"
        }
    }

    let base: DirectoryFileSystem
    let failingPath: String
    /// 元に戻す時にも失敗させるパス（2 回目以降の書き込みで失敗する）。
    var failsAfterWrites: Set<String> = []
    private let counter = WriteCounter()

    init(base: DirectoryFileSystem, failingPath: String, failsAfterWrites: Set<String> = []) {
        self.base = base
        self.failingPath = failingPath
        self.failsAfterWrites = failsAfterWrites
    }

    func listFiles() throws -> [String] {
        try base.listFiles()
    }

    func read(_ path: String) throws -> Data {
        try base.read(path)
    }

    func write(_ data: Data, to path: String) throws {
        let count: Int = counter.increment(path)
        if path == failingPath || (failsAfterWrites.contains(path) && count > 1) {
            throw Failure()
        }
        try base.write(data, to: path)
    }

    func delete(_ path: String) throws {
        try base.delete(path)
    }

    func exists(_ path: String) -> Bool {
        base.exists(path)
    }
}

/// パスごとの書き込み回数（テスト用）。
final class WriteCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var counts: [String: Int] = [:]

    func increment(_ path: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        counts[path, default: 0] += 1
        return counts[path] ?? 0
    }
}
