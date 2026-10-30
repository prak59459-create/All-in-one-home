import XCTest
@testable import MyHomeCore

final class LaunchTests: XCTestCase {
    func testPlannedFeatureIsExplainedInsteadOfOpened() {
        // Phase 7 で準備中の機能はなくなったので、状態を指定して確かめる
        XCTAssertEqual(LaunchPlanner.plan(for: .weather, state: .planned(phase: 7)), .explainUnavailable(.weather))
        XCTAssertEqual(LaunchPlanner.plan(for: .weather, state: .osLimited), .explainUnavailable(.weather))
        XCTAssertEqual(LaunchPlanner.plan(for: .weather, state: .needsPoC), .explainUnavailable(.weather))
        XCTAssertEqual(LaunchPlanner.plan(for: .weather, state: .available), .openFeature(.weather))
        XCTAssertEqual(LaunchPlanner.plan(for: .feature(.weather)), .openFeature(.weather), "天気は Phase 7 で使えるようになった")
    }

    func testAvailableAndStubFeaturesOpen() {
        XCTAssertEqual(LaunchPlanner.plan(for: .feature(.settings)), .openFeature(.settings))
        XCTAssertEqual(LaunchPlanner.plan(for: .feature(.aiAssistant)), .openFeature(.aiAssistant))
    }

    func testMiniAppsOpenSincePhase5() {
        let miniApps: [AppFeature] = [.notes, .tasks, .calculator, .unitConverter, .textTools]
        for feature in miniApps {
            XCTAssertEqual(LaunchPlanner.plan(for: .feature(feature)), .openFeature(feature), feature.rawValue)
            XCTAssertNil(item(.feature(feature)).badge, "使える機能に「準備中」の印を付けない")
        }
    }

    func testURLIsConfirmedBeforeOpening() {
        guard case .confirmURL(let checked) = LaunchPlanner.plan(for: .openURL("https://www.swift.org")) else {
            return XCTFail("確認ダイアログを経由していない")
        }
        XCTAssertEqual(checked.destination, "www.swift.org")
    }

    func testBadURLIsRejected() {
        XCTAssertEqual(LaunchPlanner.plan(for: .openURL("javascript:void(0)")), .rejectURL(.blockedScheme("javascript")))
    }

    func testBadgesDistinguishLinksStubsAndPlannedItems() {
        XCTAssertEqual(item(.openURL("https://example.com")).badge, .externalLink)
        XCTAssertEqual(item(.feature(.aiAssistant)).badge, .stub)
        XCTAssertNil(item(.feature(.weather)).badge, "天気は Phase 7 で使えるようになった")
        XCTAssertEqual(HomeItem.badge(for: .planned(phase: 9)), .planned)
        XCTAssertEqual(HomeItem.badge(for: .osLimited), .planned)
        XCTAssertNil(item(.feature(.settings)).badge)
    }

    func testAccessibilityHintsMentionState() {
        XCTAssertTrue(item(.openURL("https://example.com")).accessibilityHint.contains("確認"))
        XCTAssertTrue(item(.feature(.aiAssistant)).accessibilityHint.contains("スタブ"))
        XCTAssertTrue(HomeItem.featureHint(for: .planned(phase: 9)).contains("準備中"))
        XCTAssertEqual(item(.feature(.weather)).accessibilityHint, "アプリ内の機能を開きます")
    }

    @MainActor
    func testRouterShowsConfirmationForLink() async {
        let router = AppRouter()
        router.launch(item(.openURL("https://www.swift.org")))
        guard case .confirmURL = router.alert else {
            return XCTFail("確認ダイアログが出ていない")
        }
        XCTAssertNil(router.sheet)
        router.isShowingAlert = false
        XCTAssertNil(router.alert)
    }

    @MainActor
    func testRouterShowsMessageForRejectedLinkAndOpenFailure() async {
        let router = AppRouter()
        router.launch(item(.openURL("file:///private")))
        XCTAssertEqual(router.alert, .message(URLRejection.blockedScheme("file").message))

        guard case .allowed(let checked) = URLPolicy.check("shortcuts://") else {
            return XCTFail("前提の URL が拒否された")
        }
        router.reportOpenFailure(checked)
        guard case .message(let text) = router.alert else {
            return XCTFail("失敗の案内が出ていない")
        }
        XCTAssertTrue(text.contains("shortcuts"))
    }

    @MainActor
    func testRouterOpensSheets() async {
        let router = AppRouter()
        router.launch(item(.feature(.featureStatus)))
        XCTAssertEqual(router.sheet, .feature(.featureStatus))
        router.launch(item(.feature(.weather)))
        XCTAssertEqual(router.sheet, .feature(.weather), "天気は Phase 7 で使えるようになった")
        router.launch(item(.feature(.calculator)))
        XCTAssertEqual(router.sheet, .feature(.calculator), "電卓は Phase 5 で使えるようになった")
        router.launch(item(.feature(.timer)))
        XCTAssertEqual(router.sheet, .feature(.timer), "タイマーは Phase 4 で使えるようになった")
    }

    @MainActor
    func testLaunchOptionsCanOpenAMiniApp() async {
        let router = AppRouter()
        LaunchOptions(arguments: ["MyHome", "-MyHomeOpenFeature", "calculator"]).apply(to: router)
        XCTAssertEqual(router.sheet, .feature(.calculator))
        XCTAssertEqual(LaunchOptions(arguments: ["MyHome", "-MyHomeOpenFeature", "weather"]).openFeature, .weather)
        XCTAssertNil(LaunchOptions(arguments: ["MyHome", "-MyHomeOpenFeature", "unknown"]).openFeature)
    }

    func testLaunchOptionsParseSampleArguments() {
        let options = LaunchOptions(arguments: ["MyHome", "-MyHomeSampleItems", "150", "-MyHomeSampleItemsPerPage", "150"])
        XCTAssertEqual(options.sampleItemCount, 150)
        XCTAssertEqual(options.initialLayout().pages.count, 1)
        XCTAssertEqual(options.initialLayout().pages[0].items.count, 150)
    }

    @MainActor
    func testLaunchOptionsCanStartEditingWithFolderOpen() async {
        let options = LaunchOptions(arguments: ["MyHome", "-MyHomeStartEditing", "-MyHomeOpenFolder", "folder.check"])
        XCTAssertTrue(options.startsEditing)
        XCTAssertEqual(options.openFolderID, "folder.check")
        let router = AppRouter()
        options.apply(to: router)
        XCTAssertTrue(router.isEditing)
        XCTAssertEqual(router.openFolderID, "folder.check")
        let plain = LaunchOptions(arguments: ["MyHome"])
        XCTAssertFalse(plain.startsEditing)
        XCTAssertNil(plain.openFolderID)
    }

    func testLaunchOptionsDefaultToNormalLayout() {
        let options = LaunchOptions(arguments: ["MyHome", "-MyHomeSampleItems"])
        XCTAssertNil(options.sampleItemCount)
        XCTAssertEqual(options.initialLayout(), DefaultLayout.make())
    }

    func testFeatureStatusEntriesAreUniqueAndCoverEveryState() {
        let entries: [FeatureStatusEntry] = FeatureStatusCatalog.entries()
        XCTAssertEqual(Set(entries.map(\.id)).count, entries.count)
        XCTAssertTrue(entries.contains { $0.state == .available })
        XCTAssertTrue(entries.contains { $0.state == .stub })
        XCTAssertTrue(entries.contains { $0.state == .osLimited })
    }

    private func item(_ action: HomeItemAction) -> HomeItem {
        HomeItem(id: "test", title: "テスト", symbolName: "star", tint: .black, action: action)
    }
}
