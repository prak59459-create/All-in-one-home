/// アプリの一覧（ウィジェット型のホーム画面の「アプリ」。追加フェーズ A）に並べるもの。
/// ウィジェット型ではアイコンと Dock を出さないので、機能とリンクはここから開く。
extension HomeLayout {
    /// 開ける機能（アプリ）。並びは AppFeature の順。
    static var libraryFeatures: [AppFeature] {
        AppFeature.allCases.filter { (feature: AppFeature) -> Bool in feature.state.canOpen }
    }

    /// ホーム画面にあるリンク（ページ・フォルダの中・Dock の順）。同じ URL は最初の 1 つだけ。
    var libraryLinks: [HomeItem] {
        var seen: Set<String> = []
        var result: [HomeItem] = []
        var pending: [HomeItem] = pages.flatMap { (page: HomePage) -> [HomeItem] in page.items } + dock
        while !pending.isEmpty {
            let item: HomeItem = pending.removeFirst()
            switch item.action {
            case .openURL(let address):
                if seen.insert(address).inserted {
                    result.append(item)
                }
            case .folder(let children):
                // フォルダの中身は、フォルダのあった位置に並べる
                pending.insert(contentsOf: children, at: 0)
            case .feature:
                break
            }
        }
        return result
    }
}
