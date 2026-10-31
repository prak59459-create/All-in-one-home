/// ホーム画面の形の切り替え（設定と初期設定から。追加フェーズ A）。
@MainActor
enum HomeStyleSwitcher {
    /// 形を変える。ウィジェット型にした時、アプリのウィジェットが 1 つもなければ、おすすめを最初のページに足す
    /// （アイコン型で使っていた配置のままだと、アプリを開くウィジェットがないため）。足したウィジェットの数を返す。
    @discardableResult
    static func apply(_ style: HomeStyle, settings: SettingsStore, home: HomeStore) -> Int {
        settings.homeStyle = style
        guard style == .widgets, !home.layout.hasAppWidgets, !home.layout.pages.isEmpty else { return 0 }
        return (try? home.addRecommendedWidgets(toPage: 0)) ?? 0
    }
}
