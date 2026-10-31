import Foundation
import Observation

/// 読み込んで確かめたバックアップ。復元するかを確認する画面に出す（F0819、F0820）。
struct PendingRestore: Identifiable, Hashable, Sendable {
    let id: UUID
    /// どこから読んだか（ファイル名、または端末内のバックアップの名前）。
    let source: String
    let contents: BackupContents
    let summary: BackupSummary

    init(source: String, contents: BackupContents) {
        id = UUID()
        self.source = source
        self.contents = contents
        summary = BackupSummary(contents)
    }
}

/// 書き出すバックアップ（ファイルに保存する画面に渡す）。
struct BackupExportFile: Identifiable, Hashable, Sendable {
    let id: UUID
    let data: Data
    let fileName: String

    init(data: Data, fileName: String) {
        id = UUID()
        self.data = data
        self.fileName = fileName
    }
}

/// 結果やエラーの知らせ。
struct BackupMessage: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let text: String

    init(title: String, text: String) {
        id = UUID()
        self.title = title
        self.text = text
    }
}

/// バックアップと復元の画面の状態（F0812–F0832、F0839）。処理は AppSession に任せ、ここでは進み具合と結果を持つ。
@MainActor
@Observable
final class BackupController {
    enum Activity: Hashable, Sendable {
        case idle
        case preparing
        case reading
        case restoring
        case erasing

        var title: String {
            switch self {
            case .idle: return ""
            case .preparing: return "バックアップを作っています…"
            case .reading: return "バックアップを確かめています…"
            case .restoring: return "復元しています…"
            case .erasing: return "データを消しています…"
            }
        }
    }

    private(set) var activity: Activity = .idle
    private(set) var backups: [LocalBackup] = []
    var pending: PendingRestore?
    var exportFile: BackupExportFile?
    var message: BackupMessage?

    @ObservationIgnored let session: AppSession

    init(session: AppSession) {
        self.session = session
    }

    var isBusy: Bool {
        activity != .idle
    }

    var unavailableReason: String? {
        session.unavailableReason
    }

    func refresh() {
        backups = session.localBackups?.list() ?? []
    }

    /// 書き出すファイルを作る（F0812、F0814）。作れたら exportFile に入る。
    func prepareExport() async {
        guard begin(.preparing) else { return }
        defer { finish() }
        do {
            let result: BackupBuilder.Result = try await session.makeBackup()
            exportFile = BackupExportFile(data: result.data, fileName: BackupFormat.fileName(for: result.createdAt))
            if !result.notes.isEmpty {
                message = BackupMessage(title: "バックアップについて", text: result.notes.joined(separator: "\n"))
            }
        } catch {
            message = BackupMessage(title: "バックアップを作れませんでした", text: BackupError.message(for: error))
        }
    }

    /// この iPad の中に保存する。
    func saveOnDevice() async {
        guard begin(.preparing) else { return }
        defer { finish() }
        do {
            guard let store = session.localBackups else {
                throw BackupError.unavailable(unavailableReason ?? "")
            }
            let result: BackupBuilder.Result = try await session.makeBackup()
            let saved: LocalBackup = try store.save(result.data, kind: .manual, createdAt: result.createdAt)
            let notes: String = result.notes.isEmpty ? "" : "\n" + result.notes.joined(separator: "\n")
            message = BackupMessage(title: "保存しました", text: "「\(BackupFormat.date(saved.createdAt))」のバックアップを、この iPad に保存しました。" + notes)
        } catch {
            message = BackupMessage(title: "保存できませんでした", text: BackupError.message(for: error))
        }
        refresh()
    }

    /// 端末内のバックアップを書き出す。
    func export(_ backup: LocalBackup) async {
        guard begin(.preparing) else { return }
        defer { finish() }
        do {
            let data: Data = try await read(backup)
            exportFile = BackupExportFile(data: data, fileName: BackupFormat.fileName(for: backup.createdAt))
        } catch {
            message = BackupMessage(title: "書き出せませんでした", text: BackupError.message(for: error))
        }
    }

    /// 読み込んだファイルを確かめる（F0813、F0815）。読めたら pending に入る。重い確認はメインスレッドの外で行う。
    func inspect(_ data: Data, source: String) async {
        guard begin(.reading) else { return }
        defer { finish() }
        let result: Result<BackupContents, BackupError> = await Task.detached(priority: .userInitiated) { () -> Result<BackupContents, BackupError> in
            BackupController.read(data)
        }.value
        switch result {
        case .success(let contents):
            pending = PendingRestore(source: source, contents: contents)
        case .failure(let error):
            message = BackupMessage(title: "このバックアップは使えません", text: error.message)
        }
    }

    /// 端末内のバックアップを確かめる。
    func inspect(_ backup: LocalBackup) async {
        let data: Data
        do {
            data = try await read(backup)
        } catch {
            message = BackupMessage(title: "読み込めませんでした", text: BackupError.message(for: error))
            return
        }
        await inspect(data, source: "\(backup.kind.title)（\(BackupFormat.date(backup.createdAt))）")
    }

    /// 確認した内容で復元する。成功したら true。
    @discardableResult
    func restore(_ pending: PendingRestore, parts: Set<BackupPart>) async -> Bool {
        guard !parts.isEmpty, begin(.restoring) else { return false }
        defer { finish() }
        self.pending = nil
        do {
            let safety: LocalBackup = try await session.restore(pending.contents, parts: parts)
            message = BackupMessage(
                title: "復元しました",
                text: "「\(BackupFormat.date(pending.contents.createdAt))」のバックアップから復元しました。"
                    + "復元の前のデータは、この iPad のバックアップ（\(safety.kind.title)・\(BackupFormat.date(safety.createdAt))）に残しています。"
            )
            refresh()
            return true
        } catch {
            message = BackupMessage(title: "復元できませんでした", text: BackupError.message(for: error))
            refresh()
            return false
        }
    }

    /// すべてのデータを消す。成功したら true。
    @discardableResult
    func eraseAll() async -> Bool {
        guard begin(.erasing) else { return false }
        defer { finish() }
        do {
            let safety: LocalBackup = try await session.eraseAllData()
            message = BackupMessage(
                title: "すべてのデータを消しました",
                text: "初めて起動した時の状態に戻しました。消す前のデータは、この iPad のバックアップ（\(safety.kind.title)・\(BackupFormat.date(safety.createdAt))）に残しています。"
                    + "残したくない時は、一覧から削除してください。"
            )
            refresh()
            return true
        } catch {
            message = BackupMessage(title: "消せませんでした", text: BackupError.message(for: error))
            refresh()
            return false
        }
    }

    func delete(_ backup: LocalBackup) {
        do {
            try session.localBackups?.delete(backup)
        } catch {
            message = BackupMessage(title: "削除できませんでした", text: BackupError.message(for: error))
        }
        refresh()
    }

    func deleteAll() {
        do {
            try session.localBackups?.deleteAll()
        } catch {
            message = BackupMessage(title: "削除できませんでした", text: BackupError.message(for: error))
        }
        refresh()
    }

    // MARK: - 内部

    private func begin(_ next: Activity) -> Bool {
        guard activity == .idle else { return false }
        activity = next
        return true
    }

    private func finish() {
        activity = .idle
    }

    private func read(_ backup: LocalBackup) async throws -> Data {
        guard let store = session.localBackups else {
            throw BackupError.unavailable(unavailableReason ?? "")
        }
        return try await Task.detached(priority: .userInitiated) { () throws -> Data in
            try store.read(backup)
        }.value
    }

    nonisolated private static func read(_ data: Data) -> Result<BackupContents, BackupError> {
        do {
            return .success(try BackupReader.read(data))
        } catch let error as BackupError {
            return .failure(error)
        } catch {
            return .failure(.malformed(BackupError.message(for: error)))
        }
    }
}
