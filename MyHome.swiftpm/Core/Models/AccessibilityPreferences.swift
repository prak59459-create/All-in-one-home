/// アニメーションの設定（F0671、F0672、F0674、F0981）。
enum MotionPreference: String, Codable, CaseIterable, Identifiable, Sendable {
    /// 端末の「視差効果を減らす」に従う。
    case system
    /// 拡大・移動・ばねの動きをやめ、フェードだけにする。
    case reduced
    /// アニメーションをしない。
    case off

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "端末の設定に合わせる"
        case .reduced: return "減らす（フェードだけ）"
        case .off: return "オフ"
        }
    }
}

/// 実際に使う動きの量。設定と端末の「視差効果を減らす」から決める。
enum MotionLevel: Hashable, Sendable {
    case full
    case reduced
    case none

    static func resolve(_ preference: MotionPreference, systemReduceMotion: Bool) -> MotionLevel {
        switch preference {
        case .system: return systemReduceMotion ? .reduced : .full
        case .reduced: return .reduced
        case .off: return .none
        }
    }

    /// 拡大・縮小・移動・ばねの動きをしてよいか。
    var allowsMovement: Bool {
        self == .full
    }

    /// フェード（透明度の変化）をしてよいか。
    var allowsFade: Bool {
        self != .none
    }
}

/// このアプリの中の文字の大きさ（F0978）。端末の設定と違う大きさにしたい時に使う。
enum TextSizePreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case small
    case standard
    case large
    case extraLarge
    case largest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "端末の設定に合わせる"
        case .small: return "小さい"
        case .standard: return "標準"
        case .large: return "大きい"
        case .extraLarge: return "とても大きい"
        case .largest: return "最大（アクセシビリティ）"
        }
    }
}

/// ホーム画面の形（追加フェーズ A）。ウィジェット型ではアプリのアイコンと Dock を出さず、ウィジェットからアプリを開く。
enum HomeStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case widgets
    case icons

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .widgets: return "ウィジェット"
        case .icons: return "アイコン"
        }
    }

    var detail: String {
        switch self {
        case .widgets:
            return "ウィジェットを並べ、アプリはウィジェットか下の「アプリ」から開きます。アイコンと Dock は表示しません（配置は残っていて、アイコンに戻すと表示します）。"
        case .icons:
            return "アイコンと Dock を並べます。ウィジェットは各ページの上部に横に並びます。"
        }
    }
}
