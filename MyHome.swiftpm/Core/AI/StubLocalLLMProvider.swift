/// 推論を行わないスタブ。モデル未導入でも AI 画面の流れ（読み込み・生成・取り消し・解放）を確かめるために使う。
/// 応答は必ず「[スタブ応答]」で始め、本物の AI の回答と誤認させない。
struct StubLocalLLMProvider: LocalLLMProvider {
    let descriptor = LLMModelDescriptor(id: "stub", displayName: "スタブ（推論なし）", format: .stub)
    /// 少しずつ表示される様子を確かめるための待ち時間。テストでは .zero にする。
    var chunkDelay: Duration = .milliseconds(30)

    func load() async throws -> any LoadedLLM {
        StubLoadedLLM(chunkDelay: chunkDelay)
    }
}

struct StubLoadedLLM: LoadedLLM {
    static let replyPrefix: String = "[スタブ応答] "
    static let charactersPerChunk: Int = 4

    let chunkDelay: Duration

    func generate(_ request: LLMGenerationRequest) -> AsyncThrowingStream<String, Error> {
        let chunks: [String] = StubLoadedLLM.replyChunks(for: request)
        let delay: Duration = chunkDelay
        return AsyncThrowingStream { continuation in
            let producer = Task {
                do {
                    for chunk in chunks {
                        try Task.checkCancellation()
                        if delay > .zero {
                            try await Task.sleep(for: delay)
                        }
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                producer.cancel()
            }
        }
    }

    func unload() async {}

    static func replyText(for request: LLMGenerationRequest) -> String {
        let count: Int = request.prompt.count
        return replyPrefix + "これは実際の AI の回答ではありません。モデルが導入されていないため推論は行わず、入力された \(count) 文字を受け取ったことだけを返しています。"
    }

    /// 応答を数文字ずつに分ける。maxTokens は分けた個数の上限として扱う。
    static func replyChunks(for request: LLMGenerationRequest) -> [String] {
        var chunks: [String] = []
        var current: String = ""
        for character in replyText(for: request) {
            current.append(character)
            if current.count == charactersPerChunk {
                chunks.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            chunks.append(current)
        }
        return Array(chunks.prefix(max(request.maxTokens, 1)))
    }
}
