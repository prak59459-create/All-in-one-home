import Observation

/// 外観の設定。変わると onChange で保存を予約する（F0807）。
@MainActor
@Observable
final class SettingsStore {
    var themeID: String {
        didSet {
            if themeID != oldValue {
                onChange?()
            }
        }
    }

    var appearance: ThemeAppearance {
        didSet {
            if appearance != oldValue {
                onChange?()
            }
        }
    }

    /// 壁紙（F0646、F0647）。
    var wallpaper: WallpaperSetting {
        didSet {
            if wallpaper != oldValue {
                onChange?()
            }
        }
    }

    /// ホーム画面上部の時計に秒を表示する（F0203）。
    var showsSeconds: Bool {
        didSet {
            if showsSeconds != oldValue {
                onChange?()
            }
        }
    }

    /// 設定が変わった時に呼ぶ（PersistenceController.attach が設定する）。
    @ObservationIgnored var onChange: (@MainActor () -> Void)?

    init(
        themeID: String = ThemeCatalog.defaultID,
        appearance: ThemeAppearance = .system,
        wallpaper: WallpaperSetting = .themeGradient,
        showsSeconds: Bool = false
    ) {
        self.themeID = themeID
        self.appearance = appearance
        self.wallpaper = wallpaper
        self.showsSeconds = showsSeconds
    }

    convenience init(saved: SavedSettings) {
        self.init(themeID: saved.themeID, appearance: saved.appearance, wallpaper: saved.wallpaper, showsSeconds: saved.showsSeconds)
    }

    var theme: ThemePreset {
        ThemeCatalog.preset(id: themeID)
    }

    /// 保存する内容。
    var saved: SavedSettings {
        SavedSettings(themeID: themeID, appearance: appearance, wallpaper: wallpaper, showsSeconds: showsSeconds)
    }
}
