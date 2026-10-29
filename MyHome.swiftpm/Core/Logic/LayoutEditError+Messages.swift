extension LayoutEditError {
    var message: String {
        switch self {
        case .itemNotFound:
            return "項目が見つかりません。すでに削除された可能性があります。"
        case .pageNotFound:
            return "ページが見つかりません。"
        case .duplicateID:
            return "同じ ID の項目がすでにあります。"
        case .itemLimitReached:
            return "項目は \(LayoutLimits.maximumItems) 件までです。不要な項目を削除してから追加してください。"
        case .notRemovable:
            return "この項目は削除できません（設定を開く手段がなくなるため）。"
        case .dockFull:
            return "Dock に置けるのは \(HomeLayout.maximumDockItems) 個までです。先に Dock から項目を移してください。"
        case .folderInFolder:
            return "フォルダの中にフォルダは入れられません。"
        case .titleTooLong:
            return "名前は \(LayoutLimits.maximumTitleLength) 文字までです。"
        case .pageLimitReached:
            return "ページは \(LayoutLimits.maximumPages) ページまでです。"
        case .lastPage:
            return "最後の1ページは削除できません。"
        case .pageNotEmpty:
            return "項目やウィジェットが残っているページは削除できません。先に別のページへ移すか、削除してください。"
        case .widgetLimitReached:
            return "1ページに置けるウィジェットは \(WidgetLimits.maximumPerPage) 個までです。"
        }
    }
}
