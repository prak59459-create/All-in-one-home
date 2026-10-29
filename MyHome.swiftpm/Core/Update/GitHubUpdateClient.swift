import Foundation

/// GitHub のブランチ。
struct RemoteBranch: Hashable, Sendable, Identifiable {
    let name: String
    let commitSHA: String

    var id: String { name }
}

/// 取得するコミットの中の、パッケージ（MyHome.swiftpm）のファイル1つ。path はパッケージからの相対パス。
struct RemoteFile: Hashable, Sendable {
    let path: String
    let blobSHA: String
    let size: Int
}

/// あるコミットのパッケージの中身の一覧。
struct RemoteSnapshot: Hashable, Sendable {
    let branch: String
    let commitSHA: String
    let files: [RemoteFile]
}

struct TransportResponse: Sendable {
    let status: Int
    let data: Data
}

/// 通信の実装（iPad では URLSession。テストでは固定の応答）。
protocol UpdateTransport: Sendable {
    func get(_ url: URL) async throws -> TransportResponse
}

/// GitHub からブランチ・ファイル一覧・ファイルを取得する。ファイルはコミットの SHA で取得し、
/// git のブロブのハッシュが一覧と一致することを確かめる（途中で壊れた・違う版のファイルを書き込まない）。
struct GitHubUpdateClient: Sendable {
    static let maximumFileSize: Int = 2_000_000
    static let maximumFileCount: Int = 2_000

    let owner: String
    let repository: String
    let packagePath: String
    let transport: any UpdateTransport

    init(
        owner: String = PackageIdentity.repositoryOwner,
        repository: String = PackageIdentity.repositoryName,
        packagePath: String = PackageIdentity.packagePathInRepository,
        transport: any UpdateTransport
    ) {
        self.owner = owner
        self.repository = repository
        self.packagePath = packagePath
        self.transport = transport
    }

    func branches() async throws -> [RemoteBranch] {
        let url: URL = try apiURL("branches?per_page=100")
        let decoded: [BranchJSON] = try decode([BranchJSON].self, from: try await fetch(url))
        return decoded.map { (branch: BranchJSON) -> RemoteBranch in RemoteBranch(name: branch.name, commitSHA: branch.commit.sha) }
    }

    func snapshot(of branch: RemoteBranch) async throws -> RemoteSnapshot {
        let url: URL = try apiURL("git/trees/\(branch.commitSHA)?recursive=1")
        let tree: TreeJSON = try decode(TreeJSON.self, from: try await fetch(url))
        guard !tree.truncated else { throw UpdateError.truncatedTree }
        let files: [RemoteFile] = try packageFiles(in: tree)
        guard files.contains(where: { (file: RemoteFile) -> Bool in file.path == UpdatePlanner.manifestPath }),
              files.contains(where: { (file: RemoteFile) -> Bool in file.path == PackageIdentity.markerPath }) else {
            throw UpdateError.packageMissing
        }
        return RemoteSnapshot(branch: branch.name, commitSHA: branch.commitSHA, files: files)
    }

    /// コミットの CI の結果。
    func checkStatus(commit: String) async throws -> CommitCheckStatus {
        let url: URL = try apiURL("commits/\(commit)/check-runs?per_page=100")
        let decoded: CheckRunsJSON = try decode(CheckRunsJSON.self, from: try await fetch(url))
        return CommitCheckStatus.evaluate(decoded.checkRuns)
    }

    /// 1ファイルを取得し、ハッシュを確かめる。
    func download(_ file: RemoteFile, commit: String) async throws -> Data {
        let data: Data = try await fetch(try rawURL(for: file.path, commit: commit))
        guard data.count <= GitHubUpdateClient.maximumFileSize else { throw UpdateError.tooLarge(file.path) }
        guard SHA1.gitBlobHash(data) == file.blobSHA else { throw UpdateError.integrity(file.path) }
        return data
    }

    // MARK: - 内部

    private struct BranchJSON: Decodable {
        struct Commit: Decodable {
            let sha: String
        }

        let name: String
        let commit: Commit
    }

    private struct CheckRunsJSON: Decodable {
        let checkRuns: [CheckRunSummary]

        private enum CodingKeys: String, CodingKey {
            case checkRuns = "check_runs"
        }
    }

    private struct TreeJSON: Decodable {
        struct Entry: Decodable {
            let path: String
            let mode: String
            let type: String
            let sha: String
            let size: Int?
        }

        let tree: [Entry]
        let truncated: Bool
    }

    /// パッケージの中の普通のファイルだけ（シンボリックリンク・サブモジュール・隠しファイルは除く）。
    private func packageFiles(in tree: TreeJSON) throws -> [RemoteFile] {
        let prefix: String = packagePath + "/"
        var files: [RemoteFile] = []
        for entry in tree.tree where entry.type == "blob" && entry.path.hasPrefix(prefix) {
            let relative: String = String(entry.path.dropFirst(prefix.count))
            guard entry.mode == "100644" || entry.mode == "100755" else { continue }
            guard PackagePath.isSafe(relative) else {
                // 隠しファイル（.swiftpm の中など）は管理しない。それ以外の不正な名前は拒否する
                if relative.split(separator: "/").contains(where: { (part: Substring) -> Bool in part.hasPrefix(".") }) {
                    continue
                }
                throw UpdateError.unsafePath(relative)
            }
            let size: Int = entry.size ?? 0
            guard size <= GitHubUpdateClient.maximumFileSize else { throw UpdateError.tooLarge(relative) }
            files.append(RemoteFile(path: relative, blobSHA: entry.sha, size: size))
        }
        guard files.count <= GitHubUpdateClient.maximumFileCount else { throw UpdateError.truncatedTree }
        return files.sorted { (lhs: RemoteFile, rhs: RemoteFile) -> Bool in lhs.path < rhs.path }
    }

    private func apiURL(_ suffix: String) throws -> URL {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repository)/\(suffix)") else {
            throw UpdateError.badResponse(0)
        }
        return url
    }

    private func rawURL(for path: String, commit: String) throws -> URL {
        let full: String = packagePath + "/" + path
        guard let encoded = full.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://raw.githubusercontent.com/\(owner)/\(repository)/\(commit)/\(encoded)") else {
            throw UpdateError.unsafePath(path)
        }
        return url
    }

    private func fetch(_ url: URL) async throws -> Data {
        let response: TransportResponse
        do {
            response = try await transport.get(url)
        } catch let error as UpdateError {
            throw error
        } catch {
            throw UpdateError.network(error.localizedDescription)
        }
        switch response.status {
        case 200:
            return response.data
        case 403, 429:
            throw UpdateError.rateLimited
        case 404:
            throw UpdateError.notFound
        default:
            throw UpdateError.badResponse(response.status)
        }
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw UpdateError.badResponse(200)
        }
    }
}
