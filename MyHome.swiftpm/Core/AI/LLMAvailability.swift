/// 推論バックエンドが今使えるか。使えない時は、利用者が読める理由を持つ（F0381、F0422）。
enum LLMAvailability: Hashable, Sendable {
    case available
    case unavailable(String)

    var isAvailable: Bool {
        self == .available
    }

    var reason: String? {
        if case .unavailable(let text) = self {
            return text
        }
        return nil
    }
}

/// 起動時に一度だけ調べた、端末の AI の状態。ホーム画面の AI の項目に「スタブ」の印を付けるかどうかに使う。
/// 端末内モデルの判定は UI 層（FoundationModels を import できる側）で行い、起動直後に設定する。
/// 起動後に Apple Intelligence をオンにした時などは、AI 画面を開いた時に調べ直すので、印だけが次の起動まで古いままになる。
enum LLMRuntime {
    nonisolated(unsafe) static var isSystemModelAvailable: Bool = false
}

/// AI の生成で起きたエラー（利用者向けの説明を持つ）。
struct LLMError: Error, Hashable, Sendable {
    let message: String
}

extension LLMError: CustomStringConvertible {
    var description: String {
        message
    }
}
