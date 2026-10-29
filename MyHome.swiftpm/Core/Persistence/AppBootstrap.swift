import Foundation

/// 起動時に、保存データを読んでストアと保存の仕組みを用意する。
/// AI・天気・画像処理などの重いものはここでは作らない（PLAN.md「ローカル LLM の方針」）。
@MainActor
struct AppBootstrap {
    let home: HomeStore
    let settings: SettingsStore
    let timers: TimerStore
    let persistence: PersistenceController
    /// 画像（壁紙・アイコン）の保存先。保存しない起動（検証用など）では nil。
    let images: ImageFileStore?
    /// 起動直後に表示する説明（保存データを読めなかった時など）。
    let startupNotice: String?

    static func make(options: LaunchOptions) -> AppBootstrap {
        if let sample = options.sampleLayout() {
            // 検証用の配置で利用者の保存データを上書きしない
            let reason: String = "検証用の起動引数（\(LaunchOptions.sampleItemsFlag)）で起動したため、変更は保存しません。"
            let saved = SavedHome(layout: sample, settings: .defaults)
            return assemble(saved: saved, storage: nil, images: nil, disabledReason: reason, notice: nil)
        }
        do {
            let storage: FileHomeArchiveStorage = try FileHomeArchiveStorage.standard()
            let images = ImageFileStore(directory: storage.directory.appendingPathComponent("Images", isDirectory: true))
            return make(storage: storage, images: images)
        } catch {
            let reason: String = "保存先のフォルダを用意できなかったため、変更は保存されません。"
            return assemble(saved: .initial(), storage: nil, images: nil, disabledReason: reason, notice: reason)
        }
    }

    /// 保存先を指定して用意する（テストでも使う）。
    static func make(
        storage: any HomeArchiveStorage,
        images: ImageFileStore? = nil,
        delay: Duration = .milliseconds(500)
    ) -> AppBootstrap {
        let outcome: LoadOutcome = HomeArchiveLoader.load(from: storage)
        let usable: (any HomeArchiveStorage)? = outcome.canSave ? storage : nil
        // 読み込めた時だけ、どこからも参照されていない画像を消す（読めなかった時は、退避したファイルが参照しているかもしれない）
        if outcome.notice == nil {
            images?.removeUnreferenced(keeping: outcome.saved.referencedImageNames)
        }
        let reason: String = "読めなかった保存ファイルを上書きしないよう、この起動中は変更を保存しません。"
        return assemble(saved: outcome.saved, storage: usable, images: images, disabledReason: reason, notice: outcome.notice, delay: delay)
    }

    private static func assemble(
        saved: SavedHome,
        storage: (any HomeArchiveStorage)?,
        images: ImageFileStore?,
        disabledReason: String,
        notice: String?,
        delay: Duration = .milliseconds(500)
    ) -> AppBootstrap {
        let home = HomeStore(layout: saved.layout)
        let settings = SettingsStore(saved: saved.settings)
        let timers = TimerStore(board: saved.timers)
        let persistence = PersistenceController(storage: storage, disabledReason: disabledReason, delay: delay)
        persistence.attach(home: home, settings: settings, timers: timers)
        return AppBootstrap(
            home: home,
            settings: settings,
            timers: timers,
            persistence: persistence,
            images: storage == nil ? nil : images,
            startupNotice: notice
        )
    }
}
