import Observation

/// ホーム画面の配置を持つストア。編集は HomeLayout+Editing などの操作を通して行い、失敗した時は配置を変えない。
/// 変更の前の配置を履歴に残し、取り消し・やり直しができる（F0032–F0034、F0160。この起動中だけ）。
/// @Observable によりプロパティ単位で変更が追跡され、読んでいる View だけが再描画される。
@MainActor
@Observable
final class HomeStore {
    /// 取り消せる操作の数。配置は値型で、変わっていない部分は配列の領域を共有するため、履歴のメモリは小さい。
    static let maximumUndoSteps: Int = 30

    private(set) var layout: HomeLayout
    private(set) var undoStack: [HomeLayout] = []
    private(set) var redoStack: [HomeLayout] = []
    /// 配置が変わった時に呼ぶ（保存の予約に使う。PersistenceController.attach が設定する）。
    @ObservationIgnored var onChange: (@MainActor () -> Void)?

    init(layout: HomeLayout = DefaultLayout.make()) {
        self.layout = layout.normalized()
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func add(_ item: HomeItem, toPage pageIndex: Int) throws {
        try edit { layout in try layout.append(item, toPage: pageIndex) }
    }

    func remove(itemID: String) throws {
        try edit { layout in try layout.removeItem(id: itemID) }
    }

    func move(itemID: String, onto targetID: String) throws {
        try edit { layout in try layout.moveItem(id: itemID, onto: targetID) }
    }

    func move(itemID: String, by offset: Int) throws {
        try edit { layout in try layout.moveItem(id: itemID, by: offset) }
    }

    func move(itemID: String, to destination: ItemDestination) throws {
        try edit { layout in try layout.moveItem(id: itemID, to: destination) }
    }

    func update(itemID: String, title: String, symbolName: String, tint: RGBAColor, imageName: String?) throws {
        try edit { layout in
            try layout.updateItem(id: itemID, title: title, symbolName: symbolName, tint: tint, imageName: imageName)
        }
    }

    func addWidget(_ widget: HomeWidget, toPage pageIndex: Int) throws {
        try edit { layout in try layout.addWidget(widget, toPage: pageIndex) }
    }

    func removeWidget(id: String) throws {
        try edit { layout in try layout.removeWidget(id: id) }
    }

    func moveWidget(id: String, by offset: Int) throws {
        try edit { layout in try layout.moveWidget(id: id, by: offset) }
    }

    func updateWidget(id: String, kind: WidgetKind, size: WidgetSize) throws {
        try edit { layout in try layout.updateWidget(id: id, kind: kind, size: size) }
    }

    func makeFolder(containing itemID: String, folderID: String) throws {
        try edit { layout in try layout.makeFolder(containing: itemID, folderID: folderID) }
    }

    @discardableResult
    func addPage(id: String) throws -> Int {
        var index: Int = 0
        try edit { layout in index = try layout.addPage(id: id) }
        return index
    }

    func removePage(at index: Int) throws {
        try edit { layout in try layout.removePage(at: index) }
    }

    func movePage(at index: Int, by offset: Int) throws {
        try edit { layout in try layout.movePage(at: index, by: offset) }
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(layout)
        layout = previous
        onChange?()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(layout)
        layout = next
        onChange?()
    }

    private func edit(_ change: (inout HomeLayout) throws -> Void) throws {
        var updated: HomeLayout = layout
        try change(&updated)
        guard updated != layout else { return }
        undoStack.append(layout)
        if undoStack.count > HomeStore.maximumUndoSteps {
            undoStack.removeFirst(undoStack.count - HomeStore.maximumUndoSteps)
        }
        redoStack.removeAll()
        layout = updated
        onChange?()
    }
}
