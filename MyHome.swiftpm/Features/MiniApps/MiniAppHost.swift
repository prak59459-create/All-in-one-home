import SwiftUI

/// ミニアプリの共通の枠（F0487–F0489、F0500）。データを読み込むまで待ち、読めなかった時は理由を一度だけ表示する。
/// 保存できない時（失敗・検証用の起動）は、下に帯を出す。
@MainActor
struct MiniAppHost<Content: MiniAppContent, Page: View>: View {
    let document: MiniAppDocument<Content>
    @ViewBuilder let page: () -> Page

    var body: some View {
        Group {
            if document.isLoaded {
                page()
            } else {
                ProgressView("読み込んでいます…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom) {
            MiniAppSaveBanner(status: document.status)
        }
        .alert("データについて", isPresented: isShowingNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(document.notice ?? "")
        }
        .task {
            await document.load()
        }
    }

    private var isShowingNotice: Binding<Bool> {
        Binding<Bool>(
            get: { document.notice != nil },
            set: { (isShown: Bool) in
                if !isShown {
                    document.notice = nil
                }
            }
        )
    }
}

/// 保存できない時だけ出す帯（保存できている時・保存待ちの時は何も出さない）。
@MainActor
struct MiniAppSaveBanner: View {
    let status: PersistenceController.Status

    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.primary)
                .padding(.horizontal, DesignTokens.Spacing.medium)
                .padding(.vertical, DesignTokens.Spacing.small)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial)
        }
    }

    private var message: String? {
        switch status {
        case .failed(let text):
            return text
        case .disabled(let reason):
            return "変更は保存されません。" + reason
        case .saved, .pending:
            return nil
        }
    }
}

/// ミニアプリのシートの外枠（ナビゲーションと「閉じる」）。
@MainActor
struct MiniAppScaffold<Page: View>: View {
    let title: String
    @ViewBuilder let page: () -> Page
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            page()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") {
                            dismiss()
                        }
                    }
                }
        }
    }
}
