/// テキストツール（Apps/texttools.json）。書きかけの文章を保存し、開き直しても続きから使える。
struct TextToolsState: MiniAppContent {
    static let fileID: String = "texttools"
    static let formatVersion: Int = 1
    static let maximumByteCount: Int = 2_000_000
    static let initial: TextToolsState = TextToolsState(text: "")
    static let maximumLength: Int = 100_000

    var text: String

    var problems: [String] {
        text.count > TextToolsState.maximumLength ? ["文章が長すぎます。"] : []
    }

    /// 長すぎる分は切り詰める。切り詰めたら true。
    @discardableResult
    mutating func setText(_ newText: String) -> Bool {
        // バイト数が上限以下なら文字数も上限以下（入力のたびに全体を数えないようにする）
        if newText.utf8.count <= TextToolsState.maximumLength {
            text = newText
            return false
        }
        let limited: String = String(newText.prefix(TextToolsState.maximumLength))
        text = limited
        return limited.count < newText.count
    }
}
