import SwiftUI

/// モデルの状態と、スタブであることの説明（F0378、F0397）。読み込み・解放のボタンもここに置く。
@MainActor
struct AIStatusBanner: View {
    let session: LLMSessionController

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Label(title, systemImage: symbolName)
                .font(.headline)
            Text("この画面の AI はスタブです。実際の推論は行わず、決まった文を返します。ローカル LLM の実推論は Phase 6 で PoC を行ってから対応を判断します。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let error = session.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            actionButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.medium)
        .background(.thinMaterial)
    }

    private var title: String {
        switch session.phase {
        case .notLoaded:
            return "モデル未導入（何も読み込んでいません）"
        case .loading:
            return "読み込み中…"
        case .ready, .generating:
            return session.loadedModel?.displayName ?? "読み込み済み"
        }
    }

    private var symbolName: String {
        session.phase == .notLoaded ? "cpu" : "checkmark.circle"
    }

    @ViewBuilder
    private var actionButton: some View {
        switch session.phase {
        case .notLoaded:
            Button("スタブを読み込む") {
                load()
            }
            .buttonStyle(.borderedProminent)
        case .loading:
            ProgressView()
        case .ready, .generating:
            Button("解放する") {
                unload()
            }
            .buttonStyle(.bordered)
        }
    }

    /// プロバイダーはボタンを押した時に初めて作る（遅延ロード）。
    private func load() {
        let session: LLMSessionController = self.session
        Task {
            await session.load(using: StubLocalLLMProvider())
        }
    }

    private func unload() {
        let session: LLMSessionController = self.session
        Task {
            await session.unload()
        }
    }
}
