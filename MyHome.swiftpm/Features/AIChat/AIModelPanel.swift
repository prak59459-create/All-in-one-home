import SwiftUI

/// モデルの選択と状態（F0374、F0378–F0381、F0397）。読み込み・解放・新しい会話のボタンもここに置く。
/// 使えないモデルは選べるが読み込めず、理由を表示する（何もしない画面を動くように見せない）。
@MainActor
struct AIModelPanel: View {
    let session: LLMSessionController
    @State private var options: [AIProviderOption] = []
    @State private var selectedID: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            if session.phase == .notLoaded {
                modelPicker
                if let option = selectedOption {
                    AIModelDescription(option: option)
                }
            } else {
                Label(statusTitle, systemImage: session.phase == .loading ? "hourglass" : "checkmark.circle")
                    .font(.headline)
            }
            if let error = session.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            AIModelActions(session: session, option: selectedOption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.medium)
        .background(.thinMaterial)
        .onAppear {
            refreshOptions()
        }
    }

    private var modelPicker: some View {
        Picker("モデル", selection: $selectedID) {
            ForEach(options) { (option: AIProviderOption) in
                Text(option.descriptor.displayName).tag(option.id)
            }
        }
        .pickerStyle(.segmented)
    }

    private var selectedOption: AIProviderOption? {
        options.first { (option: AIProviderOption) -> Bool in option.id == selectedID }
    }

    private var statusTitle: String {
        switch session.phase {
        case .loading:
            return "読み込み中…"
        case .ready, .generating:
            return "\(session.loadedModel?.displayName ?? "モデル")を使っています"
        case .notLoaded:
            return ""
        }
    }

    /// 開くたびに調べ直す（Apple Intelligence をオンにした後など）。使えるものがあればそれを選ぶ。
    private func refreshOptions() {
        let all: [AIProviderOption] = AIProviderOption.all()
        options = all
        if selectedOption == nil {
            let preferred: AIProviderOption? = all.first { (option: AIProviderOption) -> Bool in option.availability.isAvailable }
            selectedID = preferred?.id ?? all.first?.id ?? ""
        }
    }
}

/// 選んだモデルの説明と、使えない時の理由。
@MainActor
struct AIModelDescription: View {
    let option: AIProviderOption

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
            Text(option.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let reason = option.availability.reason {
                Label(reason, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }
}

@MainActor
struct AIModelActions: View {
    let session: LLMSessionController
    let option: AIProviderOption?

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            switch session.phase {
            case .notLoaded:
                Button("読み込む") {
                    load()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!(option?.availability.isAvailable ?? false))
            case .loading:
                ProgressView()
            case .ready, .generating:
                Button("新しい会話") {
                    restart()
                }
                .buttonStyle(.bordered)
                .disabled(session.phase == .generating)
                Button("解放する") {
                    unload()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    /// プロバイダーはボタンを押した時に初めて作る（遅延ロード）。
    private func load() {
        guard let provider = option?.makeProvider() else { return }
        let session: LLMSessionController = self.session
        Task {
            await session.load(using: provider)
        }
    }

    /// 会話を消し、モデルの会話の記憶もなくすため読み込み直す（F0362）。
    private func restart() {
        guard let provider = option?.makeProvider() else { return }
        let session: LLMSessionController = self.session
        Task {
            await session.unload()
            session.clearConversation()
            await session.load(using: provider)
        }
    }

    private func unload() {
        let session: LLMSessionController = self.session
        Task {
            await session.unload()
        }
    }
}
