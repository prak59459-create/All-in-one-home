/// 設定の中のページ。AppRouter.settingsPath で、どのページを開いているかを持つ
/// （起動テストで設定の中のページを直接開くため。LaunchOptions の -MyHomeSettingsPage）。
enum SettingsPage: String, CaseIterable, Hashable, Sendable {
    case help
    case update
    case backup
    case about

    var title: String {
        switch self {
        case .help: return "使い方と困った時"
        case .update: return "ソフトウェアアップデート"
        case .backup: return "バックアップと復元"
        case .about: return "このアプリについて"
        }
    }
}
