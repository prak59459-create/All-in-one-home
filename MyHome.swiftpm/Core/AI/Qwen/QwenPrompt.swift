/// Qwen2.5 の会話の形（ChatML）を ID の列にする。Hugging Face の chat template と同じ:
/// <|im_start|>system\n{指示}<|im_end|>\n<|im_start|>user\n{文}<|im_end|>\n … <|im_start|>assistant\n
/// 特別なトークンは ID で直接入れ、利用者の文からは作らない（文に <|im_end|> と書かれていても、会話の区切りにはならない）。
enum QwenPrompt {
    /// 端末内で動く小さなモデルへの指示（日本語で、短く答える。できないことは、できないと言う）。
    static let defaultSystem: String = "あなたは MyHome の中で動く、端末内の小さなアシスタントです。日本語で、短く分かりやすく答えてください。分からないことは分からないと言い、端末の操作やインターネットの検索はできないことを伝えてください。"

    static func tokens(system: String, messages: [LLMMessage], tokenizer: QwenTokenizer) -> [Int] {
        var ids: [Int] = turn(role: "system", text: system, tokenizer: tokenizer)
        for message in messages {
            ids.append(contentsOf: turn(role: role(of: message), text: message.text, tokenizer: tokenizer))
        }
        ids.append(contentsOf: answerStart(tokenizer: tokenizer))
        return ids
    }

    /// limit 個に収める。指示と、新しい会話から順に入るだけ残す（古い会話から落とす）。
    /// 最後の 1 つも入らない時は、その文の後ろの方を残す。
    static func tokens(system: String, messages: [LLMMessage], tokenizer: QwenTokenizer, limit: Int) -> [Int] {
        let head: [Int] = turn(role: "system", text: system, tokenizer: tokenizer)
        let tail: [Int] = answerStart(tokenizer: tokenizer)
        var budget: Int = limit - head.count - tail.count
        var kept: [[Int]] = []
        for message in messages.reversed() {
            let ids: [Int] = turn(role: role(of: message), text: message.text, tokenizer: tokenizer)
            if ids.count <= budget {
                kept.insert(ids, at: 0)
                budget -= ids.count
            } else {
                if kept.isEmpty, budget > 4 {
                    kept.insert(trimmedTurn(ids, to: budget), at: 0)
                }
                break
            }
        }
        return head + kept.flatMap { (ids: [Int]) -> [Int] in ids } + tail
    }

    private static func role(of message: LLMMessage) -> String {
        switch message.role {
        case .user: return "user"
        case .assistant: return "assistant"
        }
    }

    private static func turn(role: String, text: String, tokenizer: QwenTokenizer) -> [Int] {
        [QwenTokenizer.imStart] + tokenizer.encode(role + "\n" + text) + [QwenTokenizer.imEnd] + tokenizer.encode("\n")
    }

    private static func answerStart(tokenizer: QwenTokenizer) -> [Int] {
        [QwenTokenizer.imStart] + tokenizer.encode("assistant\n")
    }

    /// <|im_start|>role\n … <|im_end|>\n の形を保ったまま、本文の前の方を落として count 個にする。
    private static func trimmedTurn(_ ids: [Int], to count: Int) -> [Int] {
        guard ids.count > count, count > 4 else { return ids }
        let opening: [Int] = Array(ids.prefix(3))
        let closing: [Int] = Array(ids.suffix(2))
        let body: [Int] = Array(ids.dropFirst(3).dropLast(2))
        return opening + Array(body.suffix(count - 5)) + closing
    }
}
