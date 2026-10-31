import Foundation

/// この iPad の中に残したバックアップ 1 つ（Application Support/MyHome/Backups の中のファイル）。
struct LocalBackup: Identifiable, Hashable, Sendable {
    enum Kind: String, CaseIterable, Sendable {
        /// 利用者が「この iPad に保存」で作ったもの。
        case manual
        /// 復元の前に自動で作ったもの（F0830）。
        case beforeRestore = "before-restore"
        /// すべてのデータを消す前に自動で作ったもの。
        case beforeErase = "before-erase"

        var title: String {
            switch self {
            case .manual: return "手動で保存"
            case .beforeRestore: return "復元の前"
            case .beforeErase: return "消去の前"
            }
        }

        var isAutomatic: Bool {
            self != .manual
        }
    }

    let fileName: String
    let kind: Kind
    let createdAt: Date
    let byteCount: Int

    var id: String {
        fileName
    }
}

/// 端末内のバックアップの一覧・保存・読み込み・削除（F0830–F0832）。
/// ファイル名は myhome-<種類>-<日時>.json（例: myhome-before-restore-20261030-101500.json。日時は端末の時刻）。
struct LocalBackupStore: Sendable {
    /// 自動で作るバックアップを残す数。超えたら古いものから消す。
    static let maximumAutomatic: Int = 5
    /// 手動で作れるバックアップの数。超える時は、古いものを消してもらう。
    static let maximumManual: Int = 10
    private static let prefix: String = "myhome-"
    private static let suffix: String = ".json"
    private static let stampLength: Int = 15

    let directory: URL
    var timeZone: TimeZone = .current

    /// 新しいものから順に返す。名前の形が違うファイルは無視する。
    func list() -> [LocalBackup] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return [] }
        let backups: [LocalBackup] = names.compactMap { (name: String) -> LocalBackup? in backup(named: name) }
        return backups.sorted { (lhs: LocalBackup, rhs: LocalBackup) -> Bool in
            lhs.createdAt != rhs.createdAt ? lhs.createdAt > rhs.createdAt : lhs.fileName > rhs.fileName
        }
    }

    /// 保存する。自動のものは、上限を超えた古いものを消す。手動のものは上限に達していれば保存しない。
    @discardableResult
    func save(_ data: Data, kind: LocalBackup.Kind, createdAt: Date) throws -> LocalBackup {
        let existing: [LocalBackup] = list()
        if kind == .manual {
            let manual: Int = existing.filter { (backup: LocalBackup) -> Bool in backup.kind == .manual }.count
            guard manual < LocalBackupStore.maximumManual else {
                throw BackupError.unavailable("この iPad に保存できるバックアップは \(LocalBackupStore.maximumManual) 個までです。古いものを削除してから保存してください。")
            }
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name: String = unusedName(kind: kind, createdAt: createdAt)
        try data.write(to: directory.appendingPathComponent(name, isDirectory: false), options: .atomic)
        if kind.isAutomatic {
            pruneAutomatic(keeping: name)
        }
        return LocalBackup(fileName: name, kind: kind, createdAt: createdAt, byteCount: data.count)
    }

    func read(_ backup: LocalBackup) throws -> Data {
        let url: URL = try fileURL(backup.fileName)
        let handle: FileHandle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data: Data = try handle.read(upToCount: BackupArchive.maximumByteCount + 1) ?? Data()
        guard data.count <= BackupArchive.maximumByteCount else {
            throw BackupError.tooLarge(byteCount: data.count)
        }
        return data
    }

    func delete(_ backup: LocalBackup) throws {
        let url: URL = try fileURL(backup.fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    func deleteAll() throws {
        for backup in list() {
            try delete(backup)
        }
    }

    /// 自動のバックアップを新しい順に maximumAutomatic 個だけ残す（今作ったものは必ず残す）。
    private func pruneAutomatic(keeping name: String) {
        let automatic: [LocalBackup] = list().filter { (backup: LocalBackup) -> Bool in backup.kind.isAutomatic }
        for backup in automatic.dropFirst(LocalBackupStore.maximumAutomatic) where backup.fileName != name {
            try? delete(backup)
        }
    }

    private func fileURL(_ name: String) throws -> URL {
        guard backup(named: name) != nil else {
            throw BackupError.unavailable("バックアップのファイル名が正しくありません（\(name)）。")
        }
        return directory.appendingPathComponent(name, isDirectory: false)
    }

    private func unusedName(kind: LocalBackup.Kind, createdAt: Date) -> String {
        let base: String = LocalBackupStore.prefix + kind.rawValue + "-" + formatter().string(from: createdAt)
        var name: String = base + LocalBackupStore.suffix
        var counter: Int = 2
        while FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path) {
            name = "\(base)-\(counter)" + LocalBackupStore.suffix
            counter += 1
        }
        return name
    }

    /// ファイル名から種類と日時を読む。形が違えば nil。
    func backup(named name: String) -> LocalBackup? {
        guard name.hasPrefix(LocalBackupStore.prefix), name.hasSuffix(LocalBackupStore.suffix), !name.contains("/") else { return nil }
        let body: String = String(name.dropFirst(LocalBackupStore.prefix.count).dropLast(LocalBackupStore.suffix.count))
        guard let kind = LocalBackup.Kind.allCases.first(where: { (kind: LocalBackup.Kind) -> Bool in body.hasPrefix(kind.rawValue + "-") }) else {
            return nil
        }
        let rest: Substring = body.dropFirst(kind.rawValue.count + 1)
        guard rest.count >= LocalBackupStore.stampLength,
              let date = formatter().date(from: String(rest.prefix(LocalBackupStore.stampLength))) else {
            return nil
        }
        let url: URL = directory.appendingPathComponent(name, isDirectory: false)
        return LocalBackup(fileName: name, kind: kind, createdAt: date, byteCount: LocalBackupStore.fileSize(url))
    }

    private static func fileSize(_ url: URL) -> Int {
        let attributes: [FileAttributeKey: Any]? = try? FileManager.default.attributesOfItem(atPath: url.path)
        let value: Any? = attributes?[.size]
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let unsigned = value as? UInt64 {
            return Int(clamping: unsigned)
        }
        return (value as? Int) ?? 0
    }

    private func formatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }
}
