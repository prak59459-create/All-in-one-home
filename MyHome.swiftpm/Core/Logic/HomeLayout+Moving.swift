/// 移動先（末尾に置く）。
enum ItemDestination: Hashable, Sendable {
    case page(Int)
    case dock
    case folder(String)
}

/// 項目の移動（F0059、F0061、F0100、F0126、F0127、F0146、F0147）。
extension HomeLayout {
    /// 項目を target の所へ移す。target がフォルダなら中に入れる（F0146）。
    /// それ以外は target の位置に入れ、target は後ろへずれる（前から後ろへ動かした時は target の後ろに入る）。
    /// ページ・Dock・フォルダをまたいで動かせる。
    mutating func moveItem(id: String, onto targetID: String) throws {
        guard let source = location(ofItem: id), let target = location(ofItem: targetID) else {
            throw LayoutEditError.itemNotFound
        }
        guard id != targetID else { return }
        if let targetItem = item(id: targetID), targetItem.isFolder, !(item(id: id)?.isFolder ?? false) {
            try moveItem(id: id, to: .folder(targetID))
            return
        }
        if source.container == target.container {
            reorder(in: source.container, from: source.index, to: target.index)
            return
        }
        let moving: HomeItem = items(in: source.container)[source.index]
        try checkCanPlace(moving, in: target.container)
        var updated: HomeLayout = self
        updated.removeFromContainer(at: source)
        // 取り出した後の配置で target の位置を探し直す（取り出す前の番号を使い回さない）
        guard let newTarget = updated.location(ofItem: targetID) else { throw LayoutEditError.itemNotFound }
        var list: [HomeItem] = updated.items(in: newTarget.container)
        list.insert(moving, at: newTarget.index)
        updated.setItems(list, in: newTarget.container)
        self = updated.normalized()
    }

    /// 項目を移動先の末尾へ移す（ドラッグを使わない移動。ページの点・Dock への落とし込みにも使う）。
    mutating func moveItem(id: String, to destination: ItemDestination) throws {
        guard let source = location(ofItem: id) else { throw LayoutEditError.itemNotFound }
        let container: ItemContainer = try resolve(destination)
        guard source.container != container else { return }
        let moving: HomeItem = items(in: source.container)[source.index]
        try checkCanPlace(moving, in: container)
        var updated: HomeLayout = self
        updated.removeFromContainer(at: source)
        guard let resolved = try? updated.resolve(destination) else { throw LayoutEditError.itemNotFound }
        var list: [HomeItem] = updated.items(in: resolved)
        list.append(moving)
        updated.setItems(list, in: resolved)
        self = updated.normalized()
    }

    /// 項目を同じ場所の中で offset だけ前後に動かす。端を越える分は端で止める（VoiceOver の操作用）。
    mutating func moveItem(id: String, by offset: Int) throws {
        guard let source = location(ofItem: id) else { throw LayoutEditError.itemNotFound }
        let count: Int = items(in: source.container).count
        let destination: Int = min(max(source.index + offset, 0), count - 1)
        reorder(in: source.container, from: source.index, to: destination)
    }

    private mutating func reorder(in container: ItemContainer, from index: Int, to destination: Int) {
        guard index != destination else { return }
        var list: [HomeItem] = items(in: container)
        let moving: HomeItem = list.remove(at: index)
        list.insert(moving, at: destination)
        setItems(list, in: container)
    }

    private mutating func removeFromContainer(at location: ItemLocation) {
        var list: [HomeItem] = items(in: location.container)
        list.remove(at: location.index)
        setItems(list, in: location.container)
    }

    private func resolve(_ destination: ItemDestination) throws -> ItemContainer {
        switch destination {
        case .page(let index):
            guard pages.indices.contains(index) else { throw LayoutEditError.pageNotFound }
            return .page(index)
        case .dock:
            return .dock
        case .folder(let folderID):
            guard item(id: folderID)?.isFolder ?? false else { throw LayoutEditError.itemNotFound }
            return .folder(folderID)
        }
    }

    /// その場所に置けるか（Dock の上限、フォルダの中にフォルダを入れない）。
    private func checkCanPlace(_ item: HomeItem, in container: ItemContainer) throws {
        switch container {
        case .dock:
            guard dock.count < HomeLayout.maximumDockItems else { throw LayoutEditError.dockFull }
        case .folder:
            guard !item.isFolder else { throw LayoutEditError.folderInFolder }
        case .page:
            break
        }
    }
}
