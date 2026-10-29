/// ホーム画面の項目から開くアプリ内の機能。未実装のものも登録し、状態を正直に表示する。
enum AppFeature: String, CaseIterable, Codable, Sendable {
    case settings
    case featureStatus
    case aiAssistant
    case notes
    case calculator
    case timer

    var title: String {
        switch self {
        case .settings: return "設定"
        case .featureStatus: return "機能の状況"
        case .aiAssistant: return "AI"
        case .notes: return "メモ"
        case .calculator: return "電卓"
        case .timer: return "タイマー"
        }
    }

    var state: FeatureState {
        switch self {
        case .settings, .featureStatus: return .available
        case .aiAssistant: return .stub
        case .timer: return .planned(phase: 4)
        case .notes, .calculator: return .planned(phase: 5)
        }
    }

    /// 開けない機能をタップした時に表示する説明。
    var unavailableDetail: String {
        switch self {
        case .settings, .featureStatus, .aiAssistant:
            return "この機能は利用できます。"
        case .notes:
            return "メモは Phase 5 でミニアプリとして実装する予定です（保存の仕組みは Phase 2 で用意済み）。"
        case .calculator:
            return "電卓は Phase 5 でミニアプリとして実装する予定です。"
        case .timer:
            return "タイマーは Phase 4 で実装する予定です。アプリを閉じている間の計測や通知には OS の制限があります。"
        }
    }
}
