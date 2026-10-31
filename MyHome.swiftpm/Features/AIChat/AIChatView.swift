import SwiftUI

/// AI 画面（F0361）。Apple の端末内モデル（使える端末だけ）とスタブから選ぶ。
/// この画面が開かれた時に初めてセッションを作り、「読み込む」を押した時だけプロバイダーを作って読み込む。
/// 画面を閉じたら生成を止めてモデルを解放する（F0896、F0439）。ホーム画面の起動時には何も作らない。
@MainActor
struct AIChatView: View {
    @State private var session = LLMSessionController()
    @State private var draft: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AIModelPanel(session: session)
                messageList
                AIInputBar(session: session, draft: $draft)
            }
            .navigationTitle("AI")
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
        ScrollViewReader { (proxy: ScrollViewProxy) in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                    ForEach(session.messages) { (message: LLMMessage) in
                        AIMessageRow(message: message)
                            .id(message.id)
                    }
                }
                .padding(DesignTokens.Spacing.medium)
            }
            .frame(maxHeight: .infinity)
            .onChange(of: session.messages.last?.text) { _, _ in
                // 生成中の文が伸びたら、いちばん下を表示する（F0391）
                if let last = session.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}
