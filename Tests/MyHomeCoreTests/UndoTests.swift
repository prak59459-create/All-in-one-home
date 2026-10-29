import XCTest
@testable import MyHomeCore

/// T3-4: 取り消し・やり直し（F0033、F0034、F0160）。
final class UndoTests: XCTestCase {
    @MainActor
    func testUndoAndRedoRestoreLayouts() async throws {
        let store = HomeStore(layout: PersistenceFixtures.layout(pages: [[PersistenceFixtures.link("a"), PersistenceFixtures.link("b")]]))
        let original: HomeLayout = store.layout
        try store.remove(itemID: "a")
        try store.makeFolder(containing: "b", folderID: "f")
        XCTAssertTrue(store.canUndo)
        store.undo()
        XCTAssertEqual(store.layout.pages[0].items.map(\.id), ["b"])
        store.undo()
        XCTAssertEqual(store.layout, original)
        XCTAssertFalse(store.canUndo)
        store.redo()
        store.redo()
        XCTAssertEqual(store.layout.pages[0].items.map(\.id), ["f"])
        XCTAssertFalse(store.canRedo)
    }

    @MainActor
    func testNewEditClearsRedoAndFailedEditKeepsHistory() async throws {
        let store = HomeStore(layout: PersistenceFixtures.layout(pages: [[PersistenceFixtures.link("a")]]))
        try store.addPage(id: "p2")
        store.undo()
        XCTAssertTrue(store.canRedo)
        try store.addPage(id: "p3")
        XCTAssertFalse(store.canRedo, "新しい操作をしたらやり直しは消える")
        XCTAssertThrowsError(try store.removePage(at: 0))
        XCTAssertEqual(store.undoStack.count, 1, "失敗した操作は履歴に残さない")
    }

    @MainActor
    func testUndoHistoryIsCapped() async throws {
        let store = HomeStore(layout: PersistenceFixtures.layout(pages: [[]]))
        for index in 0..<(HomeStore.maximumUndoSteps + 5) {
            try store.addPage(id: "p\(index)")
        }
        XCTAssertEqual(store.undoStack.count, HomeStore.maximumUndoSteps)
    }

    @MainActor
    func testUndoIsSaved() async throws {
        let storage = MemoryArchiveStorage()
        let boot: AppBootstrap = AppBootstrap.make(storage: storage, delay: .milliseconds(1))
        let firstID: String = boot.home.layout.pages[0].items[0].id
        try boot.home.remove(itemID: firstID)
        await boot.persistence.flush()
        boot.home.undo()
        await boot.persistence.flush()
        let saved: SavedHome = try HomeArchiveCodec.decode(try XCTUnwrap(storage.data))
        XCTAssertEqual(saved.layout.pages[0].items[0].id, firstID, "取り消した結果も保存する")
    }
}
