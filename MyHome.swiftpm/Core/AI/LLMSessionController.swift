import Foundation
import Observation

/// AI 画面1つ分のセッション。作っただけでは何も読み込まない（遅延ロード）。
/// モデルは load(using:) を呼んだ時だけ読み込み、画面を離れる時は unload() で生成を止めて解放する。
/// 推論そのものはプロバイダー側のタスクで行い、メインアクターでは受け取った文字の追加だけを行う。
@MainActor
@Observable
final class LLMSessionController {
    enum Phase: Hashable, Sendable {
        case notLoaded
        case loading
        case ready
        case generating
    }

    /// 1回の入力の上限文字数（長すぎる入力でメモリや時間を使いすぎないため）。
    static let maximumPromptLength: Int = 4000
    static let maximumOutputTokens: Int = 512
    static let interruptedSuffix: String = "\n（生成を中断しました）"

    private(set) var phase: Phase = .notLoaded
    private(set) var messages: [LLMMessage] = []
    private(set) var loadedModel: LLMModelDescriptor?
    private(set) var errorMessage: String?

    @ObservationIgnored private var model: (any LoadedLLM)?
    @ObservationIgnored private var generationTask: Task<Void, Never>?
    /// unload() のたびに進める。古い読み込み・生成の結果を捨てるために使う。
    @ObservationIgnored private var sessionToken: Int = 0

    init() {}

    func load(using provider: any LocalLLMProvider) async {
        guard phase == .notLoaded else { return }
        phase = .loading
        errorMessage = nil
        let token: Int = sessionToken
        do {
            let loaded: any LoadedLLM = try await provider.load()
            guard token == sessionToken else {
                // 読み込み中に画面を離れた（unload された）ので、すぐに解放する。
                await loaded.unload()
                return
            }
            model = loaded
            loadedModel = provider.descriptor
            phase = .ready
        } catch {
            guard token == sessionToken else { return }
            phase = .notLoaded
            errorMessage = "モデルを読み込めませんでした: \(error.localizedDescription)"
        }
    }

    func send(_ prompt: String) {
        let text: String = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard phase == .ready, let model, !text.isEmpty else { return }
        let limited: String = String(text.prefix(LLMSessionController.maximumPromptLength))
        let isStub: Bool = loadedModel?.format == .stub
        messages.append(LLMMessage(role: .user, text: limited, isStub: false))
        messages.append(LLMMessage(role: .assistant, text: "", isStub: isStub))
        phase = .generating
        errorMessage = nil
        let request = LLMGenerationRequest(prompt: limited, maxTokens: LLMSessionController.maximumOutputTokens)
        let stream: AsyncThrowingStream<String, Error> = model.generate(request)
        let token: Int = sessionToken
        generationTask = Task { [weak self] () async -> Void in
            var failure: Error? = nil
            do {
                for try await chunk in stream {
                    // セッションが破棄されたら受け取りをやめる（生成側にも取り消しが伝わる）。
                    guard let self else { return }
                    self.appendToLastMessage(chunk)
                }
            } catch {
                failure = error
            }
            self?.finishGeneration(token: token, failure: failure)
        }
    }

    /// 生成を途中で止める。モデルは読み込んだまま。
    func cancelGeneration() {
        generationTask?.cancel()
    }

    /// 生成を止めてモデルを解放する。画面を離れる時に呼ぶ。生成が止まるまで待ってから戻る。
    func unload() async {
        sessionToken += 1
        let running: Task<Void, Never>? = generationTask
        generationTask = nil
        running?.cancel()
        let current: (any LoadedLLM)? = model
        model = nil
        loadedModel = nil
        phase = .notLoaded
        await running?.value
        if let current {
            await current.unload()
        }
    }

    /// 実行中の生成が終わるまで待つ。
    func waitForGeneration() async {
        await generationTask?.value
    }

    private func appendToLastMessage(_ chunk: String) {
        guard !messages.isEmpty else { return }
        messages[messages.count - 1].text += chunk
    }

    private func finishGeneration(token: Int, failure: Error?) {
        guard token == sessionToken else { return }
        generationTask = nil
        phase = .ready
        if let failure, !(failure is CancellationError) {
            errorMessage = "生成に失敗しました: \(failure.localizedDescription)"
        } else if Task.isCancelled || failure is CancellationError {
            appendToLastMessage(LLMSessionController.interruptedSuffix)
        }
    }
}
