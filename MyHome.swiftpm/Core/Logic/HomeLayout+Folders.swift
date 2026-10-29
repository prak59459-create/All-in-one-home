/// フォルダの作成（F0121）。解除は removeItem（HomeLayout+Editing）、出し入れは moveItem（HomeLayout+Moving）。
extension HomeLayout {
    static let defaultFolderTitle: String = "フォルダ"
    static let folderSymbolName: String = "folder.fill"
    static let folderTint: RGBAColor = RGBAColor(hex: 0x475569)

    /// 項目をその場所で新しいフォルダに入れる。フォルダや、フォルダの中の項目には使えない（階層は1段）。
    mutating func makeFolder(containing itemID: String, folderID: String, title: String = HomeLayout.defaultFolderTitle) throws {
        guard let location = topLevelLocation(ofItem: itemID) else {
            // フォルダの中の項目なら、フォルダの中にフォルダを作ることになる
            throw self.location(ofItem: itemID) == nil ? LayoutEditError.itemNotFound : LayoutEditError.folderInFolder
        }
        guard self.location(ofItem: folderID) == nil else { throw LayoutEditError.duplicateID }
        guard itemCount < LayoutLimits.maximumItems else { throw LayoutEditError.itemLimitReached }
        guard title.count <= LayoutLimits.maximumTitleLength else { throw LayoutEditError.titleTooLong }
        var list: [HomeItem] = items(in: location.container)
        let item: HomeItem = list[location.index]
        guard !item.isFolder else { throw LayoutEditError.folderInFolder }
        let folder = HomeItem(
            id: folderID,
            title: title,
            symbolName: HomeLayout.folderSymbolName,
            tint: HomeLayout.folderTint,
            action: .folder([item])
        )
        list[location.index] = folder
        setItems(list, in: location.container)
    }
}
