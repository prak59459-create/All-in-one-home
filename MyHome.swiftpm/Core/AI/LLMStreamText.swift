/// 生成中の文章の受け渡し。Foundation Models などは「それまでの全文」を何度も返すので、増えた分だけにして
/// LLMSessionController（受け取った分を後ろに足していく）に渡す。
enum LLMStreamText {
    /// previous の続きなら増えた分。続きでない（途中が書き換わった）時は、区切りの改行を入れて全文を返す。
    static func delta(from previous: String, to current: String) -> String {
        if current.hasPrefix(previous) {
            return String(current.dropFirst(previous.count))
        }
        return "\n" + current
    }
}

/// AI に渡す指示（システムプロンプト）。できないことを正直に答えるよう伝える（F0370、F0397）。
enum AIInstructions {
    static let text: String = """
    あなたは iPad のアプリ「MyHome」の中で動くアシスタントです。利用者が日本語で書いたら日本語で、簡潔に答えてください。
    あなたは iPad やアプリを操作できず、インターネットの検索もできません。端末の中のモデルで答えています。
    分からないことや確かでないことは、そう伝えてください。
    """
}
