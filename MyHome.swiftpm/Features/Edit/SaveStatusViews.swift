import SwiftUI

/// 保存に失敗した時だけホーム画面に出す帯（F0834）。操作を止めずに知らせ、やり直せるようにする。
@MainActor
struct SaveStatusBanner: View {
    @Environment(PersistenceController.self) private var persistence

    var body: some View {
        if case .failed(let message) = persistence.status {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.small) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text(message)
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("再試行") {
                    Task { await persistence.flush() }
                }
                .buttonStyle(.bordered)
            }
            .padding(DesignTokens.Spacing.small)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous))
            .padding(.horizontal, DesignTokens.Grid.horizontalPadding)
        }
    }
}

/// 設定画面の保存状態（F0838）。
@MainActor
struct SaveStatusSection: View {
    @Environment(PersistenceController.self) private var persistence

    var body: some View {
        Section("保存") {
            Label(statusText, systemImage: statusSymbol)
            if case .failed = persistence.status {
                Button("もう一度保存する") {
                    Task { await persistence.flush() }
                }
            }
        }
    }

    private var statusText: String {
        switch persistence.status {
        case .disabled(let reason):
            return reason
        case .pending:
            return "保存しています…"
        case .failed(let message):
            return message
        case .saved:
            return savedText
        }
    }

    private var savedText: String {
        guard let date = persistence.lastSavedAt else {
            return "配置と設定は変更すると自動で保存されます。"
        }
        return "保存しました（\(date.formatted(date: .omitted, time: .shortened))）。"
    }

    private var statusSymbol: String {
        switch persistence.status {
        case .disabled: return "nosign"
        case .pending: return "arrow.triangle.2.circlepath"
        case .failed: return "exclamationmark.triangle"
        case .saved: return "checkmark.circle"
        }
    }
}
