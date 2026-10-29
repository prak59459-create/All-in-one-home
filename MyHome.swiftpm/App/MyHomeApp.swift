import SwiftUI

/// Phase 0: ビルド時間の基準値を取るための最小アプリ。
@main
struct MyHomeApp: App {
    var body: some Scene {
        WindowGroup {
            Text(AppInfo.displayName)
                .font(.largeTitle)
        }
    }
}
