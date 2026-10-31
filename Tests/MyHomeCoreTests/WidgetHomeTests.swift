import Foundation
import XCTest
@testable import MyHomeCore

/// 追加フェーズ A（TA-3）: ウィジェット型のホーム画面。アプリのウィジェット、並べ方、おすすめ、アプリの一覧、形の切り替え、保存形式の版 4。
final class WidgetHomeTests: XCTestCase {
    private let small: (width: Double, height: Double) = (width: 170, height: 170)
    private let medium: (width: Double, height: Double) = (width: 352, height: 170)

    private func widget(_ id: String, _ kind: WidgetKind, _ size: WidgetSize = .small) -> HomeWidget {
        HomeWidget(id: id, kind: kind, size: size)
    }

    private func sizes(of widgets: [HomeWidget]) -> [(width: Double, height: Double)] {
        widgets.map { (widget: HomeWidget) -> (width: Double, height: Double) in widget.size == .medium ? medium : small }
    }

    /// 横 n マス（小 1 つ = 1 マス）の幅。
    private func columns(_ count: Int) -> Double {
        Double(count) * 170 + Double(count - 1) * 12
    }

    // MARK: - 並べ方

    func testFlowWrapsAndReportsTheWidestRow() {
        let flow = WidgetFlow(sizes: [medium, small, small, small], availableWidth: columns(4), spacing: 12)
        XCTAssertEqual(flow.frames.map(\.x), [0, 364, 546, 0])
        XCTAssertEqual(flow.frames.map(\.y), [0, 0, 0, 182])
        XCTAssertEqual(flow.width, columns(4))
        XCTAssertEqual(flow.height, 352)
    }

    func testFlowPutsATooWideWidgetOnItsOwnRow() {
        let flow = WidgetFlow(sizes: [small, medium, small], availableWidth: 300, spacing: 12)
        XCTAssertEqual(flow.frames.map(\.y), [0, 182, 364], "入りきらない中は、行の先頭に 1 つだけ置く")
        XCTAssertEqual(flow.frames.map(\.x), [0, 0, 0])
        XCTAssertEqual(flow.width, 352)
        XCTAssertEqual(WidgetFlow(sizes: [], availableWidth: 500, spacing: 12).height, 0)
    }

    /// 初めて起動した時のウィジェットは、縦向き（4 マス）でも横向き（6 マス）でも、行の途中に隙間ができない。
    func testDefaultWidgetsFillRowsInFourAndSixColumns() {
        let widgets: [HomeWidget] = DefaultLayout.homeWidgets()
        for count in [4, 6] {
            let flow = WidgetFlow(sizes: sizes(of: widgets), availableWidth: columns(count), spacing: 12)
            let rows: [Double: [WidgetFlow.Frame]] = Dictionary(grouping: flow.frames) { (frame: WidgetFlow.Frame) -> Double in frame.y }
            for (_, row) in rows {
                let right: Double = row.map { (frame: WidgetFlow.Frame) -> Double in frame.x + frame.width }.max() ?? 0
                XCTAssertEqual(right, columns(count), "\(count) マスの行が埋まっている")
            }
        }
    }

    func testDefaultLayoutUsesAppWidgetsWithinTheLimit() {
        let layout: HomeLayout = DefaultLayout.make()
        let widgets: [HomeWidget] = layout.pages[0].widgets
        XCTAssertTrue(layout.hasAppWidgets)
        XCTAssertLessThanOrEqual(widgets.count, WidgetLimits.maximumPerPage)
        XCTAssertEqual(Set(widgets.map(\.id)).count, widgets.count)
        XCTAssertTrue(widgets.contains { $0.kind == .app(.weather) })
        XCTAssertFalse(widgets.contains { if case .clock = $0.kind { return true } else { return false } }, "時計は画面の上部にある")
        for widget in widgets {
            if let feature = widget.kind.feature {
                XCTAssertTrue(feature.state.canOpen, feature.rawValue)
            }
        }
    }

    func testGalleryOffersEveryOpenableAppExceptTimer() {
        let features: [AppFeature] = WidgetKind.galleryKinds.compactMap(\.feature)
        XCTAssertFalse(features.contains(.timer), "タイマーは専用のウィジェットがある")
        XCTAssertTrue(features.contains(.weather))
        XCTAssertTrue(features.contains(.settings))
        XCTAssertEqual(WidgetKind.app(.notes).title, "メモ")
        XCTAssertEqual(WidgetKind.note("").title, "付箋", "アプリのメモと区別する")
        XCTAssertEqual(WidgetKind.app(.weather).symbolName, FeatureIconStyle.of(.weather).symbol)
    }

    // MARK: - おすすめ

    func testRecommendedWidgetsAreAddedOnceAndOnlyTheMissingKinds() throws {
        var layout: HomeLayout = PersistenceFixtures.layout(pages: [[PersistenceFixtures.link("a")], []])
        try layout.addWidget(widget("mine", .app(.weather), .small), toPage: 1)
        try layout.addWidget(widget("sticky", .note("買い物")), toPage: 0)
        var number: Int = 0
        let added: Int = try layout.addRecommendedWidgets(toPage: 0) { () -> String in
            number += 1
            return "new\(number)"
        }
        let expected: Int = DefaultLayout.homeWidgets().count - 1
        XCTAssertEqual(added, expected, "天気はもう別のページにある")
        XCTAssertEqual(layout.pages[0].widgets.count, 1 + expected)
        XCTAssertEqual(layout.pages[0].widgets.first?.id, "sticky", "元のウィジェットはそのまま")
        XCTAssertEqual(try layout.addRecommendedWidgets(toPage: 0) { "again" }, 0, "2 回目は何も足さない")
        XCTAssertThrowsError(try layout.addRecommendedWidgets(toPage: 5) { "x" }) { error in
            XCTAssertEqual(error as? LayoutEditError, .pageNotFound)
        }
    }

    func testRecommendedWidgetsStopAtThePageLimit() throws {
        var layout: HomeLayout = PersistenceFixtures.layout(pages: [[]])
        for index in 0..<(WidgetLimits.maximumPerPage - 2) {
            try layout.addWidget(widget("clock\(index)", .clock(ClockWidgetStyle(isAnalog: false, showsSeconds: false))), toPage: 0)
        }
        var number: Int = 0
        let added: Int = try layout.addRecommendedWidgets(toPage: 0) { () -> String in
            number += 1
            return "new\(number)"
        }
        XCTAssertEqual(added, 2)
        XCTAssertEqual(layout.pages[0].widgets.count, WidgetLimits.maximumPerPage)
    }

    @MainActor
    func testSwitchingToWidgetsAddsRecommendationsOnlyWhenThereAreNoAppWidgets() async throws {
        let settings = SettingsStore(homeStyle: .icons)
        let home = HomeStore(layout: PersistenceFixtures.layout(pages: [[PersistenceFixtures.link("a")]]))
        XCTAssertFalse(home.layout.hasAppWidgets)

        XCTAssertEqual(HomeStyleSwitcher.apply(.icons, settings: settings, home: home), 0)
        XCTAssertFalse(home.canUndo)

        let added: Int = HomeStyleSwitcher.apply(.widgets, settings: settings, home: home)
        XCTAssertEqual(settings.homeStyle, .widgets)
        XCTAssertEqual(added, DefaultLayout.homeWidgets().count)
        XCTAssertTrue(home.layout.hasAppWidgets)
        XCTAssertEqual(home.layout.pages[0].items.map(\.id), ["a"], "アイコンの配置は消さない")

        // アイコンに戻して、またウィジェットにしても、二重には足さない
        HomeStyleSwitcher.apply(.icons, settings: settings, home: home)
        XCTAssertEqual(HomeStyleSwitcher.apply(.widgets, settings: settings, home: home), 0)
        XCTAssertEqual(home.layout.pages[0].widgets.count, DefaultLayout.homeWidgets().count)

        home.undo()
        XCTAssertFalse(home.layout.hasAppWidgets, "足したおすすめは取り消せる")
    }

    // MARK: - アプリの一覧

    func testLibraryListsOpenableFeaturesAndLinksFromPagesFoldersAndDock() {
        XCTAssertEqual(HomeLayout.libraryFeatures, AppFeature.allCases.filter { $0.state.canOpen })
        let folder = HomeItem(
            id: "folder",
            title: "フォルダ",
            symbolName: "folder",
            tint: RGBAColor(hex: 0x888888),
            action: .folder([PersistenceFixtures.link("in-folder"), PersistenceFixtures.feature(.notes)])
        )
        var duplicate: HomeItem = PersistenceFixtures.link("a")
        duplicate = HomeItem(id: "a-copy", title: "同じ URL", symbolName: duplicate.symbolName, tint: duplicate.tint, action: duplicate.action)
        let layout: HomeLayout = PersistenceFixtures.layout(
            pages: [[PersistenceFixtures.link("a"), folder, PersistenceFixtures.feature(.calculator)], [PersistenceFixtures.link("b")]],
            dock: [duplicate, PersistenceFixtures.link("c")]
        )
        XCTAssertEqual(layout.libraryLinks.map(\.id), ["a", "in-folder", "b", "c"], "機能は除き、同じ URL は 1 つ")
    }

    @MainActor
    func testRouterOpensFeaturesAndTheLibrary() async {
        let router = AppRouter()
        router.showAppLibrary()
        XCTAssertTrue(router.isShowingAppLibrary)
        router.open(.notes)
        XCTAssertEqual(router.sheet, .feature(.notes))
        XCTAssertFalse(router.isShowingAppLibrary, "開いたら一覧は閉じる")

        router.sheet = nil
        router.showAppLibrary()
        router.launch(PersistenceFixtures.link("a"))
        XCTAssertFalse(router.isShowingAppLibrary)
        XCTAssertNotNil(router.alert, "リンクは確認してから開く")

        router.showAppLibrary()
        router.beginEditing()
        XCTAssertFalse(router.isShowingAppLibrary, "編集を始めたら閉じる")
        router.showAppLibrary()
        XCTAssertFalse(router.isShowingAppLibrary, "編集中は開かない")
        router.open(.calculator)
        XCTAssertEqual(router.sheet, nil, "編集中はウィジェットから開かない")
    }

    func testWidgetRemovalMessageExplainsWhatIsKept() {
        XCTAssertTrue(AppAlert.confirmWidgetRemoval(widget("w", .app(.notes))).message.contains("データは消えません"))
        XCTAssertTrue(AppAlert.confirmWidgetRemoval(widget("w", .note("x"))).message.contains("付箋の内容も消えます"))
        XCTAssertFalse(AppAlert.confirmWidgetRemoval(widget("w", .calendar)).message.contains("消えます"))
    }

    // MARK: - 起動引数

    @MainActor
    func testLaunchOptionsCanSwitchTheStyleAndOpenTheLibrary() async {
        let options = LaunchOptions(arguments: ["MyHome", "-MyHomeHomeStyle", "icons", "-MyHomeShowAppLibrary"])
        XCTAssertEqual(options.homeStyle, .icons)
        XCTAssertTrue(options.showsAppLibrary)
        let settings = SettingsStore()
        XCTAssertEqual(settings.homeStyle, .widgets)
        options.apply(to: settings)
        XCTAssertEqual(settings.homeStyle, .icons)
        let router = AppRouter()
        options.apply(to: router)
        XCTAssertTrue(router.isShowingAppLibrary)

        let unknown = LaunchOptions(arguments: ["MyHome", "-MyHomeHomeStyle", "tiles"])
        XCTAssertNil(unknown.homeStyle)
        XCTAssertFalse(unknown.showsAppLibrary)
        unknown.apply(to: settings)
        XCTAssertEqual(settings.homeStyle, .icons, "知らない名前では変えない")
    }

    // MARK: - 保存形式（版 4）

    func testVersionFourRoundTripsAppWidgetsAndTheNewSettings() throws {
        var layout: HomeLayout = DefaultLayout.make()
        try layout.addWidget(widget("w.ai", .app(.aiAssistant), .medium), toPage: 1)
        let settings = SavedSettings(themeID: "forest", appearance: .dark, homeStyle: .icons, hasCompletedSetup: true)
        let saved = SavedHome(layout: layout, settings: settings)
        let data: Data = try HomeArchiveCodec.encode(saved)
        let text: String = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("\"schemaVersion\" : 4") || text.contains("\"schemaVersion\":4"), text.prefix(80).description)
        XCTAssertTrue(text.contains("\"feature\""))
        let decoded: SavedHome = try HomeArchiveCodec.decode(data)
        XCTAssertEqual(decoded, saved)
        XCTAssertEqual(decoded.layout.widget(id: "w.ai")?.kind, .app(.aiAssistant))
    }

    func testVersionThreeFileOpensAsWidgetsAndAsksForSetup() throws {
        let v3: String = """
        {"schemaVersion": 3, "layout": {"pages": [{"id": "p", "items": [], "widgets": [{"id": "w", "size": "small", "kind": {"type": "calendar"}}]}], "dock": []},
         "settings": {"themeID": "mono", "appearance": "light"}}
        """
        let saved: SavedHome = try HomeArchiveCodec.decode(PersistenceFixtures.json(v3))
        XCTAssertEqual(saved.settings.homeStyle, .widgets)
        XCTAssertFalse(saved.settings.hasCompletedSetup, "この版にした最初の起動で、初期設定を一度出す")
        XCTAssertEqual(saved.layout.pages[0].widgets.map(\.kind), [.calendar])
        XCTAssertFalse(saved.layout.hasAppWidgets)
    }

    func testUnknownAppOrStyleFallsBack() throws {
        let unknownStyle: String = """
        {"schemaVersion": 4, "layout": {"pages": [{"id": "p", "items": [], "widgets": []}], "dock": []},
         "settings": {"themeID": "mono", "homeStyle": "tiles", "hasCompletedSetup": "yes"}}
        """
        let saved: SavedHome = try HomeArchiveCodec.decode(PersistenceFixtures.json(unknownStyle))
        XCTAssertEqual(saved.settings.themeID, "mono", "ほかの設定は残す")
        XCTAssertEqual(saved.settings.homeStyle, .widgets)
        XCTAssertFalse(saved.settings.hasCompletedSetup)

        let unknownApp: String = """
        {"schemaVersion": 4, "layout": {"pages": [{"id": "p", "items": [], "widgets": [{"id": "w", "size": "small", "kind": {"type": "app", "feature": "camera"}}]}], "dock": []},
         "settings": {"themeID": "mono"}}
        """
        XCTAssertThrowsError(try HomeArchiveCodec.decode(PersistenceFixtures.json(unknownApp)), "知らない機能のウィジェットは読めない（壊れたファイルとして別名で残す）")
    }

    func testNewerVersionIsRefused() throws {
        let v5: String = """
        {"schemaVersion": 5, "layout": {"pages": [{"id": "p", "items": []}], "dock": []}, "settings": {"themeID": "mono"}}
        """
        XCTAssertThrowsError(try HomeArchiveCodec.decode(PersistenceFixtures.json(v5)))
    }
}
