import SwiftUI

/// 項目をタップした後のシートとダイアログ。外部 URL は確認してから開き（F0070、F0854）、
/// 開けなかった時はその旨を表示する（F0784）。項目の削除の確認（F0042）もここで出す。
/// アプリ（機能）は全画面で、項目の追加・編集などの画面はシートで開く（AppSheet.isFullScreen）。
@MainActor
struct LaunchPresentationModifier: ViewModifier {
    @Bindable var router: AppRouter
    @Environment(HomeStore.self) private var store
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: presented(fullScreen: true)) { (sheet: AppSheet) in
                FullScreenFeatureView(sheet: sheet)
            }
            .sheet(item: presented(fullScreen: false)) { (sheet: AppSheet) in
                FeatureSheetView(sheet: sheet)
            }
            .alert(alertTitle, isPresented: $router.isShowingAlert, presenting: router.alert) { alert in
                alertActions(for: alert)
            } message: { alert in
                Text(alert.message)
            }
    }

    /// router.sheet のうち、全画面（またはシート）で出すものだけを見せる。閉じた時は、その種類のものが開いている時だけ消す。
    private func presented(fullScreen: Bool) -> Binding<AppSheet?> {
        let router: AppRouter = self.router
        return Binding<AppSheet?>(
            get: { router.sheet?.isFullScreen == fullScreen ? router.sheet : nil },
            set: { (next: AppSheet?) in
                if let next {
                    router.sheet = next
                } else if router.sheet?.isFullScreen == fullScreen {
                    router.sheet = nil
                }
            }
        )
    }

    private var alertTitle: String {
        router.alert?.title ?? ""
    }

    @ViewBuilder
    private func alertActions(for alert: AppAlert) -> some View {
        switch alert {
        case .confirmURL(let checked):
            Button("開く") {
                open(checked)
            }
            Button("キャンセル", role: .cancel) {}
        case .confirmRemoval(let item):
            Button("削除", role: .destructive) {
                remove(item)
            }
            Button("キャンセル", role: .cancel) {}
        case .confirmWidgetRemoval(let widget):
            Button("削除", role: .destructive) {
                try? store.removeWidget(id: widget.id)
            }
            Button("キャンセル", role: .cancel) {}
        case .message, .notice:
            Button("OK", role: .cancel) {}
        }
    }

    private func remove(_ item: HomeItem) {
        do {
            try store.remove(itemID: item.id)
        } catch let error as LayoutEditError {
            router.showNotice(title: "削除できません", message: error.message)
        } catch {
            router.showNotice(title: "削除できません", message: "もう一度お試しください。")
        }
    }

    private func open(_ checked: CheckedURL) {
        let router: AppRouter = self.router
        openURL(checked.url) { accepted in
            guard !accepted else { return }
            Task { @MainActor in
                router.reportOpenFailure(checked)
            }
        }
    }
}
