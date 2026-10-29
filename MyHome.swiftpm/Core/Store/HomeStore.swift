import Observation

/// ホーム画面の配置を持つストア。編集は HomeLayout+Editing の操作を通して行い、失敗した時は配置を変えない。
/// @Observable によりプロパティ単位で変更が追跡され、読んでいる View だけが再描画される。
@MainActor
@Observable
final class HomeStore {
    private(set) var layout: HomeLayout
    /// 配置が変わった時に呼ぶ（保存の予約に使う。PersistenceController.attach が設定する）。
    @ObservationIgnored var onChange: (@MainActor () -> Void)?

    init(layout: HomeLayout = DefaultLayout.make()) {
        self.layout = layout.normalized()
    }

    func add(_ item: HomeItem, toPage pageIndex: Int) throws {
        var updated: HomeLayout = layout
        try updated.append(item, toPage: pageIndex)
        apply(updated)
    }

    func remove(itemID: String) throws {
        var updated: HomeLayout = layout
        try updated.removeItem(id: itemID)
        apply(updated)
    }

    func move(itemID: String, onto targetID: String) throws {
        var updated: HomeLayout = layout
        try updated.moveItem(id: itemID, onto: targetID)
        apply(updated)
    }

    func move(itemID: String, by offset: Int) throws {
        var updated: HomeLayout = layout
        try updated.moveItem(id: itemID, by: offset)
        apply(updated)
    }

    private func apply(_ updated: HomeLayout) {
        guard updated != layout else { return }
        layout = updated
        onChange?()
    }
}
