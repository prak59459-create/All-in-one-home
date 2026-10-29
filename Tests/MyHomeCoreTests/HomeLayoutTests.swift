import XCTest
@testable import MyHomeCore

final class HomeLayoutTests: XCTestCase {
    func testDefaultLayoutHasUniqueItemIDs() {
        let layout: HomeLayout = DefaultLayout.make()
        let ids: [String] = layout.pages.flatMap { $0.items.map(\.id) } + layout.dock.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(layout.itemCount, ids.count)
    }

    func testDefaultLayoutHasUniquePageIDs() {
        let ids: [String] = DefaultLayout.make().pages.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testDefaultLayoutURLsPassPolicy() {
        let layout: HomeLayout = DefaultLayout.make()
        for item in layout.pages.flatMap(\.items) + layout.dock {
            guard case .openURL(let raw) = item.action else { continue }
            guard case .allowed = URLPolicy.check(raw) else {
                return XCTFail("\(item.id) の URL が検証を通らない: \(raw)")
            }
        }
    }

    func testDefaultLayoutFitsDock() {
        XCTAssertLessThanOrEqual(DefaultLayout.dock().count, HomeLayout.maximumDockItems)
    }

    func testEmptyLayoutGetsOneEmptyPage() {
        let layout = HomeLayout(pages: [], dock: []).normalized()
        XCTAssertEqual(layout.pages.count, 1)
        XCTAssertEqual(layout.itemCount, 0)
    }

    func testDockOverflowMovesToLastPageWithoutLosingItems() {
        let dock: [HomeItem] = SampleLayout.stress(itemCount: 8, itemsPerPage: 8).pages[0].items
        let layout = HomeLayout(pages: [HomePage(id: "p", items: [])], dock: dock).normalized()
        XCTAssertEqual(layout.dock.count, HomeLayout.maximumDockItems)
        XCTAssertEqual(layout.pages[0].items.count, 8 - HomeLayout.maximumDockItems)
        XCTAssertEqual(layout.itemCount, 8)
    }

    func testStressLayoutSplitsPages() {
        let layout: HomeLayout = SampleLayout.stress(itemCount: 150, itemsPerPage: 60)
        XCTAssertEqual(layout.pages.map { $0.items.count }, [60, 60, 30])
        XCTAssertEqual(layout.itemCount, 150 + DefaultLayout.dock().count)
    }

    func testStressLayoutHandlesZeroAndOneItem() {
        XCTAssertEqual(SampleLayout.stress(itemCount: 0, itemsPerPage: 60).pages.count, 1)
        XCTAssertEqual(SampleLayout.stress(itemCount: 1, itemsPerPage: 60).pages[0].items.count, 1)
    }

    func testStressLayoutIsCapped() {
        let layout: HomeLayout = SampleLayout.stress(itemCount: 1_000_000, itemsPerPage: 500)
        XCTAssertEqual(layout.itemCount, SampleLayout.maximumItemCount + DefaultLayout.dock().count)
    }

    @MainActor
    func testHomeStoreNormalizesLayout() async {
        let store = HomeStore(layout: HomeLayout(pages: [], dock: []))
        XCTAssertEqual(store.layout.pages.count, 1)
    }
}
