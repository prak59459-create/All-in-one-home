import SwiftUI

/// 今のデータの状態（AppSession.boot）のストアを、画面全体に渡す。
/// 復元・消去の後はストアが入れ替わり、開いている画面（設定など）もそのまま新しい状態を表示する。
@MainActor
struct SessionRootView: View {
    let session: AppSession
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let boot: AppBootstrap = session.boot
        // 動きの量と文字の大きさの設定は、ホーム画面とシートの全部に効くよう一番外側で渡す
        AccessibilityRoot {
            HomeScreen()
        }
        .environment(boot.home)
        .environment(boot.settings)
        .environment(boot.persistence)
        .environment(boot.timers)
        .environment(boot.miniApps)
        .environment(session)
        .environment(\.imageStore, boot.images)
        .onChange(of: scenePhase) { (_: ScenePhase, phase: ScenePhase) in
            // 裏に回る時は待たずに保存する（F0837。裏に回った後は OS が止めることがある）。ミニアプリのデータも同じ
            if phase != .active {
                Task {
                    await session.flush()
                }
            } else {
                session.boot.timers.refresh()
            }
        }
    }
}
