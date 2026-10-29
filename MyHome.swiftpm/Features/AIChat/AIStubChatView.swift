import SwiftUI

/// AI 画面（現時点ではスタブのみ。F0361、F0468）。
/// この画面が開かれた時に初めてセッションを作り、「スタブを読み込む」を押した時だけプロバイダーを作って読み込む。
/// 画面を閉じたら生成を止めてモデルを解放する（F0896、F0439）。ホーム画面の起動時には何も作らない。
@MainActor
struct AIStubChatView: View {
    @State private var session = LLMSessionController()
    @State private var draft: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AIStatusBanner(session: session)
                messageList
                AIInputBar(session: session, draft: $draft)
            }
            .navigationTitle("AI（スタブ）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            let session: LLMSessionController = self.session
            Task {
                await session.unload()
            }
        }
    }

    private var messageList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                ForEach(session.messages) { message in
                    AIMessageRow(message: message)
                }
            }
            .padding(DesignTokens.Spacing.medium)
        }
        .frame(maxHeight: .infinity)
    }
}
