import SwiftUI

/// アプリの入口。起動時に作るのはホーム画面の状態（配置・設定・保存・画面遷移）だけで、
/// AI・天気・画像処理などの重いものは作らない（PLAN.md「ローカル LLM の方針」）。
@main
@MainActor
struct MyHomeApp: App {
    @State private var homeStore: HomeStore
    @State private var settings: SettingsStore
    @State private var persistence: PersistenceController
    @State private var timers: TimerStore
    @State private var miniApps: MiniAppLibrary
    @State private var router: AppRouter
    private let images: ImageFileStore?
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // 端末内モデルが使えるかを先に調べる（ホーム画面の AI の項目の「スタブ」の印に使う。モデルは読み込まない）
        LLMRuntime.isSystemModelAvailable = SystemModelSupport.availability().isAvailable
        let options: LaunchOptions = LaunchOptions.current()
        let boot: AppBootstrap = AppBootstrap.make(options: options)
        let router = AppRouter()
        options.apply(to: router)
        // タイマーが終わった時（アプリを開いている間だけ）。裏に回っていた間に終わったものは、前面に戻った時に知らせる
        boot.timers.onFinish = { timer in
            TimerAlert.play()
            router.showNotice(title: "タイマー", message: "「\(timer.label)」が終わりました。")
        }
        boot.timers.refresh()
        // 保存データの説明はタイマーの知らせより大事なので、後から出して上書きされないようにする
        if let notice = boot.startupNotice {
            router.showNotice(title: "保存データについて", message: notice)
        }
        _homeStore = State(initialValue: boot.home)
        _settings = State(initialValue: boot.settings)
        _persistence = State(initialValue: boot.persistence)
        _timers = State(initialValue: boot.timers)
        _miniApps = State(initialValue: boot.miniApps)
        _router = State(initialValue: router)
        images = boot.images
    }

    var body: some Scene {
        WindowGroup {
            HomeScreen()
                .environment(homeStore)
                .environment(settings)
                .environment(persistence)
                .environment(timers)
                .environment(miniApps)
                .environment(router)
                .environment(\.imageStore, images)
                .onChange(of: scenePhase) { _, phase in
                    // 裏に回る時は待たずに保存する（F0837。裏に回った後は OS が止めることがある）。ミニアプリのデータも同じ
                    if phase != .active {
                        Task {
                            await persistence.flush()
                            await miniApps.flushAll()
                        }
                    } else {
                        timers.refresh()
                    }
                }
        }
    }
}
