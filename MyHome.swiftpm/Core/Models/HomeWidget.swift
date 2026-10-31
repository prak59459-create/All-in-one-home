/// ページの上部に置くアプリ内ウィジェット（F0161–F0168）。iPadOS のホーム画面のウィジェット（WidgetKit）とは別物。
struct HomeWidget: Identifiable, Hashable, Codable, Sendable {
    let id: String
    var kind: WidgetKind
    var size: WidgetSize
}

/// ウィジェットの大きさ（F0166、F0167）。小は正方形、中は横長。
enum WidgetSize: String, CaseIterable, Codable, Sendable {
    case small
    case medium

    var title: String {
        switch self {
        case .small: return "小"
        case .medium: return "中"
        }
    }
}

/// ウィジェットの種類と、その設定。
enum WidgetKind: Hashable, Sendable {
    /// 時計（F0201、F0202、F0203）。
    case clock(ClockWidgetStyle)
    /// 今月のカレンダー（F0241、F0243）。
    case calendar
    /// 短いメモ（付箋）。本格的なメモは Phase 5 のミニアプリ。
    case note(String)
    /// タイマー（TimerBoard の先頭のカウントダウンを表示する。F0218–F0222）。
    case timer
    /// アプリ（機能）を開くウィジェット（追加フェーズ A。アイコンの代わり）。天気・メモ・タスクなどは中身の一部も表示する。
    case app(AppFeature)

    /// ギャラリー（F0161）に並べる既定の設定。
    static let galleryKinds: [WidgetKind] = [
        .clock(ClockWidgetStyle(isAnalog: false, showsSeconds: false)),
        .clock(ClockWidgetStyle(isAnalog: true, showsSeconds: true)),
        .calendar,
        .note(""),
        .timer
    ] + appKinds

    /// アプリのウィジェットにできる機能（開ける機能だけ）。
    static var appKinds: [WidgetKind] {
        AppFeature.allCases
            .filter { (feature: AppFeature) -> Bool in feature.state.canOpen && feature != .timer }
            .map { (feature: AppFeature) -> WidgetKind in .app(feature) }
    }

    var title: String {
        switch self {
        case .clock(let style): return style.isAnalog ? "アナログ時計" : "デジタル時計"
        case .calendar: return "カレンダー"
        case .note: return "付箋"
        case .timer: return "タイマー"
        case .app(let feature): return feature.title
        }
    }

    var symbolName: String {
        switch self {
        case .clock: return "clock"
        case .calendar: return "calendar"
        case .note: return "square.and.pencil"
        case .timer: return "timer"
        case .app(let feature): return FeatureIconStyle.of(feature).symbol
        }
    }

    /// アプリのウィジェットなら、その機能。
    var feature: AppFeature? {
        if case .app(let feature) = self {
            return feature
        }
        return nil
    }
}

/// 時計ウィジェットの表示。12 時間 / 24 時間の表示は端末の設定に従う（F0204、F0205）。
struct ClockWidgetStyle: Hashable, Codable, Sendable {
    var isAnalog: Bool
    var showsSeconds: Bool
}

enum WidgetLimits {
    /// 1ページに置けるウィジェットの数（追加フェーズ A でウィジェット型のホーム画面にしたので 8 から 12 に）。
    static let maximumPerPage: Int = 12
    /// メモの最大文字数。
    static let maximumNoteLength: Int = 2000
}
