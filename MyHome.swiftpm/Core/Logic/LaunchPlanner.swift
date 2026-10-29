/// 項目をタップした時に何をするか。
enum LaunchPlan: Hashable, Sendable {
    /// 確認してから外部の URL を開く。
    case confirmURL(CheckedURL)
    /// URL に問題があるので開かず、理由を表示する。
    case rejectURL(URLRejection)
    /// アプリ内の機能を開く。
    case openFeature(AppFeature)
    /// 未実装・OS 制限などで開けない理由を表示する。
    case explainUnavailable(AppFeature)
    /// フォルダを開く。
    case openFolder
}

/// タップ時の動作を決める。画面表示から切り離して単体テストする。
enum LaunchPlanner {
    static func plan(for action: HomeItemAction) -> LaunchPlan {
        switch action {
        case .openURL(let raw):
            return plan(forURL: raw)
        case .feature(let feature):
            return feature.state.canOpen ? .openFeature(feature) : .explainUnavailable(feature)
        case .folder:
            return .openFolder
        }
    }

    private static func plan(forURL raw: String) -> LaunchPlan {
        switch URLPolicy.check(raw) {
        case .allowed(let checked):
            return .confirmURL(checked)
        case .rejected(let reason):
            return .rejectURL(reason)
        }
    }
}
