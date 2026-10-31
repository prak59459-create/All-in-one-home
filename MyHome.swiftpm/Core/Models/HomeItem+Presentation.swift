/// アイコンに重ねて種類を示す印。外部リンクや未実装の項目を、本物のアプリ起動と誤認させないために使う。
enum HomeItemBadge: Hashable, Sendable {
    case externalLink
    case stub
    case planned

    /// アイコンに重ねる短い文字（外部リンクは矢印の記号だけを使う）。
    var text: String? {
        switch self {
        case .externalLink: return nil
        case .stub: return "スタブ"
        case .planned: return "準備中"
        }
    }

    /// 印の背景色。白い文字を重ねるため、白とのコントラスト比 4.5 以上にする。
    var fill: RGBAColor {
        switch self {
        case .externalLink: return RGBAColor(hex: 0x1D4ED8)
        case .stub: return RGBAColor(hex: 0x6D28D9)
        case .planned: return RGBAColor(hex: 0x4B5563)
        }
    }
}

extension HomeItem {
    var badge: HomeItemBadge? {
        switch action {
        case .openURL:
            return .externalLink
        case .feature(let feature):
            return HomeItem.badge(for: feature.state)
        case .folder:
            return nil
        }
    }

    /// VoiceOver で項目名の後に読み上げる補足。
    var accessibilityHint: String {
        switch action {
        case .openURL:
            return "外部リンク。開く前に確認します"
        case .feature(let feature):
            return HomeItem.featureHint(for: feature.state)
        case .folder(let items):
            return "フォルダ。\(items.count) 個の項目があります"
        }
    }

    /// 機能の項目の読み上げの補足（状態を指定してテストできるように分けた）。
    static func featureHint(for state: FeatureState) -> String {
        if state.canOpen {
            return state == .stub ? "スタブです。実際の処理は行いません" : "アプリ内の機能を開きます"
        }
        return "\(state.label)の機能です"
    }

    /// 機能の状態ごとの印（状態を指定してテストできるように分けた）。
    static func badge(for state: FeatureState) -> HomeItemBadge? {
        switch state {
        case .available: return nil
        case .stub: return .stub
        case .planned, .needsPoC, .osLimited: return .planned
        }
    }
}
