/// ホーム画面・Dock に置く1項目。
struct HomeItem: Identifiable, Hashable, Codable, Sendable {
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
    /// フォルダ（F0121）。中にフォルダは入れない（階層は1段。F0156、F0157。HomeLayout+Folders で守る）。
    case folder([HomeItem])
}

extension HomeItem {
    /// フォルダの中身。フォルダでなければ nil。
    var folderItems: [HomeItem]? {
        if case .folder(let items) = action {
            return items
        }
        return nil
    }

    var isFolder: Bool {
        folderItems != nil
    }
}
