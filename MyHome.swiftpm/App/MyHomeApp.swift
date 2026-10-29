import SwiftUI

/// アプリの入口。起動時に作るのはホーム画面の状態（配置・設定・画面遷移）だけで、
/// AI・天気・画像処理などの重いものは作らない（PLAN.md「ローカル LLM の方針」）。
@main
@MainActor
struct MyHomeApp: App {
    @State private var homeStore = HomeStore(layout: LaunchOptions.current().initialLayout())
    @State private var settings = SettingsStore()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            HomeScreen()
                .environment(homeStore)
                .environment(settings)
                .environment(router)
        }
    }
}
