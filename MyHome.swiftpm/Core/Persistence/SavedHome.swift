/// 保存ファイルの中身（F0801–F0803、F0807）。JSON の未知のキーは読み飛ばす（F0822）。
/// 形式を変える時は currentSchemaVersion を上げ、HomeArchiveCodec.migrate に古い版からの変換を足す（F0823）。
/// 版 1: Phase 2（ページ・Dock・項目・設定）。版 2: Phase 3（項目の種類にフォルダが増えた）。
/// 版 3: Phase 4（ページのウィジェット、項目の画像、壁紙、タイマー）。
/// 版 4: 追加フェーズ A（アプリのウィジェット。古い版のアプリが読むと壊れたファイルと見なすので、版を上げて「新しい版のデータ」として断らせる）。
/// どれも足しただけなので、古い版はそのまま読める。
struct SavedHome: Codable, Hashable, Sendable {
    static let currentSchemaVersion: Int = 4

    var schemaVersion: Int
    var layout: HomeLayout
    var settings: SavedSettings
    var timers: TimerBoard

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case layout
        case settings
        case timers
    }

    init(layout: HomeLayout, settings: SavedSettings, timers: TimerBoard = .initial()) {
        self.schemaVersion = SavedHome.currentSchemaVersion
        self.layout = layout
        self.settings = settings
        self.timers = timers
    }

    /// 保存ファイルがない時（初回起動）の内容。
    static func initial() -> SavedHome {
        SavedHome(layout: DefaultLayout.make(), settings: .defaults)
    }

    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        layout = try container.decode(HomeLayout.self, forKey: .layout)
        // 設定とタイマーは失っても困らないため、なければ・読めなければ初期値にする（配置は厳密に読む）
        let decodedSettings: SavedSettings? = try? container.decodeIfPresent(SavedSettings.self, forKey: .settings)
        settings = decodedSettings ?? .defaults
        let decodedTimers: TimerBoard? = try? container.decodeIfPresent(TimerBoard.self, forKey: .timers)
        timers = decodedTimers.map(TimerValidator.sanitized) ?? .initial()
    }

    /// 参照している画像ファイル名（使われていない画像を消す時に使う）。
    var referencedImageNames: Set<String> {
        var names: Set<String> = layout.referencedImageNames
        if let wallpaper = settings.wallpaper.imageFileName {
            names.insert(wallpaper)
        }
        return names
    }
}

/// 保存する設定。読めない値は項目ごとに初期値に戻す。
struct SavedSettings: Codable, Hashable, Sendable {
    var themeID: String
    var appearance: ThemeAppearance
    var wallpaper: WallpaperSetting
    /// ホーム画面上部の時計に秒を表示する（F0203）。
    var showsSeconds: Bool
    /// アニメーションの量（F0671、F0672）。Phase 8 で追加。ない時は端末の設定に合わせる。
    var motion: MotionPreference
    /// このアプリの中の文字の大きさ（F0978）。Phase 8 で追加。ない時は端末の設定に合わせる。
    var textSize: TextSizePreference
    /// ホーム画面の形（追加フェーズ A）。ない時はウィジェット型（ユーザーの依頼で、アイコンは基本置かない）。
    var homeStyle: HomeStyle
    /// 初期設定を終えたか（追加フェーズ A）。ない時は終えていない（初めての起動・この版にした最初の起動で一度出す）。
    var hasCompletedSetup: Bool

    static let defaults = SavedSettings(themeID: ThemeCatalog.defaultID, appearance: .system)

    private enum CodingKeys: String, CodingKey {
        case themeID
        case appearance
        case wallpaper
        case showsSeconds
        case motion
        case textSize
        case homeStyle
        case hasCompletedSetup
    }

    init(
        themeID: String,
        appearance: ThemeAppearance,
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

    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        let decodedTheme: String? = try? container.decodeIfPresent(String.self, forKey: .themeID)
        let decodedAppearance: ThemeAppearance? = try? container.decodeIfPresent(ThemeAppearance.self, forKey: .appearance)
        let decodedWallpaper: WallpaperSetting? = try? container.decodeIfPresent(WallpaperSetting.self, forKey: .wallpaper)
        let decodedSeconds: Bool? = try? container.decodeIfPresent(Bool.self, forKey: .showsSeconds)
        let decodedMotion: MotionPreference? = try? container.decodeIfPresent(MotionPreference.self, forKey: .motion)
        let decodedTextSize: TextSizePreference? = try? container.decodeIfPresent(TextSizePreference.self, forKey: .textSize)
        let decodedStyle: HomeStyle? = try? container.decodeIfPresent(HomeStyle.self, forKey: .homeStyle)
        let decodedSetup: Bool? = try? container.decodeIfPresent(Bool.self, forKey: .hasCompletedSetup)
        themeID = decodedTheme ?? SavedSettings.defaults.themeID
        appearance = decodedAppearance ?? SavedSettings.defaults.appearance
        wallpaper = decodedWallpaper ?? .themeGradient
        showsSeconds = decodedSeconds ?? false
        motion = decodedMotion ?? .system
        textSize = decodedTextSize ?? .system
        homeStyle = decodedStyle ?? .widgets
        hasCompletedSetup = decodedSetup ?? false
    }
}
