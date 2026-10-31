import Foundation
@testable import MyHomeCore

/// 固定の応答を返す通信（URL の文字列 → 応答）。
final class FakeTransport: UpdateTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [String: TransportResponse] = [:]
    private var requested: [String] = []
    var failure: Error?

    func respond(_ url: String, status: Int = 200, data: Data) {
        lock.lock()
        responses[url] = TransportResponse(status: status, data: data)
        lock.unlock()
    }

    func respond(_ url: String, json: String) {
        respond(url, data: Data(json.utf8))
    }

    var requestedURLs: [String] {
        lock.lock()
        defer { lock.unlock() }
        return requested
    }

    func get(_ url: URL) async throws -> TransportResponse {
        lock.lock()
        requested.append(url.absoluteString)
        let response: TransportResponse? = responses[url.absoluteString]
        let failure: Error? = self.failure
        lock.unlock()
        if let failure {
            throw failure
        }
        return response ?? TransportResponse(status: 404, data: Data())
    }
}

/// 指定した回数目の書き込みで失敗する（途中で失敗した時に元へ戻るかを確かめる）。
final class FailingFileSystem: PackageFileSystem, @unchecked Sendable {
    struct Failure: Error {}

    private let base: DirectoryFileSystem
    private let lock = NSLock()
    private var writes: Int = 0
    private let failOnWrite: Int

    init(base: DirectoryFileSystem, failOnWrite: Int) {
        self.base = base
        self.failOnWrite = failOnWrite
    }

    func listFiles() throws -> [String] { try base.listFiles() }
    func read(_ path: String) throws -> Data { try base.read(path) }
    func delete(_ path: String) throws { try base.delete(path) }
    func exists(_ path: String) -> Bool { base.exists(path) }

    func write(_ data: Data, to path: String) throws {
        lock.lock()
        writes += 1
        let count: Int = writes
        lock.unlock()
        if count == failOnWrite {
            throw Failure()
        }
        try base.write(data, to: path)
    }
}

/// 一時フォルダに、MyHome のパッケージに見える最小のフォルダを作る。
enum UpdateFixtures {
    static let manifest: String = """
    // swift-tools-version: 5.9
    import AppleProductTypes
    import PackageDescription
    let package = Package(name: "MyHome", products: [.iOSApplication(name: "MyHome", targets: ["AppModule"])])
    """

    static var marker: String {
        "enum PackageIdentity { static let id: String = \"\(PackageIdentity.id)\" }\n"
    }

    static func makeTemporaryDirectory() -> URL {
        let url: URL = FileManager.default.temporaryDirectory.appendingPathComponent("MyHomeUpdate-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// files: パス → 中身。Package.swift と識別ファイルは自動で入れる。
    static func makePackage(in parent: URL, name: String = "MyHome.swiftpm", files: [String: String]) throws -> DirectoryFileSystem {
        let root: URL = parent.appendingPathComponent(name, isDirectory: true)
        let package = DirectoryFileSystem(root: root)
        var all: [String: String] = files
        if all[UpdatePlanner.manifestPath] == nil {
            all[UpdatePlanner.manifestPath] = manifest
        }
        if all[PackageIdentity.markerPath] == nil {
            all[PackageIdentity.markerPath] = marker
        }
        for (path, text) in all {
            try package.write(Data(text.utf8), to: path)
        }
        return package
    }

    static func contents(of package: DirectoryFileSystem) throws -> [String: String] {
        var result: [String: String] = [:]
        for path in try package.listFiles() {
            result[path] = String(decoding: try package.read(path), as: UTF8.self)
        }
        return result
    }

    static func remote(_ path: String, _ text: String) -> RemoteFile {
        RemoteFile(path: path, blobSHA: SHA1.gitBlobHash(Data(text.utf8)), size: text.utf8.count)
    }

    static func snapshot(_ files: [String: String], commit: String = "c0ffee0000000000000000000000000000000001") -> RemoteSnapshot {
        var all: [String: String] = files
        if all[UpdatePlanner.manifestPath] == nil {
            all[UpdatePlanner.manifestPath] = manifest
        }
        if all[PackageIdentity.markerPath] == nil {
            all[PackageIdentity.markerPath] = marker
        }
        let remoteFiles: [RemoteFile] = all.keys.sorted().map { (path: String) -> RemoteFile in remote(path, all[path] ?? "") }
        return RemoteSnapshot(branch: "main", commitSHA: commit, files: remoteFiles)
    }

    /// GitHub の応答を FakeTransport に登録する（ブランチ1つ、そのコミットのツリーと各ファイル）。
    static func serve(
        _ files: [String: String],
        branch: String = "main",
        commit: String = "c0ffee0000000000000000000000000000000001",
        on transport: FakeTransport
    ) {
        let snapshot: RemoteSnapshot = self.snapshot(files, commit: commit)
        let api: String = "https://api.github.com/repos/\(PackageIdentity.repositoryOwner)/\(PackageIdentity.repositoryName)"
        transport.respond("\(api)/branches?per_page=100", json: "[{\"name\": \"\(branch)\", \"commit\": {\"sha\": \"\(commit)\"}}]")
        var entries: [String] = []
        for file in snapshot.files {
            let repoPath: String = "\(PackageIdentity.packagePathInRepository)/\(file.path)"
            entries.append("{\"path\": \"\(repoPath)\", \"mode\": \"100644\", \"type\": \"blob\", \"sha\": \"\(file.blobSHA)\", \"size\": \(file.size)}")
            let raw: String = "https://raw.githubusercontent.com/\(PackageIdentity.repositoryOwner)/\(PackageIdentity.repositoryName)/\(commit)/\(repoPath)"
            transport.respond(raw, data: Data((files[file.path] ?? (file.path == UpdatePlanner.manifestPath ? manifest : marker)).utf8))
        }
        transport.respond("\(api)/git/trees/\(commit)?recursive=1", json: "{\"tree\": [\(entries.joined(separator: ","))], \"truncated\": false}")
        let runs: String = """
        {"total_count": 2, "check_runs": [
          {"name": "App / iOS Simulator / Xcode 16.4", "status": "completed", "conclusion": "success"},
          {"name": "App / iOS Simulator / Xcode 26.3", "status": "completed", "conclusion": "success"}]}
        """
        transport.respond("\(api)/commits/\(commit)/check-runs?per_page=100", json: runs)
    }
}
