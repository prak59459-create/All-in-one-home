import XCTest
@testable import MyHomeCore

/// T2-4 / T2-5: 編集モードの状態、リンク入力の検証、追加できる機能。
final class EditingFlowTests: XCTestCase {
    func testDraftAddsHTTPSWhenSchemeIsMissing() {
        var draft = LinkDraft()
        draft.urlText = "  www.apple.com/jp/ "
        XCTAssertEqual(draft.normalizedURL, "https://www.apple.com/jp/")
        draft.urlText = "shortcuts://"
        XCTAssertEqual(draft.normalizedURL, "shortcuts://")
    }

    func testDraftMakesItemWithDestinationAsDefaultTitle() throws {
        var draft = LinkDraft()
        draft.urlText = "https://Example.com/path"
        let item: HomeItem = try XCTUnwrap(draft.makeItem(id: "new"))
        XCTAssertEqual(item.title, "example.com")
        XCTAssertEqual(item.action, .openURL("https://Example.com/path"))
        draft.title = "  例のサイト  "
        XCTAssertEqual(draft.makeItem(id: "new")?.title, "例のサイト")
    }

    func testDraftRejectsDangerousOrEmptyURL() {
        var draft = LinkDraft()
        XCTAssertNil(draft.makeItem(id: "new"))
        XCTAssertNil(draft.urlHint, "何も入力していない時は説明を出さない")
        draft.urlText = "javascript:alert(1)"
        XCTAssertNil(draft.makeItem(id: "new"))
        guard case .error = draft.urlHint else {
            return XCTFail("危険なスキームは理由を表示する")
        }
    }

    func testDraftRejectsTooLongTitle() {
        var draft = LinkDraft()
        draft.urlText = "https://example.com"
        draft.title = String(repeating: "長", count: LayoutLimits.maximumTitleLength + 1)
        XCTAssertNotNil(draft.titleProblem)
        XCTAssertNil(draft.makeItem(id: "new"))
    }

    func testDraftHintsDistinguishKinds() {
        var draft = LinkDraft()
        draft.urlText = "http://example.com"
        guard case .warning = draft.urlHint else {
            return XCTFail("http は注意を出す")
        }
        draft.urlText = "music://"
        guard case .info(let text) = draft.urlHint else {
            return XCTFail("URL スキームは説明を出す")
        }
        XCTAssertTrue(text.contains("アプリ"), text)
    }

    func testNewItemIDsAreUniqueAndPrefixed() {
        let first: String = LinkDraft.newItemID()
        let second: String = LinkDraft.newItemID()
        XCTAssertNotEqual(first, second)
        XCTAssertTrue(first.hasPrefix("user."))
        XCTAssertLessThanOrEqual(first.count, LayoutLimits.maximumIDLength)
    }

    func testIconChoicesAreConsistentAndReadable() {
        XCTAssertEqual(Set(IconChoices.symbols).count, IconChoices.symbols.count)
        XCTAssertEqual(IconChoices.colors.count, IconChoices.colorNames.count)
        for color in IconChoices.colors {
            XCTAssertGreaterThanOrEqual(color.contrastRatio(with: color.readableForeground), 3.0, color.hexString)
        }
    }

    func testFeatureItemsMatchDefaultLayout() {
        let layout: HomeLayout = DefaultLayout.make()
        for feature in AppFeature.allCases {
            let item: HomeItem = DefaultLayout.item(for: feature)
            XCTAssertEqual(item.action, .feature(feature))
            if let placed = layout.item(id: item.id) {
                XCTAssertEqual(placed, item, "初期配置と追加で同じ見た目にする")
            }
        }
    }

    @MainActor
    func testEditingBlocksLaunchAndAllowsRemovalRequests() async {
        let router = AppRouter()
        let link: HomeItem = PersistenceFixtures.link("a")
        router.beginEditing()
        router.launch(link)
        XCTAssertNil(router.alert, "編集中はタップしても開かない")
        router.requestRemoval(of: DefaultLayout.item(for: .settings))
        XCTAssertNil(router.alert, "設定は削除の確認を出さない")
        router.requestRemoval(of: link)
        XCTAssertEqual(router.alert, .confirmRemoval(link))
        XCTAssertTrue(router.alert?.title.contains("リンク") ?? false)
        router.endEditing()
        XCTAssertFalse(router.isEditing)
    }

    @MainActor
    func testAddSheetAndNotice() async {
        let router = AppRouter()
        router.presentAddItem(pageIndex: 1)
        XCTAssertEqual(router.sheet, .addItem(pageIndex: 1))
        router.showNotice(title: "保存データについて", message: "説明")
        XCTAssertEqual(router.alert?.title, "保存データについて")
        XCTAssertEqual(router.alert?.message, "説明")
    }
}
