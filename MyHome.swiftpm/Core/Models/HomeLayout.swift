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

    /// すべての項目数（ページと Dock の合計。フォルダの中の項目も1件ずつ数え、フォルダ自体も1件と数える）。
    var itemCount: Int {
        let pageItems: Int = pages.reduce(0) { (total: Int, page: HomePage) -> Int in
            total + HomeLayout.count(page.items)
        }
        return pageItems + HomeLayout.count(dock)
    }

    private static func count(_ items: [HomeItem]) -> Int {
        items.reduce(0) { (total: Int, item: HomeItem) -> Int in
            total + 1 + (item.folderItems?.count ?? 0)
        }
    }

    /// 表示できる状態に整える。空のフォルダは取り除く（F0143）。ページが1枚もなければ空のページを1枚作る。
    /// Dock の上限を超えた分は消さずに最後のページの末尾へ移す。
    func normalized() -> HomeLayout {
        var result: HomeLayout = self
        result.removeEmptyFolders()
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

    mutating func removeEmptyFolders() {
        let isEmptyFolder: (HomeItem) -> Bool = { (item: HomeItem) -> Bool in
            item.folderItems?.isEmpty ?? false
        }
        dock.removeAll(where: isEmptyFolder)
        for index in pages.indices {
            pages[index].items.removeAll(where: isEmptyFolder)
        }
    }
}
