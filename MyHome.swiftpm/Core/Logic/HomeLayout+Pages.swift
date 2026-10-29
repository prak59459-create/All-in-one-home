/// ページの追加・削除・並べ替え（F0011、F0012、F0015）。
extension HomeLayout {
    /// 末尾に空のページを追加し、その番号を返す。
    @discardableResult
    mutating func addPage(id: String) throws -> Int {
        guard pages.count < LayoutLimits.maximumPages else { throw LayoutEditError.pageLimitReached }
        guard !pages.contains(where: { (page: HomePage) -> Bool in page.id == id }) else { throw LayoutEditError.duplicateID }
        pages.append(HomePage(id: id, items: []))
        return pages.count - 1
    }

    /// 空のページ（項目もウィジェットもない）だけを削除できる（失わないため）。最後の1ページは残す。
    mutating func removePage(at index: Int) throws {
        guard pages.indices.contains(index) else { throw LayoutEditError.pageNotFound }
        guard pages.count > 1 else { throw LayoutEditError.lastPage }
        guard pages[index].items.isEmpty, pages[index].widgets.isEmpty else { throw LayoutEditError.pageNotEmpty }
        pages.remove(at: index)
    }

    /// ページを offset だけ前後に動かす。端を越える分は端で止める。
    mutating func movePage(at index: Int, by offset: Int) throws {
        guard pages.indices.contains(index) else { throw LayoutEditError.pageNotFound }
        let destination: Int = min(max(index + offset, 0), pages.count - 1)
        guard destination != index else { return }
        let page: HomePage = pages.remove(at: index)
        pages.insert(page, at: destination)
    }
}
