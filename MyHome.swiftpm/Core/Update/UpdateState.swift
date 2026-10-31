import Foundation

/// ソフトウェアアップデートの記録（Application Support/MyHome/update-state.json）。配置の保存ファイルとは別に持つ。
struct UpdateState: Codable, Hashable, Sendable {
    /// 書き込み先の MyHome.swiftpm（セキュリティスコープ付きのブックマーク。iPad で作る）。
    var packageBookmark: Data?
    /// 書き込み先の表示用の場所（例: iCloud Drive › Playgrounds › MyHome.swiftpm）。
    var packageLocation: String?
    var branch: String?
    var installedCommit: String?
    var installedAt: Date?
    /// 更新で入れたファイル → ハッシュ（次に「手元で変更されたか」を判断する）。
    var installedFiles: [String: String]?
    var lastBackupID: String?

    static let empty = UpdateState()
}

/// 記録の読み書き。
struct UpdateStateStore: Sendable {
    let fileURL: URL

    func load() -> UpdateState {
        guard let data = try? Data(contentsOf: fileURL) else { return .empty }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return (try? decoder.decode(UpdateState.self, from: data)) ?? .empty
    }

    func save(_ state: UpdateState) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(state).write(to: fileURL, options: .atomic)
    }
}

/// いま動いているアプリが、更新で書き込んだコミットでビルドされたか。
enum BuildStatus: Hashable, Sendable {
    /// アップデート機能で入れた版ではない（リポジトリから手で入れた版など）。
    case notInstalledByUpdater
    /// 最後に書き込んだコミットでビルドされている。
    case upToDate(commit: String)
    /// 書き込んだが、まだ前のビルドで動いている（Swift Playgrounds で実行し直す必要がある）。
    case needsRebuild(running: String, installed: String)

    static func evaluate(runningCommit: String, state: UpdateState) -> BuildStatus {
        guard let installed = state.installedCommit else {
            return runningCommit.isEmpty ? .notInstalledByUpdater : .upToDate(commit: runningCommit)
        }
        return runningCommit == installed ? .upToDate(commit: installed) : .needsRebuild(running: runningCommit, installed: installed)
    }

    var message: String {
        switch self {
        case .notInstalledByUpdater:
            return "この版はアップデート機能で入れたものではありません。"
        case .upToDate(let commit):
            return "コミット \(String(commit.prefix(7))) でビルドされています。"
        case .needsRebuild(let running, let installed):
            let current: String = running.isEmpty ? "更新前の版" : "コミット \(String(running.prefix(7)))"
            return "コミット \(String(installed.prefix(7))) を書き込みましたが、いま動いているのは\(current)です。"
                + "Swift Playgrounds で ■ を押して止め、プロジェクトを開き直してから ▶ を押してください。"
        }
    }
}
