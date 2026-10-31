/// 機能の実装状態。アプリ内でも同じ表記で示し、未実装の機能を実装済みに見せない。
enum FeatureState: Hashable, Sendable {
    case available
    case stub
    case planned(phase: Int)
    /// 実現できるかが未確認で、小さな PoC で検証してから判断するもの。
    case needsPoC
    /// 一般のアプリには OS が許可していないもの。
    case osLimited

    var label: String {
        switch self {
        case .available: return "利用可能"
        case .stub: return "スタブ"
        case .planned(let phase): return "準備中（Phase \(phase)）"
        case .needsPoC: return "要調査（PoC）"
        case .osLimited: return "OS の制限で不可"
        }
    }

    /// 画面を開ける状態か（スタブは「スタブ」と明示した上で開ける）。
    var canOpen: Bool {
        switch self {
        case .available, .stub: return true
        case .planned, .needsPoC, .osLimited: return false
        }
    }
}
