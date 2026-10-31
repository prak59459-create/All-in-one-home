/// 配置の上限。保存データの検証（LayoutValidator）と編集操作（HomeLayout+Editing）の両方で使う。
enum LayoutLimits {
    /// 項目数の上限（ページと Dock の合計）。この件数まで表示が破綻しないことを検証用レイアウトで確かめる。
    static let maximumItems: Int = 2000
    static let maximumPages: Int = 100
    static let maximumIDLength: Int = 100
    /// 項目名の上限（文字数）。ホーム画面では1行に収まらない分を省略して表示する。
    static let maximumTitleLength: Int = 50
    static let maximumSymbolNameLength: Int = 100
    static let maximumURLLength: Int = URLPolicy.maximumLength
}
