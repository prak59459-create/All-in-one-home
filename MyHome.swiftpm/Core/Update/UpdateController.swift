import Foundation
import Observation

/// ソフトウェアアップデートの手順（ブランチの取得 → 差分の確認 → 取得と書き込み → 元に戻す）。
/// ファイルの読み書きは時間がかかることがある（iCloud Drive のファイルの取得待ちなど）ので、メインスレッドの外で行う。
/// 書き込み先のフォルダは、どの段階でも PackageVerifier で確かめ直してから使う。
@MainActor
@Observable
final class UpdateController {
    enum Phase: Hashable, Sendable {
        case idle
        case working(String)
        case planned
        case installed(InstallResult)
        case rolledBack(String)
        case failed(String)
    }

    struct Progress: Hashable, Sendable {
        let done: Int
        let total: Int
    }

    /// 残しておく退避の数（古いものから消す）。
    static let keptBackups: Int = 3

    private(set) var state: UpdateState
    private(set) var branches: [RemoteBranch] = []
    var selectedBranchName: String?
    private(set) var plan: UpdatePlan?
    /// 確認したコミットの CI の結果。
    private(set) var checkStatus: CommitCheckStatus?
    /// CI が成功していないコミットでも書き込むことを、利用者が選んだ。
    var allowsUnverifiedCommit: Bool = false
    private(set) var phase: Phase = .idle
    private(set) var progress: Progress?
    var selection = UpdateSelection(includeManifest: false, overwriteLocalEdits: false)

    @ObservationIgnored private let client: GitHubUpdateClient
    @ObservationIgnored private let stateStore: UpdateStateStore
    @ObservationIgnored private let backups: DirectoryFileSystem
    @ObservationIgnored private let runningCommit: String

    init(client: GitHubUpdateClient, stateStore: UpdateStateStore, backups: DirectoryFileSystem, runningCommit: String = BuildStamp.commit) {
        self.client = client
        self.stateStore = stateStore
        self.backups = backups
        self.runningCommit = runningCommit
        self.state = stateStore.load()
    }

    var buildStatus: BuildStatus {
        BuildStatus.evaluate(runningCommit: runningCommit, state: state)
    }

    var isWorking: Bool {
        if case .working = phase {
            return true
        }
        return false
    }

    var selectedBranch: RemoteBranch? {
        branches.first { (branch: RemoteBranch) -> Bool in branch.name == selectedBranchName }
    }

    /// 書き込み先を覚える（選んだ時に PackageVerifier で確かめた後に呼ぶ）。
    func rememberPackage(bookmark: Data, location: String) {
        state.packageBookmark = bookmark
        state.packageLocation = location
        saveState()
    }

    func loadBranches() async {
        phase = .working("ブランチを読み込んでいます…")
        do {
            branches = try await client.branches()
            if selectedBranch == nil {
                selectedBranchName = defaultBranchName()
            }
            phase = .idle
        } catch {
            phase = .failed(UpdateController.message(for: error))
        }
    }

    /// 選んだブランチと手元のパッケージを比べる。
    func check(package: PackageFileSystem, folderName: String) async {
        guard let branch = selectedBranch else { return }
        plan = nil
        phase = .working("違うファイルを調べています…")
        do {
            try await UpdateController.offMain { try PackageVerifier.verify(folderName: folderName, package: package) }
            let snapshot: RemoteSnapshot = try await client.snapshot(of: branch)
            checkStatus = (try? await client.checkStatus(commit: snapshot.commitSHA)) ?? .unknown
            let local: [String: String] = try await UpdateController.offMain { try UpdateController.localHashes(of: package) }
            let planned: UpdatePlan = UpdatePlanner.plan(snapshot: snapshot, local: local, installed: state.installedFiles)
            selection = UpdateSelection(includeManifest: defaultIncludesManifest(planned), overwriteLocalEdits: false)
            allowsUnverifiedCommit = false
            plan = planned
            phase = .planned
        } catch {
            phase = .failed(UpdateController.message(for: error))
        }
    }

    /// CI が成功したコミットか、利用者が承知した時だけ書き込める。
    var canInstall: Bool {
        guard let plan, !plan.isUpToDate, !isWorking else { return false }
        return checkStatus == .passed || allowsUnverifiedCommit
    }

    /// 全部を取得してハッシュを確かめてから、退避して書き込む。
    func install(package: PackageFileSystem, folderName: String) async {
        guard let plan, canInstall else { return }
        phase = .working("ファイルを取得しています…")
        do {
            try await UpdateController.offMain { try PackageVerifier.verify(folderName: folderName, package: package) }
            let contents: [String: Data] = try await download(plan)
            phase = .working("書き込んでいます…")
            let backupID: String = UpdateController.newBackupID()
            let previous = UpdateInstaller.Previous(commit: state.installedCommit, branch: state.branch, installed: state.installedFiles)
            let selection: UpdateSelection = self.selection
            let backupRoot: DirectoryFileSystem = backups.subdirectory(backupID)
            let result: InstallResult = try await UpdateController.offMain {
                try UpdateInstaller.install(
                    plan: plan, selection: selection, contents: contents, package: package,
                    backups: backupRoot, backupID: backupID, previous: previous
                )
            }
            record(result)
            pruneBackups()
            self.plan = nil
            phase = .installed(result)
        } catch {
            phase = .failed(UpdateController.message(for: error))
        }
        progress = nil
    }

    /// 最後の更新の前の状態に戻す。
    func rollback(package: PackageFileSystem, folderName: String) async {
        guard let backupID = state.lastBackupID else {
            phase = .failed(UpdateError.noBackup.message)
            return
        }
        phase = .working("元に戻しています…")
        let backupRoot: DirectoryFileSystem = backups.subdirectory(backupID)
        do {
            try await UpdateController.offMain { try PackageVerifier.verify(folderName: folderName, package: package) }
            let backup: UpdateBackup = try await UpdateController.offMain {
                try UpdateInstaller.rollback(package: package, backups: backupRoot)
            }
            state.installedCommit = backup.previousCommit
            state.branch = backup.previousBranch
            state.installedFiles = backup.previousInstalled
            state.installedAt = Date()
            state.lastBackupID = nil
            saveState()
            try? FileManager.default.removeItem(at: backupRoot.root)
            phase = .rolledBack("\(backup.entries.count) 個のファイルを更新の前の状態に戻しました。")
        } catch {
            phase = .failed(UpdateController.message(for: error))
        }
    }

    // MARK: - 内部

    private func download(_ plan: UpdatePlan) async throws -> [String: Data] {
        var files: [RemoteFile] = plan.additions + plan.modifications
        if selection.includeManifest, let manifest = plan.manifestChange {
            files.append(manifest)
        }
        if !selection.overwriteLocalEdits {
            files.removeAll { (file: RemoteFile) -> Bool in plan.locallyEdited.contains(file.path) }
        }
        var contents: [String: Data] = [:]
        for (index, file) in files.enumerated() {
            progress = Progress(done: index, total: files.count)
            contents[file.path] = try await client.download(file, commit: plan.snapshot.commitSHA)
        }
        progress = Progress(done: files.count, total: files.count)
        return contents
    }

    private func record(_ result: InstallResult) {
        state.installedCommit = result.commitSHA
        state.branch = result.branch
        state.installedAt = Date()
        state.installedFiles = result.installed
        state.lastBackupID = result.backupID
        saveState()
    }

    private func saveState() {
        try? stateStore.save(state)
    }

    private func defaultBranchName() -> String? {
        let preferred: [String] = [state.branch, BuildStamp.branch.isEmpty ? nil : BuildStamp.branch, "main"].compactMap { $0 }
        for name in preferred where branches.contains(where: { (branch: RemoteBranch) -> Bool in branch.name == name }) {
            return name
        }
        return branches.first?.name
    }

    /// Package.swift は、前回の更新で入れたものから手元で変わっていない時だけ、最初から「書き込む」にする。
    private func defaultIncludesManifest(_ plan: UpdatePlan) -> Bool {
        plan.manifestChange != nil && !plan.manifestLocallyEdited && state.installedFiles != nil
    }

    private func pruneBackups() {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: backups.root.path) else { return }
        let sorted: [String] = names.filter { (name: String) -> Bool in name.hasPrefix("update-") }.sorted()
        for name in sorted.dropLast(UpdateController.keptBackups) {
            try? FileManager.default.removeItem(at: backups.root.appendingPathComponent(name, isDirectory: true))
        }
    }

    nonisolated static func localHashes(of package: PackageFileSystem) throws -> [String: String] {
        var hashes: [String: String] = [:]
        for path in try package.listFiles() {
            hashes[path] = SHA1.gitBlobHash(try package.read(path))
        }
        return hashes
    }

    nonisolated static func newBackupID() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "update-\(formatter.string(from: Date()))-\(UUID().uuidString.prefix(8).lowercased())"
    }

    nonisolated static func message(for error: Error) -> String {
        (error as? UpdateError)?.message ?? "更新できませんでした（\(error.localizedDescription)）。"
    }

    /// ファイルの読み書きをメインスレッドの外で行う。
    nonisolated static func offMain<Value: Sendable>(_ work: @escaping @Sendable () throws -> Value) async throws -> Value {
        try await Task.detached(priority: .userInitiated) {
            try work()
        }.value
    }
}
