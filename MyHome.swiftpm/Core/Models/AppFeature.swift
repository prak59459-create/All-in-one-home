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
        case .notes, .tasks, .calculator, .unitConverter, .textTools, .weather: return .available
        case .aiAssistant:
            // 端末内モデル（Apple Intelligence）が使える端末だけ本物の AI。使えなければスタブだけなので、そう示す
            return LLMRuntime.isSystemModelAvailable ? .available : .stub
        }
    }

    /// 開けない機能をタップした時に表示する説明。今は開けない機能はないが、準備中や OS の制限で開けない機能を足した時に使う。
    var unavailableDetail: String {
        switch state {
        case .available, .stub:
            return "この機能は利用できます。"
        case .planned(let phase):
            return "Phase \(phase) で実装する予定です。"
        case .needsPoC:
            return "実現できるかを小さな試作（PoC）で確かめてから判断します。"
        case .osLimited:
            return "iPadOS の制限で、一般のアプリには作れません。"
        }
    }
}
