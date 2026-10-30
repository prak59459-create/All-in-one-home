import Foundation

/// 起動引数による検証用の設定。Simulator や Xcode から起動した時だけ使う（Swift Playgrounds では指定できない）。
/// 例: `-MyHomeSampleItems 150 -MyHomeSampleItemsPerPage 150`、`-MyHomeStartEditing`、`-MyHomeOpenFolder <項目 ID>`、
/// `-MyHomeOpenFeature <機能の rawValue>`（例: calculator）、`-MyHomeSettingsPage <設定のページ>`（例: backup）。
/// 操作を自動で行えない Simulator の起動テストで、編集中・フォルダ・ミニアプリを開いた画面のスクリーンショットを撮るために使う。
struct LaunchOptions: Hashable, Sendable {
    static let sampleItemsFlag: String = "-MyHomeSampleItems"
    static let sampleItemsPerPageFlag: String = "-MyHomeSampleItemsPerPage"
    static let startEditingFlag: String = "-MyHomeStartEditing"
    static let openFolderFlag: String = "-MyHomeOpenFolder"
    static let openFeatureFlag: String = "-MyHomeOpenFeature"
    static let settingsPageFlag: String = "-MyHomeSettingsPage"
    static let defaultItemsPerPage: Int = 60

    var sampleItemCount: Int?
    var sampleItemsPerPage: Int
    var startsEditing: Bool
    var openFolderID: String?
    /// 起動時に開く機能。開けない機能（準備中など）や知らない名前は無視する。
    var openFeature: AppFeature?
    /// 起動時に開く設定の中のページ（設定も開く）。知らない名前は無視する。
    var settingsPage: SettingsPage?

    init(arguments: [String]) {
        sampleItemCount = LaunchOptions.intValue(after: LaunchOptions.sampleItemsFlag, in: arguments)
        let perPage: Int? = LaunchOptions.intValue(after: LaunchOptions.sampleItemsPerPageFlag, in: arguments)
        sampleItemsPerPage = perPage ?? LaunchOptions.defaultItemsPerPage
        startsEditing = arguments.contains(LaunchOptions.startEditingFlag)
        openFolderID = LaunchOptions.value(after: LaunchOptions.openFolderFlag, in: arguments)
        let feature: AppFeature? = LaunchOptions.value(after: LaunchOptions.openFeatureFlag, in: arguments).flatMap(AppFeature.init(rawValue:))
        openFeature = feature?.state.canOpen == true ? feature : nil
        settingsPage = LaunchOptions.value(after: LaunchOptions.settingsPageFlag, in: arguments).flatMap(SettingsPage.init(rawValue:))
    }

    static func current() -> LaunchOptions {
        LaunchOptions(arguments: ProcessInfo.processInfo.arguments)
    }

    /// 起動時に表示するレイアウト。検証用の指定がなければ初期レイアウト。
    func initialLayout() -> HomeLayout {
        sampleLayout() ?? DefaultLayout.make()
    }

    /// 検証用の配置。指定がなければ nil（保存データを読む）。
    func sampleLayout() -> HomeLayout? {
        guard let count = sampleItemCount else {
            return nil
        }
        return SampleLayout.stress(itemCount: count, itemsPerPage: sampleItemsPerPage)
    }

    /// 起動時の画面の状態（編集中・開くフォルダ・開く機能）を反映する。
    @MainActor
    func apply(to router: AppRouter) {
        if startsEditing {
            router.beginEditing()
        }
        if let openFolderID {
            router.openFolderID = openFolderID
        }
        if let openFeature {
            router.sheet = .feature(openFeature)
        }
        if let settingsPage {
            router.sheet = .feature(.settings)
            router.settingsPath = [settingsPage]
        }
    }

    private static func intValue(after flag: String, in arguments: [String]) -> Int? {
        value(after: flag, in: arguments).flatMap { (text: String) -> Int? in Int(text) }
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }
}
