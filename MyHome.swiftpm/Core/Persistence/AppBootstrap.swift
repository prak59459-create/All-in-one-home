import Foundation

/// 起動時に、保存データを読んでストアと保存の仕組みを用意する。
/// AI・天気・画像処理などの重いものはここでは作らない（PLAN.md「ローカル LLM の方針」）。
@MainActor
struct AppBootstrap {
    let home: HomeStore
    let settings: SettingsStore
    let persistence: PersistenceController
    /// 起動直後に表示する説明（保存データを読めなかった時など）。
    let startupNotice: String?

    static func make(options: LaunchOptions) -> AppBootstrap {
        if let sample = options.sampleLayout() {
            // 検証用の配置で利用者の保存データを上書きしない
            let reason: String = "検証用の起動引数（\(LaunchOptions.sampleItemsFlag)）で起動したため、変更は保存しません。"
            let saved = SavedHome(layout: sample, settings: .defaults)
            return assemble(saved: saved, storage: nil, disabledReason: reason, notice: nil)
        }
        do {
            let storage: FileHomeArchiveStorage = try FileHomeArchiveStorage.standard()
            return make(storage: storage)
        } catch {
            let reason: String = "保存先のフォルダを用意できなかったため、変更は保存されません。"
            return assemble(saved: .initial(), storage: nil, disabledReason: reason, notice: reason)
        }
    }

    /// 保存先を指定して用意する（テストでも使う）。
    static func make(storage: any HomeArchiveStorage, delay: Duration = .milliseconds(500)) -> AppBootstrap {
        let outcome: LoadOutcome = HomeArchiveLoader.load(from: storage)
        let usable: (any HomeArchiveStorage)? = outcome.canSave ? storage : nil
        let reason: String = "読めなかった保存ファイルを上書きしないよう、この起動中は変更を保存しません。"
        return assemble(saved: outcome.saved, storage: usable, disabledReason: reason, notice: outcome.notice, delay: delay)
    }

    private static func assemble(
        saved: SavedHome,
        storage: (any HomeArchiveStorage)?,
        disabledReason: String,
        notice: String?,
        delay: Duration = .milliseconds(500)
    ) -> AppBootstrap {
        let home = HomeStore(layout: saved.layout)
        let settings = SettingsStore(saved: saved.settings)
        let persistence = PersistenceController(storage: storage, disabledReason: disabledReason, delay: delay)
        persistence.attach(home: home, settings: settings)
        return AppBootstrap(home: home, settings: settings, persistence: persistence, startupNotice: notice)
    }
}
