/// ホーム画面の項目から開くアプリ内の機能。未実装のものも登録し、状態を正直に表示する。
/// 並びの順は「項目を追加」の一覧の順。保存データには rawValue を書くので、名前は変えない。
enum AppFeature: String, CaseIterable, Codable, Sendable {
    case settings
    case featureStatus
    case aiAssistant
    case notes
    case tasks
    case calculator
    case unitConverter
    case textTools
    case timer
    case weather

    var title: String {
        switch self {
        case .settings: return "設定"
        case .featureStatus: return "機能の状況"
        case .aiAssistant: return "AI"
        case .notes: return "メモ"
        case .tasks: return "タスク"
        case .calculator: return "電卓"
        case .unitConverter: return "単位変換"
        case .textTools: return "テキストツール"
        case .timer: return "タイマー"
        case .weather: return "天気"
        }
    }

    var state: FeatureState {
        switch self {
        case .settings, .featureStatus, .timer: return .available
        case .notes, .tasks, .calculator, .unitConverter, .textTools: return .available
        case .aiAssistant:
            // 端末内モデル（Apple Intelligence）が使える端末だけ本物の AI。使えなければスタブだけなので、そう示す
            return LLMRuntime.isSystemModelAvailable ? .available : .stub
        case .weather: return .planned(phase: 7)
        }
    }

    /// 開けない機能をタップした時に表示する説明。
    var unavailableDetail: String {
        switch self {
        case .weather:
            return "天気は Phase 7 で実装する予定です（Open-Meteo）。通信は、設定でオンにするまで行いません。"
        case .settings, .featureStatus, .aiAssistant, .notes, .tasks, .calculator, .unitConverter, .textTools, .timer:
            return "この機能は利用できます。"
        }
    }
}
