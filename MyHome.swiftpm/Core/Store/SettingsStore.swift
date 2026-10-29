import Observation

/// 外観の設定。Phase 1 ではアプリを終了すると初期値に戻る（保存は Phase 2）。
@MainActor
@Observable
final class SettingsStore {
    var themeID: String
    var appearance: ThemeAppearance

    init(themeID: String = ThemeCatalog.defaultID, appearance: ThemeAppearance = .system) {
        self.themeID = themeID
        self.appearance = appearance
    }

    var theme: ThemePreset {
        ThemeCatalog.preset(id: themeID)
    }
}
