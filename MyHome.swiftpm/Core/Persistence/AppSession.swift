import Foundation
import Observation

/// アプリのデータの状態一式（AppBootstrap）を持つ。バックアップの作成・復元・すべての消去もここで行う（Phase 9）。
/// 復元・消去の後は、保存先のファイルから読み直したものに入れ替える。画面は boot のストアを environment で受け取るので、
/// 入れ替えると、開いている設定の画面もホーム画面も、そのまま新しい状態を表示する（アプリの再起動はいらない）。
@MainActor
@Observable
final class AppSession {
    private(set) var boot: AppBootstrap
    /// 読み直した回数。
    private(set) var generation: Int = 0

    /// 読み直した後に呼ぶ（開いているフォルダや編集モードを閉じるなど）。
    @ObservationIgnored var onReload: (@MainActor () -> Void)?
    /// 作ったストアの準備（タイマーが終わった時の知らせなど）。最初と、読み直すたびに呼ぶ。
    @ObservationIgnored private let configure: @MainActor (AppBootstrap) -> Void
    @ObservationIgnored private let load: @MainActor (URL) -> AppBootstrap
    @ObservationIgnored private let clock: @Sendable () -> Date
    @ObservationIgnored private let appVersion: String

    init(
        boot: AppBootstrap,
        configure: @escaping @MainActor (AppBootstrap) -> Void = { (_: AppBootstrap) in },
        load: @escaping @MainActor (URL) -> AppBootstrap = { (directory: URL) -> AppBootstrap in AppBootstrap.make(directory: directory) },
        clock: @escaping @Sendable () -> Date = { Date() },
        appVersion: String = AppInfo.version
    ) {
        configure(boot)
        self.boot = boot
        self.configure = configure
        self.load = load
        self.clock = clock
        self.appVersion = appVersion
    }

    /// バックアップと復元ができない理由。できる時は nil。
    var unavailableReason: String? {
        guard boot.dataDirectory == nil else { return nil }
        if case .disabled(let reason) = boot.persistence.status, !reason.isEmpty {
            return reason
        }
        return "この起動では保存先を使えないため、バックアップと復元はできません。"
    }

    /// 端末内のバックアップ（Application Support/MyHome/Backups）。保存しない起動では nil。
    var localBackups: LocalBackupStore? {
        boot.dataDirectory.map { (directory: URL) -> LocalBackupStore in
            LocalBackupStore(directory: directory.appendingPathComponent("Backups", isDirectory: true))
        }
    }

    /// 保存待ちの変更をすぐ保存する（ホーム画面とミニアプリ）。
    func flush() async {
        await boot.persistence.flush()
        await boot.miniApps.flushAll()
    }

    /// 今のデータのバックアップを作る（F0812）。重い処理はメインスレッドの外で行う。
    func makeBackup() async throws -> BackupBuilder.Result {
        guard let directory = boot.dataDirectory else {
            throw BackupError.unavailable(unavailableReason ?? "")
        }
        await flush()
        let saved: SavedHome = boot.currentSaved
        let files = DirectoryFileSystem(root: directory)
        let createdAt: Date = clock()
        let version: String = appVersion
        return try await Task.detached(priority: .userInitiated) { () throws -> BackupBuilder.Result in
            try BackupBuilder.make(saved: saved, files: files, createdAt: createdAt, appVersion: version)
        }.value
    }

    /// 復元する（F0828–F0830）。先に今のデータを端末内のバックアップに残してから、parts のファイルを書き換えて読み直す。
    /// 戻り値は、復元の前に残したバックアップ。
    @discardableResult
    func restore(_ contents: BackupContents, parts: Set<BackupPart>) async throws -> LocalBackup {
        try await replaceData(kind: .beforeRestore) { (files: DirectoryFileSystem) throws -> [BackupFileChange] in
            try BackupRestorer.changes(for: contents, parts: parts, current: files)
        }
    }

    /// すべてのデータを消して、初めて起動した時の状態に戻す（F0839、F0868）。消す前のデータは端末内のバックアップに残す。
    @discardableResult
    func eraseAllData() async throws -> LocalBackup {
        try await replaceData(kind: .beforeErase) { (files: DirectoryFileSystem) throws -> [BackupFileChange] in
            try BackupRestorer.eraseChanges(in: files)
        }
    }

    /// 1. 保存待ちを保存して、今のストアの保存をやめる（書き換えた後に、古い内容で上書きしないため）
    /// 2. 今のデータを端末内のバックアップに残す（残せなければ何も変えない）
    /// 3. ファイルを書き換える（失敗したら元に戻す）
    /// 4. 成功しても失敗しても、保存先のファイルから読み直す
    private func replaceData(
        kind: LocalBackup.Kind,
        changes makeChanges: @escaping @Sendable (DirectoryFileSystem) throws -> [BackupFileChange]
    ) async throws -> LocalBackup {
        guard let directory = boot.dataDirectory, let store = localBackups else {
            throw BackupError.unavailable(unavailableReason ?? "")
        }
        await flush()
        let current: AppBootstrap = boot
        let reason: String = "データを書き換えています。"
        current.persistence.suspend(reason: reason)
        current.miniApps.suspendAll(reason: reason)
        defer {
            reload(from: directory)
        }
        let saved: SavedHome = current.currentSaved
        let createdAt: Date = clock()
        let version: String = appVersion
        let files = DirectoryFileSystem(root: directory)
        let outcome: Result<LocalBackup, BackupError> = await Task.detached(priority: .userInitiated) { () -> Result<LocalBackup, BackupError> in
            AppSession.replace(saved: saved, files: files, store: store, kind: kind, createdAt: createdAt, appVersion: version, makeChanges: makeChanges)
        }.value
        return try outcome.get()
    }

    nonisolated private static func replace(
        saved: SavedHome,
        files: DirectoryFileSystem,
        store: LocalBackupStore,
        kind: LocalBackup.Kind,
        createdAt: Date,
        appVersion: String,
        makeChanges: @Sendable (DirectoryFileSystem) throws -> [BackupFileChange]
    ) -> Result<LocalBackup, BackupError> {
        let safety: LocalBackup
        do {
            let backup: BackupBuilder.Result = try BackupBuilder.make(saved: saved, files: files, createdAt: createdAt, appVersion: appVersion)
            safety = try store.save(backup.data, kind: kind, createdAt: createdAt)
        } catch {
            return .failure(.couldNotSaveCurrent(BackupError.message(for: error)))
        }
        do {
            try BackupRestorer.apply(try makeChanges(files), to: files)
        } catch let error as BackupError {
            return .failure(error)
        } catch {
            return .failure(.writeFailed(BackupError.message(for: error), rolledBack: true))
        }
        return .success(safety)
    }

    /// 保存先のファイルから読み直して、ストアを入れ替える。
    func reload(from directory: URL) {
        let next: AppBootstrap = load(directory)
        configure(next)
        boot = next
        generation += 1
        onReload?()
    }
}
