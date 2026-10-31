import Foundation
import XCTest
@testable import MyHomeCore

/// Phase 9: バックアップの形式・作成・検証（F0812、F0813、F0817–F0821、F0824、F0827）。
final class BackupTests: XCTestCase {
    private var directory: URL!
    private let fixed = Date(timeIntervalSince1970: 1_793_275_200)

    override func setUpWithError() throws {
        directory = try MigrationFixtureTests.makeDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testBackupRoundTripKeepsEverything() throws {
        let files = DirectoryFileSystem(root: directory)
        let saved: SavedHome = BackupTestData.home(themeID: "forest", imageName: "icon-a.jpg")
        try files.write(Data("JPEG-A".utf8), to: "Images/icon-a.jpg")
        try files.write(Data("UNUSED".utf8), to: "Images/icon-unused.jpg")
        try files.write(try BackupTestData.notes("買い物"), to: "Apps/notes.json")
        try files.write(try BackupTestData.weather(consent: true), to: "Apps/weather.json")

        let result: BackupBuilder.Result = try BackupBuilder.make(saved: saved, files: files, createdAt: fixed, appVersion: "0.1")
        XCTAssertTrue(result.notes.isEmpty)
        let contents: BackupContents = try BackupReader.read(result.data)
        XCTAssertEqual(contents.home, saved)
        XCTAssertEqual(contents.createdAt, fixed)
        XCTAssertEqual(contents.appVersion, "0.1")
        XCTAssertEqual(contents.miniApps.map { (entry: MiniAppBackupEntry) -> String in entry.fileID }, ["notes", "weather"])
        XCTAssertEqual(contents.images, ["icon-a.jpg": Data("JPEG-A".utf8)], "使っていない画像は含めない")
        XCTAssertTrue(contents.missingImageNames.isEmpty)
        XCTAssertTrue(contents.skippedPaths.isEmpty)
        XCTAssertEqual(contents.allParts, [.home, .miniApp("notes"), .miniApp("weather")])

        let summary = BackupSummary(contents)
        XCTAssertEqual(summary.pageCount, saved.layout.pages.count)
        XCTAssertEqual(summary.itemCount, saved.layout.itemCount)
        XCTAssertEqual(summary.imageCount, 1)
        XCTAssertEqual(summary.themeName, ThemeCatalog.preset(id: "forest").name)
    }

    func testBuilderLeavesOutUnreadableDataAndMissingImages() throws {
        let files = DirectoryFileSystem(root: directory)
        try files.write(Data("{ 壊れた".utf8), to: "Apps/tasks.json")
        try files.write(try BackupTestData.notes("メモ"), to: "Apps/notes.json")
        let saved: SavedHome = BackupTestData.home(themeID: "mono", imageName: "icon-gone.jpg")

        let result: BackupBuilder.Result = try BackupBuilder.make(saved: saved, files: files, createdAt: fixed, appVersion: "0.1")
        XCTAssertEqual(result.notes.count, 2)
        XCTAssertTrue(result.notes[0].contains("タスク"))
        XCTAssertTrue(result.notes[1].contains("画像 1 枚"))
        let contents: BackupContents = try BackupReader.read(result.data)
        XCTAssertEqual(contents.miniApps.map { (entry: MiniAppBackupEntry) -> String in entry.fileID }, ["notes"])
        XCTAssertEqual(contents.missingImageNames, ["icon-gone.jpg"], "読み込む時も、欠けている画像を数える（F0827）")
    }

    func testReaderRejectsFilesThatAreNotUsableBackups() throws {
        assertRejected(Data("ただの文章".utf8), .notABackup)
        assertRejected(Data(#"{"format": "other-app", "formatVersion": 1}"#.utf8), .notABackup)
        assertRejected(Data(#"{"format": "myhome-backup", "formatVersion": 2, "files": []}"#.utf8), .newerVersion(2))
        assertRejected(try archive([]), .missingHome)

        let home: Data = try HomeArchiveCodec.encode(BackupTestData.home(themeID: "forest", imageName: nil))
        assertRejected(try archive([BackupFile(path: "home.json", data: home), BackupFile(path: "home.json", data: home)]), .duplicatePath("home.json"))

        let newer: Data = Data(#"{"schemaVersion": 99, "layout": {"pages": [], "dock": []}}"#.utf8)
        XCTAssertThrowsError(try BackupReader.read(try archive([BackupFile(path: "home.json", data: newer)]))) { (error: Error) in
            guard case .invalidHome(let reason) = error as? BackupError else {
                return XCTFail("\(error)")
            }
            XCTAssertTrue(reason.contains("新しい版"))
        }

        let brokenNotes: Data = Data(#"{"schemaVersion": 1, "app": "notes", "content": {"notes": "x"}}"#.utf8)
        let withBrokenApp: Data = try archive([BackupFile(path: "home.json", data: home), BackupFile(path: "Apps/notes.json", data: brokenNotes)])
        XCTAssertThrowsError(try BackupReader.read(withBrokenApp)) { (error: Error) in
            guard case .invalidMiniApp(let title, _) = error as? BackupError else {
                return XCTFail("\(error)")
            }
            XCTAssertEqual(title, "メモ", "1 つでも読めなければ、何も復元しない")
        }
    }

    func testReaderSkipsUnknownAndUnsafePaths() throws {
        let home: Data = try HomeArchiveCodec.encode(BackupTestData.home(themeID: "forest", imageName: nil))
        let files: [BackupFile] = [
            BackupFile(path: "home.json", data: home),
            BackupFile(path: "Apps/calendar.json", data: Data("{}".utf8)),
            BackupFile(path: "../outside.json", data: Data("x".utf8)),
            BackupFile(path: "Images/../home.json", data: Data("x".utf8)),
            BackupFile(path: "Images/.hidden", data: Data("x".utf8))
        ]
        let contents: BackupContents = try BackupReader.read(try archive(files))
        XCTAssertEqual(contents.skippedPaths, ["Apps/calendar.json", "../outside.json", "Images/../home.json", "Images/.hidden"])
        XCTAssertTrue(contents.images.isEmpty)
        XCTAssertTrue(contents.miniApps.isEmpty)
    }

    func testArchiveIsReadableJSON() throws {
        let files = DirectoryFileSystem(root: directory)
        let result: BackupBuilder.Result = try BackupBuilder.make(
            saved: BackupTestData.home(themeID: "forest", imageName: nil), files: files, createdAt: fixed, appVersion: "0.1"
        )
        let text: String = String(decoding: result.data, as: UTF8.self)
        XCTAssertTrue(text.contains(#""format" : "myhome-backup""#))
        XCTAssertTrue(text.contains(#""createdAt" : "2026-10-29T12:00:00Z""#), "日時は ISO 8601（F0817）")
        XCTAssertTrue(text.contains(#""formatVersion" : 1"#), "形式の版（F0818）")
    }

    func testFormatting() {
        XCTAssertEqual(BackupFormat.size(512), "512 バイト")
        XCTAssertEqual(BackupFormat.size(350_400), "350 KB")
        XCTAssertEqual(BackupFormat.size(1_249_999), "1.2 MB")
        XCTAssertEqual(BackupFormat.size(1_250_000), "1.3 MB")
        let utc = TimeZone(identifier: "UTC")!
        XCTAssertEqual(BackupFormat.fileName(for: fixed, timeZone: utc), "MyHome-backup-20261029-1200.json")
        XCTAssertEqual(BackupFormat.date(fixed, timeZone: utc), "2026年10月29日 12:00")
    }

    func testEveryMiniAppIsInTheCatalogOnce() {
        let ids: [String] = MiniAppDataCatalog.all.map { (kind: MiniAppDataKind) -> String in kind.fileID }
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(Set(ids), [NoteBook.fileID, TodoList.fileID, CalculatorState.fileID, ConverterState.fileID, TextToolsState.fileID, WeatherData.fileID])
    }

    // MARK: - 補助

    private func archive(_ files: [BackupFile]) throws -> Data {
        try BackupArchiveCodec.encode(BackupArchive(createdAt: fixed, appVersion: "0.1", files: files))
    }

    private func assertRejected(_ data: Data, _ expected: BackupError, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try BackupReader.read(data), file: file, line: line) { (error: Error) in
            XCTAssertEqual(error as? BackupError, expected, file: file, line: line)
        }
    }
}

/// バックアップのテストで使うデータ。
enum BackupTestData {
    static func home(themeID: String, imageName: String?) -> SavedHome {
        var layout: HomeLayout = DefaultLayout.make()
        layout.pages[0].items[0].imageName = imageName
        let settings = SavedSettings(themeID: themeID, appearance: .dark)
        return SavedHome(layout: layout, settings: settings)
    }

    static func notes(_ title: String) throws -> Data {
        var book: NoteBook = NoteBook.initial
        let note: Note = try book.addNote(id: "note.\(title)", now: Date(timeIntervalSince1970: 1_793_275_200))
        book.updateNote(id: note.id, title: title, body: "本文", now: Date(timeIntervalSince1970: 1_793_275_200))
        return try MiniAppArchiveCodec.encode(book)
    }

    static func weather(consent: Bool) throws -> Data {
        var data: WeatherData = WeatherData.initial
        data.isNetworkEnabled = consent
        data.temperatureUnit = .fahrenheit
        try data.add(WeatherFixtures.tokyo)
        return try MiniAppArchiveCodec.encode(data)
    }
}
