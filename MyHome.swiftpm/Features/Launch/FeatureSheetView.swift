import SwiftUI

/// シート・全画面の中身。機能ごとの画面はここで選ぶ。AI 画面はこの画面が開かれた時に初めて作られる。
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

/// 全画面で開いたアプリ。どのアプリにも「閉じる」「完了」があり、iPad のキーボードでは ⌘W でも閉じる。
@MainActor
struct FullScreenFeatureView: View {
    let sheet: AppSheet
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        FeatureSheetView(sheet: sheet)
            .background {
                Button("閉じる") {
                    dismiss()
                }
                .keyboardShortcut("w", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
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
            AIChatView()
        case .timer:
            TimerAppView()
        case .notes:
            NotesAppView()
        case .tasks:
            TodoAppView()
        case .calculator:
            CalculatorAppView()
        case .unitConverter:
            UnitConverterAppView()
        case .textTools:
            TextToolsAppView()
        case .weather:
            WeatherAppView()
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
