/// 配置の編集に失敗した理由。失敗した時は配置を変えない。
enum LayoutEditError: Error, Hashable, Sendable {
    case itemNotFound
    case pageNotFound
    case duplicateID
    case itemLimitReached
    /// 設定のように、消すと戻れなくなる項目。
    case notRemovable
    /// Dock がいっぱい（HomeLayout.maximumDockItems）。
    case dockFull
    /// フォルダの中にフォルダは入れない（F0156、F0157）。
    case folderInFolder
    case titleTooLong
    case pageLimitReached
    /// 最後の1ページは削除できない。
    case lastPage
    /// 項目やウィジェットが残っているページは削除できない（失わないため）。
    case pageNotEmpty
    /// 1ページに置けるウィジェットの数を超える（WidgetLimits.maximumPerPage）。
    case widgetLimitReached
}

/// 項目が置かれている場所。
enum ItemContainer: Hashable, Sendable {
    case page(Int)
    case dock
    /// フォルダの中（フォルダの項目 ID）。
    case folder(String)
}

struct ItemLocation: Hashable, Sendable {
    let container: ItemContainer
    let index: Int
}

extension HomeItem {
    /// 削除できるか。設定はホーム画面から消すと開く手段がなくなるため削除できない。
    /// フォルダの「削除」は解除（中の項目をその場所に戻す）なので、中に設定があっても削除できる。
    var isRemovable: Bool {
        action != .feature(.settings)
    }
}

/// 配置の編集操作（F0041、F0042、F0044）。移動は HomeLayout+Moving、フォルダは HomeLayout+Folders、ページは HomeLayout+Pages。
extension HomeLayout {
    func location(ofItem id: String) -> ItemLocation? {
        if let top = topLevelLocation(ofItem: id) {
            return top
        }
        for folder in allFolders() {
            let items: [HomeItem] = folder.folderItems ?? []
            if let index = items.firstIndex(where: { (item: HomeItem) -> Bool in item.id == id }) {
                return ItemLocation(container: .folder(folder.id), index: index)
            }
        }
        return nil
    }

    func item(id: String) -> HomeItem? {
        guard let location = location(ofItem: id) else { return nil }
        return items(in: location.container)[location.index]
    }

    /// ページの末尾に項目を追加する。
    mutating func append(_ item: HomeItem, toPage pageIndex: Int) throws {
        guard pages.indices.contains(pageIndex) else { throw LayoutEditError.pageNotFound }
        guard location(ofItem: item.id) == nil else { throw LayoutEditError.duplicateID }
        guard itemCount < LayoutLimits.maximumItems else { throw LayoutEditError.itemLimitReached }
        pages[pageIndex].items.append(item)
    }

    /// 項目を削除する。フォルダの場合は解除して、中の項目をフォルダのあった場所に戻す（F0122）。
    @discardableResult
    mutating func removeItem(id: String) throws -> HomeItem {
        guard let location = location(ofItem: id) else { throw LayoutEditError.itemNotFound }
        var list: [HomeItem] = items(in: location.container)
        let removed: HomeItem = list[location.index]
        guard removed.isRemovable else { throw LayoutEditError.notRemovable }
        list.remove(at: location.index)
        if let children = removed.folderItems {
            list.insert(contentsOf: children, at: location.index)
        }
        setItems(list, in: location.container)
        self = normalized()
        return removed
    }

    /// 名前・記号・色・画像を変える（F0044、F0046、F0047、F0050）。動作（リンク先など）は変えない。
    mutating func updateItem(id: String, title: String, symbolName: String, tint: RGBAColor, imageName: String?) throws {
        guard title.count <= LayoutLimits.maximumTitleLength else { throw LayoutEditError.titleTooLong }
        guard let location = location(ofItem: id) else { throw LayoutEditError.itemNotFound }
        var list: [HomeItem] = items(in: location.container)
        list[location.index].title = title
        list[location.index].symbolName = symbolName
        list[location.index].tint = tint
        list[location.index].imageName = imageName
        setItems(list, in: location.container)
    }

    func items(in container: ItemContainer) -> [HomeItem] {
        switch container {
        case .dock:
            return dock
        case .page(let index):
            return pages[index].items
        case .folder(let folderID):
            return item(id: folderID)?.folderItems ?? []
        }
    }

    mutating func setItems(_ items: [HomeItem], in container: ItemContainer) {
        switch container {
        case .dock:
            dock = items
        case .page(let index):
            pages[index].items = items
        case .folder(let folderID):
            guard let folder = topLevelLocation(ofItem: folderID) else { return }
            var list: [HomeItem] = self.items(in: folder.container)
            list[folder.index].action = .folder(items)
            setItems(list, in: folder.container)
        }
    }

    /// ページか Dock に直接置かれている項目の場所（フォルダの中は探さない）。
    func topLevelLocation(ofItem id: String) -> ItemLocation? {
        if let index = dock.firstIndex(where: { (item: HomeItem) -> Bool in item.id == id }) {
            return ItemLocation(container: .dock, index: index)
        }
        for (pageIndex, page) in pages.enumerated() {
            if let index = page.items.firstIndex(where: { (item: HomeItem) -> Bool in item.id == id }) {
                return ItemLocation(container: .page(pageIndex), index: index)
            }
        }
        return nil
    }

    /// ページと Dock にあるフォルダ（フォルダの中にフォルダはない）。
    func allFolders() -> [HomeItem] {
        let topLevel: [HomeItem] = pages.flatMap { (page: HomePage) -> [HomeItem] in page.items } + dock
        return topLevel.filter { (item: HomeItem) -> Bool in item.isFolder }
    }
}
