import SwiftUI

/// 設定（テーマと外観）。変更は自動で保存し、保存の状態も表示する（F0807、F0838）。
/// 中のページ（使い方・アップデート・バックアップ・このアプリについて）は AppRouter.settingsPath で開く。
@MainActor
struct SettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var navigation = router
        NavigationStack(path: $navigation.settingsPath) {
            Form {
                HomeStyleSection()
                Section("テーマ") {
                    ThemePickerView()
                }
                appearanceSection
                motionAndTextSection
                WallpaperSettingsSection()
                clockSection
                SaveStatusSection()
                Section("データ") {
                    NavigationLink(SettingsPage.backup.title, value: SettingsPage.backup)
                }
                Section("ソフトウェア") {
                    NavigationLink(SettingsPage.help.title, value: SettingsPage.help)
                    NavigationLink(SettingsPage.update.title, value: SettingsPage.update)
                    NavigationLink(SettingsPage.about.title, value: SettingsPage.about)
                    LabeledContent("バージョン", value: AppInfo.version)
                }
            }
            .navigationTitle("設定")
            .navigationDestination(for: SettingsPage.self) { (page: SettingsPage) in
                SettingsPageView(page: page)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            // 次に設定を開いた時は、最初のページから
            router.settingsPath = []
        }
    }

    private var clockSection: some View {
        @Bindable var bindable = settings
        return Section("時計") {
            Toggle("ホーム画面の時計に秒を表示", isOn: $bindable.showsSeconds)
        }
    }

    /// 動きと文字の大きさ（F0671、F0672、F0674、F0978）。
    private var motionAndTextSection: some View {
        @Bindable var bindable = settings
        return Section {
            Picker("動き", selection: $bindable.motion) {
                ForEach(MotionPreference.allCases) { (preference: MotionPreference) in
                    Text(preference.title).tag(preference)
                }
            }
            Picker("文字の大きさ", selection: $bindable.textSize) {
                ForEach(TextSizePreference.allCases) { (preference: TextSizePreference) in
                    Text(preference.title).tag(preference)
                }
            }
        } header: {
            Text("動きと文字")
        } footer: {
            Text("「端末の設定に合わせる」では、iPad の設定の「視差効果を減らす」（アクセシビリティ → 動作）と、文字の大きさに従います。")
        }
    }

    private var appearanceSection: some View {
        @Bindable var bindable = settings
        return Section("外観") {
            Picker("外観", selection: $bindable.appearance) {
                ForEach(ThemeAppearance.allCases, id: \.self) { appearance in
                    Text(appearance.title).tag(appearance)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

/// ホーム画面の形（追加フェーズ A）。ウィジェット型にした時、アプリのウィジェットがなければおすすめを足す。
@MainActor
struct HomeStyleSection: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(HomeStore.self) private var home

    var body: some View {
        let selection = Binding<HomeStyle>(
            get: { settings.homeStyle },
            set: { (style: HomeStyle) in HomeStyleSwitcher.apply(style, settings: settings, home: home) }
        )
        Section {
            Picker("ホーム画面", selection: selection) {
                ForEach(HomeStyle.allCases) { (style: HomeStyle) in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("ホーム画面")
        } footer: {
            Text(settings.homeStyle.detail)
        }
    }
}

/// 設定の中のページ。
@MainActor
struct SettingsPageView: View {
    let page: SettingsPage

    var body: some View {
        switch page {
        case .help:
            HelpView()
        case .update:
            SoftwareUpdateView()
        case .backup:
            BackupSettingsView()
        case .about:
            AboutView()
        }
    }
}
