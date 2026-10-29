extension LayoutProblem {
    var message: String {
        switch self {
        case .tooManyItems(let count):
            return "項目が多すぎます（\(count) 件。上限は \(LayoutLimits.maximumItems) 件）。"
        case .tooManyPages(let count):
            return "ページが多すぎます（\(count) ページ。上限は \(LayoutLimits.maximumPages) ページ）。"
        case .invalidPageID(let id):
            return "ページの ID が不正です（\(LayoutProblem.shortened(id))）。"
        case .duplicatePageID(let id):
            return "ページの ID が重複しています（\(LayoutProblem.shortened(id))）。"
        case .invalidItemID(let id):
            return "項目の ID が不正です（\(LayoutProblem.shortened(id))）。"
        case .duplicateItemID(let id):
            return "項目の ID が重複しています（\(LayoutProblem.shortened(id))）。"
        case .textTooLong(let itemID):
            return "項目（\(LayoutProblem.shortened(itemID))）の名前・記号名・URL のどれかが長すぎます。"
        }
    }

    /// 説明に入れる ID は先頭だけにする（壊れたファイルの長い文字列をそのまま表示しない）。
    private static func shortened(_ text: String) -> String {
        if text.isEmpty {
            return "空"
        }
        let limit: Int = 24
        return text.count > limit ? String(text.prefix(limit)) + "…" : text
    }
}
