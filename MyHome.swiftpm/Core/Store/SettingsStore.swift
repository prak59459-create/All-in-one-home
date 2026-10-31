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

    /// アニメーションの量（F0671、F0672、F0674）。
    var motion: MotionPreference {
        didSet {
            if motion != oldValue {
                onChange?()
            }
        }
    }

    /// このアプリの中の文字の大きさ（F0978）。
    var textSize: TextSizePreference {
        didSet {
            if textSize != oldValue {
                onChange?()
            }
        }
    }

    /// ホーム画面の形（追加フェーズ A）。
    var homeStyle: HomeStyle {
        didSet {
            if homeStyle != oldValue {
                onChange?()
            }
        }
    }

    /// 初期設定を終えたか（追加フェーズ A）。
    var hasCompletedSetup: Bool {
        didSet {
            if hasCompletedSetup != oldValue {
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
        showsSeconds: Bool = false,
        motion: MotionPreference = .system,
        textSize: TextSizePreference = .system,
        homeStyle: HomeStyle = .widgets,
        hasCompletedSetup: Bool = false
    ) {
        self.themeID = themeID
        self.appearance = appearance
        self.wallpaper = wallpaper
        self.showsSeconds = showsSeconds
        self.motion = motion
        self.textSize = textSize
        self.homeStyle = homeStyle
        self.hasCompletedSetup = hasCompletedSetup
    }

    convenience init(saved: SavedSettings) {
        self.init(
            themeID: saved.themeID,
            appearance: saved.appearance,
            wallpaper: saved.wallpaper,
            showsSeconds: saved.showsSeconds,
            motion: saved.motion,
            textSize: saved.textSize,
            homeStyle: saved.homeStyle,
            hasCompletedSetup: saved.hasCompletedSetup
        )
    }

    var theme: ThemePreset {
        ThemeCatalog.preset(id: themeID)
    }

    /// 保存する内容。
    var saved: SavedSettings {
        SavedSettings(
            themeID: themeID,
            appearance: appearance,
            wallpaper: wallpaper,
            showsSeconds: showsSeconds,
            motion: motion,
            textSize: textSize,
            homeStyle: homeStyle,
            hasCompletedSetup: hasCompletedSetup
        )
    }
}
