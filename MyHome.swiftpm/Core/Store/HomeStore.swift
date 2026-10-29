import Observation

/// ホーム画面の配置を持つストア。Phase 1 は表示のみ（編集と保存は Phase 2）。
/// @Observable によりプロパティ単位で変更が追跡され、読んでいる View だけが再描画される。
@MainActor
@Observable
final class HomeStore {
    private(set) var layout: HomeLayout

    init(layout: HomeLayout = DefaultLayout.make()) {
        self.layout = layout.normalized()
    }
}
