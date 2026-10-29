import Foundation
import XCTest
@testable import MyHomeCore

/// T3-1〜T3-3: ページの追加・削除・並べ替え、フォルダの作成・出し入れ・解除、名前などの変更。
final class FolderAndPageTests: XCTestCase {
    private let a: HomeItem = PersistenceFixtures.link("a")
    private let b: HomeItem = PersistenceFixtures.link("b")
    private let c: HomeItem = PersistenceFixtures.link("c")

    private func folderLayout() throws -> HomeLayout {
        var layout: HomeLayout = PersistenceFixtures.layout(pages: [[a, b], [c]])
        try layout.makeFolder(containing: "a", folderID: "f")
        return layout
    }

    func testMakeFolderReplacesItemInPlace() throws {
        let layout: HomeLayout = try folderLayout()
        let folder: HomeItem = layout.pages[0].items[0]
        XCTAssertEqual(folder.id, "f")
        XCTAssertEqual(folder.title, HomeLayout.defaultFolderTitle)
        XCTAssertEqual(folder.folderItems, [a])
        XCTAssertEqual(layout.location(ofItem: "a"), ItemLocation(container: .folder("f"), index: 0))
        XCTAssertEqual(layout.itemCount, 4, "フォルダ自体も1件と数える")
    }

    func testNoFolderInsideFolder() throws {
        var layout: HomeLayout = try folderLayout()
        XCTAssertThrowsError(try layout.makeFolder(containing: "a", folderID: "g")) { error in
            XCTAssertEqual(error as? LayoutEditError, .folderInFolder, "フォルダの中の項目からは作れない")
        }
        XCTAssertThrowsError(try layout.makeFolder(containing: "f", folderID: "g")) { error in
            XCTAssertEqual(error as? LayoutEditError, .folderInFolder)
        }
        try layout.makeFolder(containing: "c", folderID: "g")
        XCTAssertThrowsError(try layout.moveItem(id: "g", to: .folder("f"))) { error in
            XCTAssertEqual(error as? LayoutEditError, .folderInFolder)
        }
        XCTAssertThrowsError(try layout.moveItem(id: "g", onto: "a")) { error in
            XCTAssertEqual(error as? LayoutEditError, .folderInFolder, "フォルダの中の項目に重ねても入れない")
        }
    }

    func testDroppingOntoFolderPutsItemInside() throws {
        var layout: HomeLayout = try folderLayout()
        try layout.moveItem(id: "c", onto: "f")
        XCTAssertEqual(layout.item(id: "f")?.folderItems?.map(\.id), ["a", "c"])
        XCTAssertTrue(layout.pages[1].items.isEmpty)
    }

    func testMovingLastItemOutRemovesFolder() throws {
        var layout: HomeLayout = try folderLayout()
        try layout.moveItem(id: "a", to: .page(1))
        XCTAssertNil(layout.item(id: "f"), "空のフォルダは取り除く")
        XCTAssertEqual(layout.pages[0].items.map(\.id), ["b"])
        XCTAssertEqual(layout.pages[1].items.map(\.id), ["c", "a"])
    }

    func testReorderInsideFolder() throws {
        var layout: HomeLayout = try folderLayout()
        try layout.moveItem(id: "c", to: .folder("f"))
        try layout.moveItem(id: "c", onto: "a")
        XCTAssertEqual(layout.item(id: "f")?.folderItems?.map(\.id), ["c", "a"])
        try layout.moveItem(id: "c", by: 1)
        XCTAssertEqual(layout.item(id: "f")?.folderItems?.map(\.id), ["a", "c"])
    }

    func testRemovingFolderReturnsItemsToItsPlace() throws {
        var layout: HomeLayout = try folderLayout()
        try layout.moveItem(id: "c", to: .folder("f"))
        try layout.removeItem(id: "f")
        XCTAssertEqual(layout.pages[0].items.map(\.id), ["a", "c", "b"], "フォルダの解除で項目は消えない")
    }

    func testRemovingItemInsideFolder() throws {
        var layout: HomeLayout = try folderLayout()
        try layout.moveItem(id: "c", to: .folder("f"))
        try layout.removeItem(id: "c")
        XCTAssertEqual(layout.item(id: "f")?.folderItems?.map(\.id), ["a"])
    }

    func testDissolvingFolderInFullDockKeepsEveryItem() throws {
        var dock: [HomeItem] = []
        for index in 0..<5 {
            dock.append(PersistenceFixtures.link("d\(index)"))
        }
        var layout: HomeLayout = PersistenceFixtures.layout(pages: [[a, b, c]], dock: dock)
        try layout.makeFolder(containing: "a", folderID: "f")
        try layout.moveItem(id: "b", to: .folder("f"))
        try layout.moveItem(id: "c", to: .folder("f"))
        try layout.moveItem(id: "f", to: .dock)
        try layout.removeItem(id: "f")
        XCTAssertEqual(layout.dock.count, HomeLayout.maximumDockItems)
        XCTAssertEqual(layout.itemCount, 8, "Dock に入らない分は最後のページへ移す")
    }

    func testUpdateItemChangesLooksOnly() throws {
        var layout: HomeLayout = try folderLayout()
        try layout.updateItem(id: "a", title: "新しい名前", symbolName: "star.fill", tint: RGBAColor(hex: 0x16A34A))
        let updated: HomeItem? = layout.item(id: "a")
        XCTAssertEqual(updated?.title, "新しい名前")
        XCTAssertEqual(updated?.symbolName, "star.fill")
        XCTAssertEqual(updated?.action, a.action, "リンク先は変えない")
        let long: String = String(repeating: "長", count: LayoutLimits.maximumTitleLength + 1)
        XCTAssertThrowsError(try layout.updateItem(id: "f", title: long, symbolName: "x", tint: .black)) { error in
            XCTAssertEqual(error as? LayoutEditError, .titleTooLong)
        }
    }

    func testPagesCanBeAddedReorderedAndRemovedWhenEmpty() throws {
        var layout: HomeLayout = PersistenceFixtures.layout(pages: [[a], [b]])
        XCTAssertEqual(try layout.addPage(id: "new"), 2)
        XCTAssertThrowsError(try layout.addPage(id: "new")) { error in
            XCTAssertEqual(error as? LayoutEditError, .duplicateID)
        }
        try layout.movePage(at: 2, by: -2)
        XCTAssertEqual(layout.pages.map(\.id), ["new", "page.0", "page.1"])
        XCTAssertThrowsError(try layout.removePage(at: 1)) { error in
            XCTAssertEqual(error as? LayoutEditError, .pageNotEmpty, "項目を失わないよう、空のページだけ削除できる")
        }
        try layout.removePage(at: 0)
        XCTAssertEqual(layout.pages.map(\.id), ["page.0", "page.1"])
    }

    func testLastPageCannotBeRemovedAndPageLimitHolds() throws {
        var layout: HomeLayout = PersistenceFixtures.layout(pages: [[]])
        XCTAssertThrowsError(try layout.removePage(at: 0)) { error in
            XCTAssertEqual(error as? LayoutEditError, .lastPage)
        }
        for index in 1..<LayoutLimits.maximumPages {
            try layout.addPage(id: "p\(index)")
        }
        XCTAssertThrowsError(try layout.addPage(id: "over")) { error in
            XCTAssertEqual(error as? LayoutEditError, .pageLimitReached)
        }
    }

    func testFolderRoundTripsAndNestedFolderIsRejected() throws {
        let layout: HomeLayout = try folderLayout()
        let saved = SavedHome(layout: layout, settings: .defaults)
        XCTAssertEqual(try HomeArchiveCodec.decode(try HomeArchiveCodec.encode(saved)), saved)

        let inner = HomeItem(id: "inner", title: "中", symbolName: "folder.fill", tint: .black, action: .folder([b]))
        let outer = HomeItem(id: "outer", title: "外", symbolName: "folder.fill", tint: .black, action: .folder([inner]))
        let nested = SavedHome(layout: PersistenceFixtures.layout(pages: [[outer]]), settings: .defaults)
        XCTAssertThrowsError(try HomeArchiveCodec.decode(try HomeArchiveCodec.encode(nested))) { error in
            XCTAssertEqual(error as? HomeArchiveError, .invalid([.nestedFolder(itemID: "inner")]))
        }
    }

    func testDuplicateIDInsideFolderIsRejected() throws {
        let folder = HomeItem(id: "f", title: "F", symbolName: "folder.fill", tint: .black, action: .folder([a]))
        let saved = SavedHome(layout: PersistenceFixtures.layout(pages: [[folder, a]]), settings: .defaults)
        XCTAssertThrowsError(try HomeArchiveCodec.decode(try HomeArchiveCodec.encode(saved))) { error in
            XCTAssertEqual(error as? HomeArchiveError, .invalid([.duplicateItemID("a")]))
        }
    }

    func testVersionOneFileIsMigrated() throws {
        // Phase 2 の版 1 の形式（フォルダなし）をそのまま読み、版 2 として書き戻す
        let v1: String = """
        {"schemaVersion": 1, "layout": {"pages": [{"id": "p", "items": [
          {"id": "a", "title": "A", "symbolName": "link", "tint": "#2563EB", "action": {"kind": "url", "url": "https://example.com"}}]}], "dock": []},
         "settings": {"themeID": "mono", "appearance": "dark"}}
        """
        let saved: SavedHome = try HomeArchiveCodec.decode(PersistenceFixtures.json(v1))
        XCTAssertEqual(saved.schemaVersion, SavedHome.currentSchemaVersion)
        XCTAssertEqual(saved.layout.pages[0].items.map(\.id), ["a"])
        XCTAssertEqual(saved.settings, SavedSettings(themeID: "mono", appearance: .dark))
    }

    func testEmptyFoldersAreDroppedOnLoad() throws {
        let empty = HomeItem(id: "f", title: "F", symbolName: "folder.fill", tint: .black, action: .folder([]))
        let saved = SavedHome(layout: PersistenceFixtures.layout(pages: [[empty, a]]), settings: .defaults)
        let decoded: SavedHome = try HomeArchiveCodec.decode(try HomeArchiveCodec.encode(saved))
        XCTAssertEqual(decoded.layout.pages[0].items.map(\.id), ["a"])
    }

    func testFolderOpensFromRouter() async {
        let folder = HomeItem(id: "f", title: "F", symbolName: "folder.fill", tint: .black, action: .folder([a]))
        XCTAssertEqual(LaunchPlanner.plan(for: folder.action), .openFolder)
        XCTAssertNil(folder.badge)
        XCTAssertTrue(folder.accessibilityHint.contains("1 個"))
    }
}
