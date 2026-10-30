import SwiftUI

/// 入力欄と、送信・中断ボタン（F0392 生成のキャンセル）。
@MainActor
struct AIInputBar: View {
    let session: LLMSessionController
    @Binding var draft: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            TextField(placeholder, text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .disabled(session.phase != .ready)
            primaryButton
        }
        .padding(DesignTokens.Spacing.medium)
        .background(.bar)
    }

    @ViewBuilder
    private var primaryButton: some View {
        if session.phase == .generating {
            Button {
                session.cancelGeneration()
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.title2)
            }
            .accessibilityLabel("生成を中断")
        } else {
            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(!canSend)
            .accessibilityLabel("送信")
        }
    }

    private var placeholder: String {
        session.loadedModel?.format == .stub ? "メッセージ（スタブに送信）" : "メッセージ"
    }

    private var canSend: Bool {
        let text: String = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return session.phase == .ready && !text.isEmpty
    }

    private func send() {
        session.send(draft)
        draft = ""
    }
}
