import Foundation
import XCTest
@testable import MyHomeCore

/// T4-1〜T4-3: ウィジェット、壁紙、アイコンの画像、版 3 の保存形式。
final class WidgetAndWallpaperTests: XCTestCase {
    private func widget(_ id: String, _ kind: WidgetKind = .calendar, _ size: WidgetSize = .small) -> HomeWidget {
        HomeWidget(id: id, kind: kind, size: size)
    }

    func testWidgetsCanBeAddedMovedResizedAndRemoved() throws {
        var layout: HomeLayout = PersistenceFixtures.layout(pages: [[PersistenceFixtures.link("a")], []])
        try layout.addWidget(widget("w1"), toPage: 0)
        try layout.addWidget(widget("w2", .note("買い物")), toPage: 0)
        try layout.moveWidget(id: "w2", by: -1)
        XCTAssertEqual(layout.pages[0].widgets.map(\.id), ["w2", "w1"])
        try layout.updateWidget(id: "w1", kind: .clock(ClockWidgetStyle(isAnalog: true, showsSeconds: true)), size: .medium)
        XCTAssertEqual(layout.widget(id: "w1")?.size, .medium)
        try layout.removeWidget(id: "w2")
        XCTAssertEqual(layout.pages[0].widgets.map(\.id), ["w1"])
        XCTAssertThrowsError(try layout.removeWidget(id: "w2")) { error in
            XCTAssertEqual(error as? LayoutEditError, .itemNotFound)
        }
    }

    func testWidgetLimitsAndIDsAreChecked() throws {
        var layout: HomeLayout = PersistenceFixtures.layout(pages: [[PersistenceFixtures.link("a")]])
        XCTAssertThrowsError(try layout.addWidget(widget("a"), toPage: 0)) { error in
            XCTAssertEqual(error as? LayoutEditError, .duplicateID, "項目と同じ ID は使えない")
        }
        for index in 0..<WidgetLimits.maximumPerPage {
            try layout.addWidget(widget("w\(index)"), toPage: 0)
        }
        XCTAssertThrowsError(try layout.addWidget(widget("over"), toPage: 0)) { error in
            XCTAssertEqual(error as? LayoutEditError, .widgetLimitReached)
        }
        XCTAssertThrowsError(try layout.addWidget(widget("x"), toPage: 3)) { error in
            XCTAssertEqual(error as? LayoutEditError, .pageNotFound)
        }
    }

    func testLongNoteIsTrimmed() throws {
        var layout: HomeLayout = PersistenceFixtures.layout(pages: [[]])
        let long: String = String(repeating: "あ", count: WidgetLimits.maximumNoteLength + 10)
        try layout.addWidget(widget("n", .note(long)), toPage: 0)
        guard case .note(let text) = layout.widget(id: "n")?.kind else {
            return XCTFail("メモのはず")
        }
        XCTAssertEqual(text.count, WidgetLimits.maximumNoteLength)
    }

    func testPageWithWidgetCannotBeRemoved() throws {
        var layout: HomeLayout = PersistenceFixtures.layout(pages: [[], []])
        try layout.addWidget(widget("w"), toPage: 1)
        XCTAssertThrowsError(try layout.removePage(at: 1)) { error in
            XCTAssertEqual(error as? LayoutEditError, .pageNotEmpty)
        }
    }

    func testVersionThreeRoundTripsEverything() throws {
        var layout: HomeLayout = DefaultLayout.make()
        try layout.addWidget(widget("w.clock", .clock(ClockWidgetStyle(isAnalog: true, showsSeconds: false)), .medium), toPage: 0)
        try layout.addWidget(widget("w.note", .note("メモ")), toPage: 0)
        try layout.addWidget(widget("w.timer", .timer), toPage: 1)
        let firstID: String = layout.pages[0].items[0].id
        var item: HomeItem = try XCTUnwrap(layout.item(id: firstID))
        item.imageName = "icon-1.jpg"
        try layout.updateItem(id: firstID, title: item.title, symbolName: item.symbolName, tint: item.tint, imageName: item.imageName)
        let wallpaper: WallpaperSetting = .image(WallpaperImage(fileName: "wallpaper-1.jpg", blur: 0.4, dim: 0.3))
        let settings = SavedSettings(themeID: "forest", appearance: .dark, wallpaper: wallpaper, showsSeconds: true)
        var timers: TimerBoard = .initial()
        timers.countdowns[0].start(at: Date(timeIntervalSince1970: 1_000))
        let saved = SavedHome(layout: layout, settings: settings, timers: timers)
        let decoded: SavedHome = try HomeArchiveCodec.decode(try HomeArchiveCodec.encode(saved))
        XCTAssertEqual(decoded, saved)
        XCTAssertEqual(decoded.referencedImageNames, ["icon-1.jpg", "wallpaper-1.jpg"])
    }

    func testVersionTwoFileGetsDefaultsForNewValues() throws {
        let v2: String = """
        {"schemaVersion": 2, "layout": {"pages": [{"id": "p", "items": []}], "dock": []}, "settings": {"themeID": "mono"}}
        """
        let saved: SavedHome = try HomeArchiveCodec.decode(PersistenceFixtures.json(v2))
        XCTAssertEqual(saved.layout.pages[0].widgets, [])
        XCTAssertEqual(saved.settings.wallpaper, .themeGradient)
        XCTAssertFalse(saved.settings.showsSeconds)
        XCTAssertEqual(saved.timers, .initial())
    }

    func testBrokenWallpaperOrTimersFallBackWithoutLosingLayout() throws {
        let json: String = """
        {"schemaVersion": 3, "layout": {"pages": [{"id": "p", "items": [], "widgets": []}], "dock": []},
         "settings": {"themeID": "mono", "wallpaper": {"style": "video"}}, "timers": {"countdowns": "x"}}
        """
        let saved: SavedHome = try HomeArchiveCodec.decode(PersistenceFixtures.json(json))
        XCTAssertEqual(saved.settings.themeID, "mono")
        XCTAssertEqual(saved.settings.wallpaper, .themeGradient)
        XCTAssertEqual(saved.timers, .initial())
    }

    func testWallpaperValuesAreClamped() throws {
        let image = WallpaperImage(fileName: "a.jpg", blur: 4, dim: -1)
        XCTAssertEqual(image.blur, 1)
        XCTAssertEqual(image.dim, 0)
        let json: String = #"{"fileName": "a.jpg", "blur": 9, "dim": "x"}"#
        let decoded: WallpaperImage = try JSONDecoder().decode(WallpaperImage.self, from: PersistenceFixtures.json(json))
        XCTAssertEqual(decoded.blur, 1)
        XCTAssertEqual(decoded.dim, 0.2, "読めない値は初期値")
    }

    func testInvalidWidgetsAreRejectedOnLoad() throws {
        var layout: HomeLayout = PersistenceFixtures.layout(pages: [[PersistenceFixtures.link("a")]])
        layout.pages[0].widgets = [widget("a")]
        let data: Data = try HomeArchiveCodec.encode(SavedHome(layout: layout, settings: .defaults))
        XCTAssertThrowsError(try HomeArchiveCodec.decode(data)) { error in
            XCTAssertEqual(error as? HomeArchiveError, .invalid([.invalidWidget("a")]))
        }
    }

    @MainActor
    func testRouterOpensWidgetEditorAndConfirmsRemoval() async {
        let router = AppRouter()
        let note: HomeWidget = widget("n", .note("メモ"))
        router.presentWidgetEditor(note)
        XCTAssertEqual(router.sheet, .editWidget("n"))
        router.requestWidgetRemoval(note)
        XCTAssertEqual(router.alert, .confirmWidgetRemoval(note))
        XCTAssertTrue(router.alert?.title.contains("メモ") ?? false)
    }

    func testMonthGridStartsOnCalendarFirstWeekday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.firstWeekday = 1
        // 2026年10月1日は木曜日
        let date: Date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 29)) ?? Date()
        let grid: MonthGrid = MonthGrid.make(for: date, calendar: calendar)
        XCTAssertEqual(grid.weeks[0], [nil, nil, nil, nil, 1, 2, 3])
        XCTAssertEqual(grid.weeks.flatMap { $0 }.compactMap { $0 }.count, 31)
        XCTAssertEqual(grid.today, 29)
        XCTAssertEqual(grid.weekdaySymbols.count, 7)
        calendar.firstWeekday = 2
        let mondayFirst: MonthGrid = MonthGrid.make(for: date, calendar: calendar)
        XCTAssertEqual(mondayFirst.weeks[0], [nil, nil, nil, 1, 2, 3, 4], "月曜始まり")
    }
}
