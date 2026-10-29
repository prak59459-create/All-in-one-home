import SwiftUI

/// 会話の1件。スタブの応答には「AI ではありません」と表示する（F0461）。
@MainActor
struct AIMessageRow: View {
    let message: LLMMessage

    var body: some View {
        VStack(alignment: horizontalAlignment, spacing: DesignTokens.Spacing.xSmall) {
            Text(roleLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(displayedText)
                .padding(DesignTokens.Spacing.small)
                .background(bubbleColor, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .accessibilityElement(children: .combine)
    }

    private var isUser: Bool {
        message.role == .user
    }

    private var roleLabel: String {
        if isUser {
            return "あなた"
        }
        return message.isStub ? "スタブ（AI ではありません）" : "AI"
    }

    private var displayedText: String {
        message.text.isEmpty ? "…" : message.text
    }

    private var bubbleColor: Color {
        isUser ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.15)
    }

    private var horizontalAlignment: HorizontalAlignment {
        isUser ? .trailing : .leading
    }

    private var frameAlignment: Alignment {
        isUser ? .trailing : .leading
    }
}
