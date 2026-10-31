import Foundation

/// 書き込みの選択。
struct UpdateSelection: Hashable, Sendable {
    /// Package.swift の変更も書き込む。
    var includeManifest: Bool
    /// 手元で変更されたファイルも上書きする（退避はする）。
    var overwriteLocalEdits: Bool
}

/// 書き込みの結果。
struct InstallResult: Hashable, Sendable {
    let commitSHA: String
    let branch: String
    let written: [String]
    let deleted: [String]
    let skipped: [String]
    let backupID: String
    /// 次に比べる時のための「更新で入れたファイル → ハッシュ」。
    let installed: [String: String]
}

/// 退避の記録（UpdateBackups/<id>/backup.json）。
struct UpdateBackup: Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        /// 更新で新しく作った（元に戻す時は消す）。
        case added
        /// 更新で上書きした（元に戻す時は退避した中身を書き戻す）。
        case modified
        /// 更新で消した（元に戻す時は退避した中身を書き戻す）。
        case deleted
    }

    struct Entry: Codable, Hashable, Sendable {
        let path: String
        let kind: Kind
    }

    let id: String
    /// この更新で書き込んだコミット。
    let commitSHA: String
    let createdAt: Date
    let entries: [Entry]
    /// 更新の前の記録（元に戻した時に、記録もこの値に戻す）。
    let previousCommit: String?
    let previousBranch: String?
    let previousInstalled: [String: String]?
}

/// 書き込みと元に戻す処理。書き込む前に、上書き・削除するファイルを退避し、途中で失敗したらその場で元に戻す。
enum UpdateInstaller {
    /// 更新の前の記録（退避の記録に残し、元に戻す時に使う）。
    struct Previous: Hashable, Sendable {
        let commit: String?
        let branch: String?
        let installed: [String: String]?
    }

    static func install(
        plan: UpdatePlan,
        selection: UpdateSelection,
        contents: [String: Data],
        package: PackageFileSystem,
        backups: PackageFileSystem,
        backupID: String,
        previous: Previous
    ) throws -> InstallResult {
        let targets: Targets = targets(for: plan, selection: selection)
        for file in targets.writes where contents[file.path] == nil {
            throw UpdateError.integrity(file.path)
        }
        let entries: [UpdateBackup.Entry] = try backUp(targets, package: package, backups: backups)
        try saveBackupRecord(entries, id: backupID, commit: plan.snapshot.commitSHA, previous: previous, backups: backups)
        var done: [UpdateBackup.Entry] = []
        do {
            for file in targets.writes {
                let entry: UpdateBackup.Entry = try entry(for: file.path, in: entries)
                try write(contents[file.path] ?? Data(), to: file.path, package: package)
                done.append(entry)
            }
            for path in targets.deletions {
                let entry: UpdateBackup.Entry = try entry(for: path, in: entries)
                try package.delete(path)
                done.append(entry)
            }
            let stamp: Data = Data(BuildStampWriter.source(commit: plan.snapshot.commitSHA, branch: plan.snapshot.branch).utf8)
            let stampEntry: UpdateBackup.Entry = try entry(for: BuildStampWriter.path, in: entries)
            try write(stamp, to: BuildStampWriter.path, package: package)
            done.append(stampEntry)
        } catch {
            restore(done.reversed(), package: package, backups: backups)
            throw failure(error)
        }
        return InstallResult(
            commitSHA: plan.snapshot.commitSHA,
            branch: plan.snapshot.branch,
            written: targets.writes.map(\.path),
            deleted: targets.deletions,
            skipped: targets.skipped,
            backupID: backupID,
            installed: installedHashes(plan: plan, targets: targets, previous: previous.installed)
        )
    }

    /// 更新の前の状態に戻す（backups はその更新の退避先）。戻した記録を返す。
    static func rollback(package: PackageFileSystem, backups: PackageFileSystem) throws -> UpdateBackup {
        let backup: UpdateBackup = try loadBackup(backups: backups)
        restore(backup.entries.reversed(), package: package, backups: backups)
        return backup
    }

    static func loadBackup(backups: PackageFileSystem) throws -> UpdateBackup {
        guard let data = try? backups.read("backup.json") else { throw UpdateError.noBackup }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let backup = try? decoder.decode(UpdateBackup.self, from: data) else { throw UpdateError.noBackup }
        return backup
    }

    // MARK: - 内部

    struct Targets {
        var writes: [RemoteFile]
        var deletions: [String]
        var skipped: [String]
    }

    private static func targets(for plan: UpdatePlan, selection: UpdateSelection) -> Targets {
        var writes: [RemoteFile] = plan.additions
        var skipped: [String] = []
        for file in plan.modifications {
            if plan.locallyEdited.contains(file.path) && !selection.overwriteLocalEdits {
                skipped.append(file.path)
            } else {
                writes.append(file)
            }
        }
        if let manifest = plan.manifestChange {
            if selection.includeManifest {
                writes.append(manifest)
            } else {
                skipped.append(manifest.path)
            }
        }
        return Targets(writes: writes, deletions: plan.deletions, skipped: skipped)
    }

    /// 上書き・削除する前の中身を退避する。退避できなければ何も書き込まずに止める。
    /// backups は、この更新の退避先（UpdateBackups/<id>）をルートにしたもの。
    private static func backUp(_ targets: Targets, package: PackageFileSystem, backups: PackageFileSystem) throws -> [UpdateBackup.Entry] {
        var entries: [UpdateBackup.Entry] = []
        let paths: [String] = targets.writes.map(\.path) + [BuildStampWriter.path]
        for path in paths where !entries.contains(where: { (entry: UpdateBackup.Entry) -> Bool in entry.path == path }) {
            if package.exists(path) {
                try backups.write(try package.read(path), to: "files/\(path)")
                entries.append(UpdateBackup.Entry(path: path, kind: .modified))
            } else {
                entries.append(UpdateBackup.Entry(path: path, kind: .added))
            }
        }
        for path in targets.deletions {
            try backups.write(try package.read(path), to: "files/\(path)")
            entries.append(UpdateBackup.Entry(path: path, kind: .deleted))
        }
        return entries
    }

    private static func saveBackupRecord(
        _ entries: [UpdateBackup.Entry],
        id: String,
        commit: String,
        previous: Previous,
        backups: PackageFileSystem
    ) throws {
        let backup = UpdateBackup(
            id: id, commitSHA: commit, createdAt: Date(), entries: entries,
            previousCommit: previous.commit, previousBranch: previous.branch, previousInstalled: previous.installed
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try backups.write(try encoder.encode(backup), to: "backup.json")
    }

    private static func entry(for path: String, in entries: [UpdateBackup.Entry]) throws -> UpdateBackup.Entry {
        guard let entry = entries.first(where: { (entry: UpdateBackup.Entry) -> Bool in entry.path == path }) else {
            throw UpdateError.writeFailed(path: path, reason: "退避の記録がありません")
        }
        return entry
    }

    private static func write(_ data: Data, to path: String, package: PackageFileSystem) throws {
        do {
            try package.write(data, to: path)
        } catch {
            throw UpdateError.writeFailed(path: path, reason: error.localizedDescription)
        }
    }

    /// 退避した中身で元に戻す（戻せなかったファイルがあっても、残りは続けて戻す）。
    private static func restore<S: Sequence>(_ entries: S, package: PackageFileSystem, backups: PackageFileSystem)
        where S.Element == UpdateBackup.Entry {
        for entry in entries {
            switch entry.kind {
            case .added:
                try? package.delete(entry.path)
            case .modified, .deleted:
                if let data = try? backups.read("files/\(entry.path)") {
                    try? package.write(data, to: entry.path)
                }
            }
        }
    }

    private static func failure(_ error: Error) -> UpdateError {
        (error as? UpdateError) ?? UpdateError.writeFailed(path: "?", reason: error.localizedDescription)
    }

    /// 書き込み後に「更新で入れたもの」として覚えるハッシュ。書き込まなかったファイルは前回の値のままにする
    /// （次も「手元で変更あり」と分かるように）。
    private static func installedHashes(plan: UpdatePlan, targets: Targets, previous: [String: String]?) -> [String: String] {
        var result: [String: String] = previous ?? [:]
        let skipped: Set<String> = Set(targets.skipped)
        for file in plan.snapshot.files where file.path != BuildStampWriter.path && !skipped.contains(file.path) {
            result[file.path] = file.blobSHA
        }
        for path in targets.deletions {
            result[path] = nil
        }
        return result
    }
}
