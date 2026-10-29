import SwiftUI

/// 設定（Phase 1 はテーマと外観のみ）。保存はまだ行わないことを画面でも示す。
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
                Section {
                    Text("設定はまだ保存されません。アプリを終了すると初期値に戻ります（Phase 2 で保存に対応）。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
