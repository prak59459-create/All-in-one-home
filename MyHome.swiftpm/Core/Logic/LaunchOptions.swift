import Foundation

/// 起動引数による検証用の設定。Simulator や Xcode から起動した時だけ使う（Swift Playgrounds では指定できない）。
/// 例: `-MyHomeSampleItems 150 -MyHomeSampleItemsPerPage 150`
struct LaunchOptions: Hashable, Sendable {
    static let sampleItemsFlag: String = "-MyHomeSampleItems"
    static let sampleItemsPerPageFlag: String = "-MyHomeSampleItemsPerPage"
    static let defaultItemsPerPage: Int = 60

    var sampleItemCount: Int?
    var sampleItemsPerPage: Int

    init(arguments: [String]) {
        sampleItemCount = LaunchOptions.intValue(after: LaunchOptions.sampleItemsFlag, in: arguments)
        let perPage: Int? = LaunchOptions.intValue(after: LaunchOptions.sampleItemsPerPageFlag, in: arguments)
        sampleItemsPerPage = perPage ?? LaunchOptions.defaultItemsPerPage
    }

    static func current() -> LaunchOptions {
        LaunchOptions(arguments: ProcessInfo.processInfo.arguments)
    }

    /// 起動時に表示するレイアウト。検証用の指定がなければ初期レイアウト。
    func initialLayout() -> HomeLayout {
        guard let count = sampleItemCount else {
            return DefaultLayout.make()
        }
        return SampleLayout.stress(itemCount: count, itemsPerPage: sampleItemsPerPage)
    }

    private static func intValue(after flag: String, in arguments: [String]) -> Int? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else {
            return nil
        }
        return Int(arguments[index + 1])
    }
}
