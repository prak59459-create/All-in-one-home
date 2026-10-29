extension LayoutEditError {
    var message: String {
        switch self {
        case .itemNotFound:
            return "項目が見つかりません。すでに削除された可能性があります。"
        case .pageNotFound:
            return "追加先のページが見つかりません。"
        case .duplicateID:
            return "同じ ID の項目がすでにあります。"
        case .itemLimitReached:
            return "項目は \(LayoutLimits.maximumItems) 件までです。不要な項目を削除してから追加してください。"
        case .notRemovable:
            return "この項目は削除できません（設定を開く手段がなくなるため）。"
        case .differentContainer:
            return "別のページや Dock への移動はまだできません（Phase 3 で対応します）。"
        }
    }
}
