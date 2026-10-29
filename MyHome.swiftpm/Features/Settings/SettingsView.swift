import SwiftUI

/// 設定（テーマと外観）。変更は自動で保存し、保存の状態も表示する（F0807、F0838）。
@MainActor
struct SettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("テーマ") {
                    ThemePickerView()
                }
                appearanceSection
                SaveStatusSection()
                Section("ソフトウェア") {
                    NavigationLink("ソフトウェアアップデート") {
                        SoftwareUpdateView()
                    }
                    LabeledContent("バージョン", value: AppInfo.version)
                }
            }
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
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
