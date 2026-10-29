/// 保存ファイルの中身（F0801–F0803、F0807）。JSON の未知のキーは読み飛ばす（F0822）。
/// 形式を変える時は currentSchemaVersion を上げ、HomeArchiveCodec.migrate に古い版からの変換を足す（F0823）。
/// 版 1: Phase 2（ページ・Dock・項目・設定）。版 2: Phase 3（項目の種類にフォルダが増えた）。
struct SavedHome: Codable, Hashable, Sendable {
    static let currentSchemaVersion: Int = 2

    var schemaVersion: Int
    var layout: HomeLayout
    var settings: SavedSettings

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case layout
        case settings
    }

    init(layout: HomeLayout, settings: SavedSettings) {
        self.schemaVersion = SavedHome.currentSchemaVersion
        self.layout = layout
        self.settings = settings
    }

    /// 保存ファイルがない時（初回起動）の内容。
    static func initial() -> SavedHome {
        SavedHome(layout: DefaultLayout.make(), settings: .defaults)
    }

    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        layout = try container.decode(HomeLayout.self, forKey: .layout)
        // 設定は失っても困らないため、なければ初期値にする（配置は厳密に読む）
        let decodedSettings: SavedSettings? = try? container.decodeIfPresent(SavedSettings.self, forKey: .settings)
        settings = decodedSettings ?? .defaults
    }
}

/// 保存する設定。読めない値は項目ごとに初期値に戻す。
struct SavedSettings: Codable, Hashable, Sendable {
    var themeID: String
    var appearance: ThemeAppearance

    static let defaults = SavedSettings(themeID: ThemeCatalog.defaultID, appearance: .system)

    private enum CodingKeys: String, CodingKey {
        case themeID
        case appearance
    }

    init(themeID: String, appearance: ThemeAppearance) {
        self.themeID = themeID
        self.appearance = appearance
    }

    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        let decodedTheme: String? = try? container.decodeIfPresent(String.self, forKey: .themeID)
        let decodedAppearance: ThemeAppearance? = try? container.decodeIfPresent(ThemeAppearance.self, forKey: .appearance)
        themeID = decodedTheme ?? SavedSettings.defaults.themeID
        appearance = decodedAppearance ?? SavedSettings.defaults.appearance
    }
}
