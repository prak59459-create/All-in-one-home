import XCTest
@testable import MyHomeCore

/// T2-5 / T2-6: 追加・削除・ページ内の並べ替え。失敗した時は配置を変えない。
final class LayoutEditingTests: XCTestCase {
    private let a: HomeItem = PersistenceFixtures.link("a")
    private let b: HomeItem = PersistenceFixtures.link("b")
    private let c: HomeItem = PersistenceFixtures.link("c")
    private let d: HomeItem = PersistenceFixtures.link("d")

    private func ids(_ layout: HomeLayout, page: Int = 0) -> [String] {
        layout.pages[page].items.map(\.id)
    }

    func testAppendAddsToEndOfPage() throws {
        var layout: HomeLayout = PersistenceFixtures.layout(pages: [[a], [b]])
        try layout.append(c, toPage: 1)
        XCTAssertEqual(ids(layout, page: 1), ["b", "c"])
    }

    func testAppendRejectsDuplicateMissingPageAndLimit() {
        var layout: HomeLayout = PersistenceFixtures.layout(pages: [[a]], dock: [b])
        XCTAssertThrowsError(try layout.append(b, toPage: 0)) { error in
            XCTAssertEqual(error as? LayoutEditError, .duplicateID)
        }
        XCTAssertThrowsError(try layout.append(c, toPage: 5)) { error in
            XCTAssertEqual(error as? LayoutEditError, .pageNotFound)
        }
        var full: HomeLayout = SampleLayout.stress(itemCount: LayoutLimits.maximumItems, itemsPerPage: 500)
        XCTAssertEqual(full.itemCount, LayoutLimits.maximumItems)
        XCTAssertThrowsError(try full.append(c, toPage: 0)) { error in
            XCTAssertEqual(error as? LayoutEditError, .itemLimitReached)
        }
        XCTAssertEqual(layout, PersistenceFixtures.layout(pages: [[a]], dock: [b]), "失敗しても変えない")
    }

    func testRemoveFromPageAndDock() throws {
        var layout: HomeLayout = PersistenceFixtures.layout(pages: [[a, b]], dock: [c])
        XCTAssertEqual(try layout.removeItem(id: "a"), a)
        XCTAssertEqual(try layout.removeItem(id: "c"), c)
        XCTAssertEqual(ids(layout), ["b"])
        XCTAssertTrue(layout.dock.isEmpty)
    }

    func testSettingsCannotBeRemoved() {
        let settings: HomeItem = PersistenceFixtures.feature(.settings)
        var layout: HomeLayout = PersistenceFixtures.layout(pages: [[a]], dock: [settings])
        XCTAssertFalse(settings.isRemovable)
        XCTAssertTrue(PersistenceFixtures.feature(.notes).isRemovable)
        XCTAssertThrowsError(try layout.removeItem(id: settings.id)) { error in
            XCTAssertEqual(error as? LayoutEditError, .notRemovable)
        }
        XCTAssertThrowsError(try layout.removeItem(id: "missing")) { error in
            XCTAssertEqual(error as? LayoutEditError, .itemNotFound)
        }
        XCTAssertEqual(layout.dock, [settings])
    }

    func testMoveOntoForwardPlacesAfterTarget() throws {
        var layout: HomeLayout = PersistenceFixtures.layout(pages: [[a, b, c, d]])
        try layout.moveItem(id: "a", onto: "c")
        XCTAssertEqual(ids(layout), ["b", "c", "a", "d"])
    }

    func testMoveOntoBackwardPlacesBeforeTarget() throws {
        var layout: HomeLayout = PersistenceFixtures.layout(pages: [[a, b, c, d]])
        try layout.moveItem(id: "d", onto: "b")
        XCTAssertEqual(ids(layout), ["a", "d", "b", "c"])
    }

    func testMoveOntoItselfDoesNothing() throws {
        var layout: HomeLayout = PersistenceFixtures.layout(pages: [[a, b]])
        try layout.moveItem(id: "a", onto: "a")
        XCTAssertEqual(ids(layout), ["a", "b"])
    }

    func testMoveWithinDock() throws {
        var layout: HomeLayout = PersistenceFixtures.layout(pages: [[]], dock: [a, b, c])
        try layout.moveItem(id: "c", onto: "a")
        XCTAssertEqual(layout.dock.map(\.id), ["c", "a", "b"])
    }

    func testMoveOntoItemInOtherPageOrDock() throws {
        var layout: HomeLayout = PersistenceFixtures.layout(pages: [[a], [b, c]], dock: [d])
        try layout.moveItem(id: "a", onto: "c")
        XCTAssertEqual(ids(layout, page: 1), ["b", "a", "c"], "別のページの項目に重ねると、その位置に入る")
        try layout.moveItem(id: "b", onto: "d")
        XCTAssertEqual(layout.dock.map(\.id), ["b", "d"])
        XCTAssertThrowsError(try layout.moveItem(id: "a", onto: "missing")) { error in
            XCTAssertEqual(error as? LayoutEditError, .itemNotFound)
        }
    }

    func testMoveIntoFullDockIsRejected() {
        let dock: [HomeItem] = (0..<HomeLayout.maximumDockItems).map { (index: Int) -> HomeItem in PersistenceFixtures.link("d\(index)") }
        var layout: HomeLayout = PersistenceFixtures.layout(pages: [[a]], dock: dock)
        XCTAssertThrowsError(try layout.moveItem(id: "a", onto: "d0")) { error in
            XCTAssertEqual(error as? LayoutEditError, .dockFull)
        }
        XCTAssertThrowsError(try layout.moveItem(id: "a", to: .dock)) { error in
            XCTAssertEqual(error as? LayoutEditError, .dockFull)
        }
        try? layout.moveItem(id: "d0", onto: "d3")
        XCTAssertEqual(layout.dock.count, HomeLayout.maximumDockItems, "Dock の中の並べ替えはできる")
    }

    func testMoveToDestinationEnd() throws {
        var layout: HomeLayout = PersistenceFixtures.layout(pages: [[a, b], [c]], dock: [d])
        try layout.moveItem(id: "a", to: .page(1))
        XCTAssertEqual(ids(layout, page: 1), ["c", "a"])
        try layout.moveItem(id: "d", to: .page(0))
        XCTAssertEqual(ids(layout, page: 0), ["b", "d"])
        try layout.moveItem(id: "b", to: .dock)
        XCTAssertEqual(layout.dock.map(\.id), ["b"])
        XCTAssertThrowsError(try layout.moveItem(id: "b", to: .page(9))) { error in
            XCTAssertEqual(error as? LayoutEditError, .pageNotFound)
        }
    }

    func testMoveByOffsetStopsAtEdges() throws {
        var layout: HomeLayout = PersistenceFixtures.layout(pages: [[a, b, c]])
        try layout.moveItem(id: "a", by: 1)
        XCTAssertEqual(ids(layout), ["b", "a", "c"])
        try layout.moveItem(id: "a", by: 10)
        XCTAssertEqual(ids(layout), ["b", "c", "a"])
        try layout.moveItem(id: "a", by: -10)
        XCTAssertEqual(ids(layout), ["a", "b", "c"])
        try layout.moveItem(id: "a", by: -1)
        XCTAssertEqual(ids(layout), ["a", "b", "c"])
    }

    func testLocationFindsPageAndDock() {
        let layout: HomeLayout = PersistenceFixtures.layout(pages: [[a], [b]], dock: [c])
        XCTAssertEqual(layout.location(ofItem: "b"), ItemLocation(container: .page(1), index: 0))
        XCTAssertEqual(layout.location(ofItem: "c"), ItemLocation(container: .dock, index: 0))
        XCTAssertNil(layout.location(ofItem: "z"))
        XCTAssertEqual(layout.item(id: "b"), b)
    }

    @MainActor
    func testStoreAppliesEditsAndReportsChanges() async throws {
        let store = HomeStore(layout: PersistenceFixtures.layout(pages: [[a, b]]))
        var changes: Int = 0
        store.onChange = { changes += 1 }
        try store.add(c, toPage: 0)
        try store.move(itemID: "c", onto: "a")
        try store.remove(itemID: "b")
        XCTAssertEqual(store.layout.pages[0].items.map(\.id), ["c", "a"])
        XCTAssertEqual(changes, 3)
    }

    @MainActor
    func testStoreDoesNotReportFailedOrEmptyEdits() async throws {
        let store = HomeStore(layout: PersistenceFixtures.layout(pages: [[a, b]]))
        var changes: Int = 0
        store.onChange = { changes += 1 }
        XCTAssertThrowsError(try store.remove(itemID: "missing"))
        try store.move(itemID: "a", by: -1)
        XCTAssertEqual(changes, 0)
    }
}
