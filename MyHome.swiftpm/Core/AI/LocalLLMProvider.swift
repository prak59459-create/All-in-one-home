// ローカル LLM の境界。推論エンジンやモデルへの依存はここに持ち込まない。
// 実推論バックエンド（llama.cpp、Core ML など）は PoC で Swift Playgrounds 上の動作を確認してから、
// このプロトコルに適合する型として追加する（PLAN.md「ローカル LLM の方針」）。

/// モデルファイルの形式。実際に推論できるかはバックエンドごとに PoC で確認する。
enum LLMModelFormat: String, Hashable, Sendable {
    case stub
    case gguf
    case coreML
}

/// モデルの説明。読み込む前に表示できる情報だけを持つ。
struct LLMModelDescriptor: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let format: LLMModelFormat
}

/// 1回の生成の指示。
struct LLMGenerationRequest: Hashable, Sendable {
    var prompt: String
    /// 出力の上限（単位はバックエンドごとのトークンなど）。
    var maxTokens: Int
}

/// 推論バックエンド。プロバイダーを作っただけではモデルを読み込まず、load() を呼んだ時だけメモリに載せる。
protocol LocalLLMProvider: Sendable {
    var descriptor: LLMModelDescriptor { get }
    func load() async throws -> any LoadedLLM
}

/// 読み込み済みのモデル。unload() の後は使わない。
protocol LoadedLLM: Sendable {
    /// 生成結果を少しずつ返す。受け取り側のタスクが取り消されたら生成も止める。
    func generate(_ request: LLMGenerationRequest) -> AsyncThrowingStream<String, Error>
    /// モデルを解放する。
    func unload() async
}
