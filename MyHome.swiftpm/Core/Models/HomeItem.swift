/// ホーム画面・Dock に置く1項目。
struct HomeItem: Identifiable, Hashable, Sendable {
    let id: String
    var title: String
    /// SF Symbols の名前。
    var symbolName: String
    var tint: RGBAColor
    var action: HomeItemAction
}

/// 項目をタップした時の動作。
enum HomeItemAction: Hashable, Sendable {
    /// Web ページ、または URL スキームに対応した他アプリを開く。開く前に必ず確認する。
    case openURL(String)
    /// アプリ内の機能を開く。
    case feature(AppFeature)
}
