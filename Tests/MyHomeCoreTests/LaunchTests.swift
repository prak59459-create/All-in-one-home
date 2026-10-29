import XCTest
@testable import MyHomeCore

final class LaunchTests: XCTestCase {
    func testPlannedFeatureIsExplainedInsteadOfOpened() {
        XCTAssertEqual(LaunchPlanner.plan(for: .feature(.notes)), .explainUnavailable(.notes))
    }

    func testAvailableAndStubFeaturesOpen() {
        XCTAssertEqual(LaunchPlanner.plan(for: .feature(.settings)), .openFeature(.settings))
        XCTAssertEqual(LaunchPlanner.plan(for: .feature(.aiAssistant)), .openFeature(.aiAssistant))
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
        XCTAssertEqual(item(.feature(.calculator)).badge, .planned)
        XCTAssertNil(item(.feature(.settings)).badge)
    }

    func testAccessibilityHintsMentionState() {
        XCTAssertTrue(item(.openURL("https://example.com")).accessibilityHint.contains("確認"))
        XCTAssertTrue(item(.feature(.aiAssistant)).accessibilityHint.contains("スタブ"))
        XCTAssertTrue(item(.feature(.timer)).accessibilityHint.contains("準備中"))
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
        router.launch(item(.feature(.timer)))
        XCTAssertEqual(router.sheet, .unavailable(.timer))
    }

    func testLaunchOptionsParseSampleArguments() {
        let options = LaunchOptions(arguments: ["MyHome", "-MyHomeSampleItems", "150", "-MyHomeSampleItemsPerPage", "150"])
        XCTAssertEqual(options.sampleItemCount, 150)
        XCTAssertEqual(options.initialLayout().pages.count, 1)
        XCTAssertEqual(options.initialLayout().pages[0].items.count, 150)
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
