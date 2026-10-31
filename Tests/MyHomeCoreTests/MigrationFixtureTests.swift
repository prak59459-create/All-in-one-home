import Foundation
import XCTest
@testable import MyHomeCore

/// Phase 9: アップデート相当の移行（F0823）。Fixtures/Migration の保存ファイルは、それぞれの時点のコミットのコードで
/// 作ったもの（作り方は scripts/fixtures/migration/README.md）。今のアプリが、起動時と同じ読み込みで読めることを確かめる。
final class MigrationFixtureTests: XCTestCase {
    // 2026-10-29 12:00:00 UTC（作った時に使った時刻）
    private let fixed = Date(timeIntervalSince1970: 1_793_275_200)

    func testPhase2FileLoads() throws {
        let saved: SavedHome = try loadHome("home-v1-phase2.json")
        XCTAssertEqual(saved.schemaVersion, SavedHome.currentSchemaVersion, "読んだら今の版になる")
        let links: [String] = saved.layout.pages[1].items.map { (item: HomeItem) -> String in item.id }
        XCTAssertTrue(links.contains("link.phase2"))
        let home: [String] = saved.layout.pages[0].items.map { (item: HomeItem) -> String in item.id }
        XCTAssertFalse(home.contains("link.wikipedia"), "削除した項目は戻らない")
        XCTAssertEqual(saved.settings.themeID, "forest")
        XCTAssertEqual(saved.settings.appearance, .dark)
        XCTAssertEqual(saved.settings.wallpaper, .themeGradient, "Phase 4 で増えた値は初期値")
        XCTAssertEqual(saved.settings.motion, .system, "Phase 8 で増えた値は初期値")
        XCTAssertEqual(saved.timers, .initial())
    }

    func testPhase3FileKeepsFoldersAndPages() throws {
        let saved: SavedHome = try loadHome("home-v2-phase3.json")
        let folder: HomeItem? = saved.layout.pages.flatMap { (page: HomePage) -> [HomeItem] in page.items }
            .first { (item: HomeItem) -> Bool in item.id == "folder.phase3" }
        let inside: [String] = folder?.folderItems?.map { (item: HomeItem) -> String in item.id } ?? []
        XCTAssertEqual(Set(inside), ["link.github", "link.swift-forums"])
        XCTAssertTrue(saved.layout.pages.contains { (page: HomePage) -> Bool in page.id == "page.phase3" })
        let swift: HomeItem? = saved.layout.pages[0].items.first { (item: HomeItem) -> Bool in item.id == "link.swift" }
        XCTAssertEqual(swift?.title, "Swift 公式")
        XCTAssertEqual(saved.settings.themeID, "sunset")
    }

    func testPhase4FileKeepsWidgetsImagesAndTimers() throws {
        let saved: SavedHome = try loadHome("home-v3-phase4.json")
        let widgets: [WidgetKind] = saved.layout.pages[0].widgets.map { (widget: HomeWidget) -> WidgetKind in widget.kind }
        XCTAssertEqual(widgets, [.clock(ClockWidgetStyle(isAnalog: true, showsSeconds: true)), .note("Phase 4 のメモ")])
        XCTAssertEqual(saved.referencedImageNames, ["icon-0f8c2b7e.jpg", "wallpaper-5d1e9a40.jpg"])
        XCTAssertTrue(saved.settings.showsSeconds)
        let labels: [String] = saved.timers.countdowns.map { (timer: CountdownTimer) -> String in timer.label }
        XCTAssertTrue(labels.contains("お茶"))
        let running: CountdownTimer? = saved.timers.countdowns.first { (timer: CountdownTimer) -> Bool in timer.id == "timer.3min" }
        XCTAssertEqual(running?.state, .running(endDate: fixed.addingTimeInterval(180)))
        XCTAssertEqual(saved.timers.stopwatch.laps.count, 1)
    }

    func testPhase7FileGetsTheNewSettings() throws {
        let saved: SavedHome = try loadHome("home-v3-phase7.json")
        XCTAssertEqual(saved.settings.themeID, "forest")
        XCTAssertTrue(saved.settings.showsSeconds)
        XCTAssertEqual(saved.settings.motion, .system)
        XCTAssertEqual(saved.settings.textSize, .system)
    }

    func testOldFilesLoadThroughTheStartupPathAndSaveAsTheCurrentVersion() throws {
        for name in ["home-v1-phase2.json", "home-v2-phase3.json", "home-v3-phase4.json", "home-v3-phase7.json"] {
            let storage = MemoryArchiveStorage(data: try fixture(name))
            let outcome: LoadOutcome = HomeArchiveLoader.load(from: storage)
            XCTAssertNil(outcome.notice, name)
            XCTAssertTrue(outcome.canSave, name)
            // 書き戻すと今の版になり、もう一度読んでも同じ
            let rewritten: Data = try HomeArchiveCodec.encode(outcome.saved)
            let again: SavedHome = try HomeArchiveCodec.decode(rewritten)
            XCTAssertEqual(again, outcome.saved, name)
            XCTAssertEqual(again.schemaVersion, SavedHome.currentSchemaVersion, name)
        }
    }

    func testPhase5MiniAppFilesLoad() throws {
        let notes: NoteBook = try MiniAppArchiveCodec.decode(NoteBook.self, from: try fixture("apps-v1-notes.json"))
        XCTAssertEqual(notes.notes.count, 2)
        XCTAssertEqual(notes.notes.first { (note: Note) -> Bool in note.isPinned }?.title, "買い物")

        let tasks: TodoList = try MiniAppArchiveCodec.decode(TodoList.self, from: try fixture("apps-v1-tasks.json"))
        XCTAssertEqual(tasks.items.count, 2)
        XCTAssertEqual(tasks.items.first { (item: TodoItem) -> Bool in item.id == "task.2" }?.isDone, true)
        XCTAssertEqual(tasks.items.first { (item: TodoItem) -> Bool in item.id == "task.1" }?.due, DayStamp(year: 2026, month: 11, day: 2))

        let calculator: CalculatorState = try MiniAppArchiveCodec.decode(CalculatorState.self, from: try fixture("apps-v1-calculator.json"))
        XCTAssertEqual(calculator.history.first?.result, "36")
        XCTAssertEqual(calculator.tokens, [.number("7"), .operation(.add)])

        let converter: ConverterState = try MiniAppArchiveCodec.decode(ConverterState.self, from: try fixture("apps-v1-converter.json"))
        XCTAssertEqual(converter.categoryID, "temperature")
        XCTAssertEqual(converter.input, "36.5")

        let text: TextToolsState = try MiniAppArchiveCodec.decode(TextToolsState.self, from: try fixture("apps-v1-texttools.json"))
        XCTAssertEqual(text.text, "全角ＡＢＣ　と　半角")
    }

    func testPhase7WeatherFileLoads() throws {
        let weather: WeatherData = try MiniAppArchiveCodec.decode(WeatherData.self, from: try fixture("apps-v1-weather.json"))
        XCTAssertTrue(weather.isNetworkEnabled)
        XCTAssertEqual(weather.temperatureUnit, .fahrenheit)
        XCTAssertEqual(weather.windSpeedUnit, .kilometersPerHour)
        XCTAssertEqual(weather.locations.map { (location: WeatherLocation) -> String in location.name }, ["東京", "大阪市"])
        XCTAssertEqual(weather.snapshots.count, 1)
    }

    /// 起動時と同じ読み込み（AppBootstrap）で、古い版のファイル一式を読む。読めない時の退避も起きない。
    @MainActor
    func testOldFilesLoadAtStartup() async throws {
        let directory: URL = try MigrationFixtureTests.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try fixture("home-v3-phase4.json").write(to: directory.appendingPathComponent("home.json"))
        let apps: URL = directory.appendingPathComponent("Apps", isDirectory: true)
        try FileManager.default.createDirectory(at: apps, withIntermediateDirectories: true)
        try fixture("apps-v1-notes.json").write(to: apps.appendingPathComponent("notes.json"))

        let boot: AppBootstrap = AppBootstrap.make(directory: directory)
        XCTAssertNil(boot.startupNotice)
        XCTAssertEqual(boot.settings.themeID, "mono")
        let notes: MiniAppDocument<NoteBook> = boot.miniApps.document(NoteBook.self)
        await notes.load()
        XCTAssertNil(notes.notice)
        XCTAssertEqual(notes.content.notes.count, 2)
        let files: [String] = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertFalse(files.contains { (name: String) -> Bool in name.contains("unreadable") }, "退避していない")
    }

    /// 新規起動: 保存先が空なら初期の配置で始まり、変更すると保存ファイルができる。
    @MainActor
    func testFreshLaunchStartsWithTheInitialLayoutAndSaves() async throws {
        let directory: URL = try MigrationFixtureTests.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let boot: AppBootstrap = AppBootstrap.make(directory: directory, delay: .milliseconds(1))
        XCTAssertNil(boot.startupNotice)
        XCTAssertEqual(boot.home.layout, DefaultLayout.make())
        XCTAssertEqual(boot.persistence.status, .saved)
        boot.settings.themeID = "forest"
        await boot.persistence.flush()
        let saved: SavedHome = try HomeArchiveCodec.decode(try Data(contentsOf: directory.appendingPathComponent("home.json")))
        XCTAssertEqual(saved.settings.themeID, "forest")
    }

    // MARK: - 補助

    private func loadHome(_ name: String) throws -> SavedHome {
        try HomeArchiveCodec.decode(try fixture(name))
    }

    private func fixture(_ name: String) throws -> Data {
        try MigrationFixtureTests.fixture(name)
    }

    static func fixture(_ name: String) throws -> Data {
        let folder: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Migration", isDirectory: true)
        return try Data(contentsOf: folder.appendingPathComponent(name))
    }

    static func makeDirectory() throws -> URL {
        let directory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyHomeMigration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
