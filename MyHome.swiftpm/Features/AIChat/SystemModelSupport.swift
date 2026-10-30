import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple の端末内モデル（Foundation Models）が使えるかの判定（F0381、F0422）。
/// FoundationModels は iOS 26 SDK にしかないので、古い SDK（Xcode 16.4、iOS 18 SDK の Swift Playgrounds）では
/// この部分を丸ごとビルドから外し、「この版では使えない」と表示する。判定はモデルを読み込まないので軽い。
enum SystemModelSupport {
    static func availability() -> LLMAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return availabilityOnSupportedOS()
        }
        return .unavailable("iPadOS 26 以降が必要です。")
        #else
        return .unavailable("この Swift Playgrounds（または Xcode）の版には端末内モデルの機能が含まれていません（iOS 26 SDK が必要）。")
        #endif
    }

    /// 端末内モデルのプロバイダー。使えない環境では nil。
    static func makeProvider() -> (any LocalLLMProvider)? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return FoundationModelsProvider()
        }
        #endif
        return nil
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func availabilityOnSupportedOS() -> LLMAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            return .unavailable(message(for: reason))
        @unknown default:
            return .unavailable("今は使えません。")
        }
    }

    @available(iOS 26.0, *)
    private static func message(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "この iPad は Apple Intelligence に対応していないため使えません。"
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence がオフになっています。「設定」→「Apple Intelligence と Siri」でオンにしてください。"
        case .modelNotReady:
            return "モデルを準備中です（ダウンロード中など）。しばらく待ってから、この画面を開き直してください。"
        @unknown default:
            return "今は使えません。"
        }
    }
    #endif
}

#if canImport(FoundationModels)
/// Apple の端末内モデル（F0374）。読み込みはセッションを作るだけで、モデル自体は OS が管理する。
/// 会話の文脈はセッションが覚えているので、続けて質問できる（「新しい会話」でセッションを作り直す）。
@available(iOS 26.0, *)
struct FoundationModelsProvider: LocalLLMProvider {
    let descriptor = LLMModelDescriptor(id: "apple.system", displayName: "Apple の端末内モデル", format: .systemModel)

    func load() async throws -> any LoadedLLM {
        if case .unavailable(let reason) = SystemModelSupport.availability() {
            throw LLMError(message: reason)
        }
        // 指示はビルダーの形で渡す（SDK の版によって String を直接受け取る形があるか分からないため）
        let instructions: String = AIInstructions.text
        let session = LanguageModelSession {
            instructions
        }
        return FoundationModelsLoadedLLM(session: session)
    }
}

@available(iOS 26.0, *)
struct FoundationModelsLoadedLLM: LoadedLLM {
    let session: LanguageModelSession

    func generate(_ request: LLMGenerationRequest) -> AsyncThrowingStream<String, Error> {
        let session: LanguageModelSession = self.session
        return AsyncThrowingStream { continuation in
            let producer = Task {
                do {
                    let options = GenerationOptions(maximumResponseTokens: request.maxTokens)
                    let prompt: String = request.prompt
                    // 返るのは「それまでの全文」。増えた分だけにして渡す
                    let stream = session.streamResponse(options: options) {
                        prompt
                    }
                    var previous: String = ""
                    for try await snapshot in stream {
                        try Task.checkCancellation()
                        let current: String = snapshot.content
                        continuation.yield(LLMStreamText.delta(from: previous, to: current))
                        previous = current
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(throwing: FoundationModelsLoadedLLM.describe(error))
                }
            }
            continuation.onTermination = { _ in
                producer.cancel()
            }
        }
    }

    /// セッションを手放すだけ（モデルのメモリは OS が管理する）。
    func unload() async {}

    /// よくある失敗を、利用者向けの説明にする（F0421、F0434）。
    static func describe(_ error: Error) -> LLMError {
        guard let failure = error as? LanguageModelSession.GenerationError else {
            return LLMError(message: "生成に失敗しました: \(error.localizedDescription)")
        }
        switch failure {
        case .exceededContextWindowSize:
            return LLMError(message: "会話が長くなりすぎました。「新しい会話」を押して、最初からやり直してください。")
        case .guardrailViolation:
            return LLMError(message: "安全のための制限により、この内容には答えられません。")
        case .unsupportedLanguageOrLocale:
            return LLMError(message: "この言語には対応していません。")
        case .assetsUnavailable:
            return LLMError(message: "モデルのデータが使えない状態です。しばらく待ってからお試しください。")
        case .rateLimited:
            return LLMError(message: "短い時間に何度も使ったため、少し待ってからお試しください。")
        default:
            return LLMError(message: "生成に失敗しました: \(failure.localizedDescription)")
        }
    }
}
#endif
