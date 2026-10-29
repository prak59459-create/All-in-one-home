import SwiftUI

/// 項目をタップした後のシートとダイアログ。外部 URL は確認してから開き（F0070、F0854）、
/// 開けなかった時はその旨を表示する（F0784）。項目の削除の確認（F0042）もここで出す。
@MainActor
struct LaunchPresentationModifier: ViewModifier {
    @Bindable var router: AppRouter
    @Environment(HomeStore.self) private var store
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content
            .sheet(item: $router.sheet) { sheet in
                FeatureSheetView(sheet: sheet)
            }
            .alert(alertTitle, isPresented: $router.isShowingAlert, presenting: router.alert) { alert in
                alertActions(for: alert)
            } message: { alert in
                Text(alert.message)
            }
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
