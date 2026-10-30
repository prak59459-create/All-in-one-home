import SwiftUI

/// アプリの入口。起動時に作るのはホーム画面の状態（配置・設定・保存・画面遷移）だけで、
/// AI・天気・画像処理などの重いものは作らない（PLAN.md「ローカル LLM の方針」）。
/// データの状態一式は AppSession が持ち、復元・消去の後は読み直したものに入れ替わる（Phase 9）。
@main
@MainActor
struct MyHomeApp: App {
    @State private var session: AppSession
    @State private var router: AppRouter

    init() {
        // 端末内モデルが使えるかを先に調べる（ホーム画面の AI の項目の「スタブ」の印に使う。モデルは読み込まない）
        LLMRuntime.isSystemModelAvailable = SystemModelSupport.availability().isAvailable
        let options: LaunchOptions = LaunchOptions.current()
        let boot: AppBootstrap = AppBootstrap.make(options: options)
        let router = AppRouter()
        options.apply(to: router)
        let session = AppSession(boot: boot, configure: { (next: AppBootstrap) in
            MyHomeApp.configure(next, router: router)
        })
        // 読み直した後は、なくなったかもしれないフォルダや、編集モードを閉じる
        session.onReload = {
            router.closeFolder()
            router.endEditing()
        }
        // 保存データの説明はタイマーの知らせより大事なので、後から出して上書きされないようにする
        if let notice = boot.startupNotice {
            router.showNotice(title: "保存データについて", message: notice)
        }
        _session = State(initialValue: session)
        _router = State(initialValue: router)
    }

    var body: some Scene {
        WindowGroup {
            SessionRootView(session: session)
                .environment(router)
        }
    }

    /// タイマーが終わった時（アプリを開いている間だけ）。裏に回っていた間に終わったものは、前面に戻った時に知らせる。
    private static func configure(_ boot: AppBootstrap, router: AppRouter) {
        boot.timers.onFinish = { (timer: CountdownTimer) in
            TimerAlert.play()
            router.showNotice(title: "タイマー", message: "「\(timer.label)」が終わりました。")
        }
        boot.timers.refresh()
    }
}
