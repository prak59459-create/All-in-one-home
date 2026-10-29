/// 配置の編集に失敗した理由。失敗した時は配置を変えない。
enum LayoutEditError: Error, Hashable, Sendable {
    case itemNotFound
    case pageNotFound
    case duplicateID
    case itemLimitReached
    /// 設定のように、消すと戻れなくなる項目。
    case notRemovable
    /// 移動先が別のページや Dock（ページをまたぐ移動は Phase 3）。
    case differentContainer
}

/// 項目が置かれている場所。
enum ItemContainer: Hashable, Sendable {
    case page(Int)
    case dock
}

struct ItemLocation: Hashable, Sendable {
    let container: ItemContainer
    let index: Int
}

extension HomeItem {
    /// 削除できるか。設定はホーム画面から消すと開く手段がなくなるため削除できない。
    var isRemovable: Bool {
        action != .feature(.settings)
    }
}

/// 配置の編集操作（F0041、F0042、F0059）。
extension HomeLayout {
    func location(ofItem id: String) -> ItemLocation? {
        if let index = dock.firstIndex(where: { item in item.id == id }) {
            return ItemLocation(container: .dock, index: index)
        }
        for (pageIndex, page) in pages.enumerated() {
            if let index = page.items.firstIndex(where: { item in item.id == id }) {
                return ItemLocation(container: .page(pageIndex), index: index)
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

    @discardableResult
    mutating func removeItem(id: String) throws -> HomeItem {
        guard let location = location(ofItem: id) else { throw LayoutEditError.itemNotFound }
        var list: [HomeItem] = items(in: location.container)
        guard list[location.index].isRemovable else { throw LayoutEditError.notRemovable }
        let removed: HomeItem = list.remove(at: location.index)
        setItems(list, in: location.container)
        return removed
    }

    /// 項目を、同じページ（または Dock）の中の target の位置へ移す。target は後ろへずれる
    /// （前から後ろへ動かした時は target の後ろに入る。ホーム画面でアイコンを重ねた時と同じ動き）。
    mutating func moveItem(id: String, onto targetID: String) throws {
        guard let source = location(ofItem: id), let target = location(ofItem: targetID) else {
            throw LayoutEditError.itemNotFound
        }
        guard source.container == target.container else { throw LayoutEditError.differentContainer }
        guard source.index != target.index else { return }
        var list: [HomeItem] = items(in: source.container)
        let moving: HomeItem = list.remove(at: source.index)
        list.insert(moving, at: target.index)
        setItems(list, in: source.container)
    }

    /// 項目を同じページ（または Dock）の中で offset だけ前後に動かす。端を越える分は端で止める。
    /// VoiceOver の操作など、ドラッグを使わない並べ替えに使う。
    mutating func moveItem(id: String, by offset: Int) throws {
        guard let source = location(ofItem: id) else { throw LayoutEditError.itemNotFound }
        var list: [HomeItem] = items(in: source.container)
        let destination: Int = min(max(source.index + offset, 0), list.count - 1)
        guard destination != source.index else { return }
        let moving: HomeItem = list.remove(at: source.index)
        list.insert(moving, at: destination)
        setItems(list, in: source.container)
    }

    func items(in container: ItemContainer) -> [HomeItem] {
        switch container {
        case .dock:
            return dock
        case .page(let index):
            return pages[index].items
        }
    }

    private mutating func setItems(_ items: [HomeItem], in container: ItemContainer) {
        switch container {
        case .dock:
            dock = items
        case .page(let index):
            pages[index].items = items
        }
    }
}
