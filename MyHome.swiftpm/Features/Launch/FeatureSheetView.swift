import SwiftUI

/// シートの中身。機能ごとの画面はここで選ぶ。AI 画面はこのシートが開かれた時に初めて作られる。
@MainActor
struct FeatureSheetView: View {
    let sheet: AppSheet
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        destination
            .preferredColorScheme(settings.appearance.colorScheme)
    }

    @ViewBuilder
    private var destination: some View {
        switch sheet {
        case .feature(let feature):
            FeatureDestinationView(feature: feature)
        case .unavailable(let feature):
            UnavailableFeatureView(feature: feature)
        case .addItem(let pageIndex):
            AddItemView(pageIndex: pageIndex)
        case .editItem(let itemID):
            ItemEditorView(itemID: itemID)
        case .managePages:
            PageManagerView()
        case .editWidget(let widgetID):
            WidgetEditorView(widgetID: widgetID)
        }
    }
}

@MainActor
struct FeatureDestinationView: View {
    let feature: AppFeature

    var body: some View {
        switch feature {
        case .settings:
            SettingsView()
        case .featureStatus:
            FeatureStatusView()
        case .aiAssistant:
            AIStubChatView()
        case .timer:
            TimerAppView()
        case .notes, .calculator:
            UnavailableFeatureView(feature: feature)
        }
    }
}

/// 準備中などで開けない機能の説明。何もしない画面を動くように見せない（F0080）。
@MainActor
struct UnavailableFeatureView: View {
    let feature: AppFeature
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label(feature.title, systemImage: "hourglass")
            } description: {
                Text(message)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var message: String {
        feature.state.label + "\n" + feature.unavailableDetail
    }
}
