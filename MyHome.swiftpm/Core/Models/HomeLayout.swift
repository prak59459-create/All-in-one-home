/// ホーム画面の1ページ。
struct HomePage: Identifiable, Hashable, Codable, Sendable {
    let id: String
    var items: [HomeItem]
}

/// ホーム画面全体の配置（ページと Dock）。
struct HomeLayout: Hashable, Codable, Sendable {
    var pages: [HomePage]
    var dock: [HomeItem]

    /// Dock に置ける最大数。
    static let maximumDockItems: Int = 6

    /// すべての項目数（ページと Dock の合計）。
    var itemCount: Int {
        let pageItems: Int = pages.reduce(0) { total, page in total + page.items.count }
        return pageItems + dock.count
    }

    /// 表示できる状態に整える。ページが1枚もなければ空のページを1枚作る。
    /// Dock の上限を超えた分は消さずに最後のページの末尾へ移す。
    func normalized() -> HomeLayout {
        var result: HomeLayout = self
        if result.pages.isEmpty {
            result.pages = [HomePage(id: "page.empty", items: [])]
        }
        let limit: Int = HomeLayout.maximumDockItems
        if result.dock.count > limit {
            let overflow: [HomeItem] = Array(result.dock[limit...])
            result.dock.removeLast(result.dock.count - limit)
            result.pages[result.pages.count - 1].items.append(contentsOf: overflow)
        }
        return result
    }
}
