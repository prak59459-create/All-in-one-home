import Foundation
import Observation

/// 大きなファイルを取得して、そのまま保存する（iPad では URLSession のダウンロード。テストでは決まった中身を書く）。
protocol QwenFileDownloader: Sendable {
    /// url の中身を destination に保存し、HTTP の状態コードを返す（200 以外の時は保存しない）。
    func download(_ url: URL, to destination: URL) async throws -> Int
}

/// 取得したモデルを、端末で使える形にコンパイルする（iPad では MLModel.compileModel。テストではコピー）。
/// 戻り値はコンパイルしたもの（.mlmodelc）の場所。
typealias QwenModelCompiler = @Sendable (URL) async throws -> URL

/// Qwen のモデルを取得して入れる（追加フェーズ A の TA-4）。モデルはアプリ（.swiftpm）に入れず、リポジトリの models/ から
/// 1 回だけ取得する（ビルドを速く保つため。ソフトウェアアップデートの対象にもしない）。
/// 1. GitHub の tree で、アプリが持つ一覧（QwenModelManifest）と同じ版のファイルがあるブランチ・コミットを探す
/// 2. 1 つずつ取得し、大きさ（小さなファイルは中身の SHA-1 も）を確かめる。途中で止めても、確かめ済みのファイルは取り直さない
/// 3. 端末でコンパイルして compiled/ に置き、トークナイザーのファイルを置き、最後に入れた印（installed.json）を書く
@MainActor
@Observable
final class QwenModelInstaller {
    enum State: Hashable, Sendable {
        case notInstalled
        case checking
        case downloading(file: Int, of: Int, bytes: Int)
        case compiling(model: Int, of: Int)
        case installed
        case failed(String)
    }

    private(set) var state: State

    /// 入れる場所（Application Support/MyHome/Models/qwen2.5-0.5b-instruct-coreml）。
    let directory: URL
    @ObservationIgnored private let transport: any UpdateTransport
    @ObservationIgnored private let downloader: any QwenFileDownloader
    @ObservationIgnored private let compiler: QwenModelCompiler
    @ObservationIgnored private let refs: [String]
    @ObservationIgnored private let manifest: [QwenModelFile]
    @ObservationIgnored private var task: Task<Void, Never>?

    /// refs は、取得を試すブランチ・コミットの順（空のものは飛ばす）。
    init(
        directory: URL,
        transport: any UpdateTransport,
        downloader: any QwenFileDownloader,
        compiler: @escaping QwenModelCompiler,
        refs: [String] = QwenModelInstaller.defaultRefs,
        manifest: [QwenModelFile] = QwenModelManifest.files
    ) {
        self.directory = directory
        self.transport = transport
        self.downloader = downloader
        self.compiler = compiler
        self.refs = refs.filter { (ref: String) -> Bool in !ref.isEmpty }
        self.manifest = manifest
        state = QwenModelInstaller.isInstalled(at: directory, manifest: manifest) ? .installed : .notInstalled
    }

    /// アプリをビルドしたコミット（ソフトウェアアップデートで入れた時）、そのブランチ、main の順。
    nonisolated static var defaultRefs: [String] {
        [BuildStamp.commit, BuildStamp.branch, "main"]
    }

    var isWorking: Bool {
        switch state {
        case .checking, .downloading, .compiling: return true
        case .notInstalled, .installed, .failed: return false
        }
    }

    /// 取得して入れる。終わるまで待つ。
    func install() async {
        guard !isWorking, state != .installed else { return }
        state = .checking
        let job = Task { [weak self] () async -> Void in
            await self?.run()
        }
        task = job
        await job.value
        task = nil
    }

    /// 取得を止める。確かめ済みのファイルは残すので、次は続きから取得する。
    func cancel() {
        task?.cancel()
    }

    /// 入れたモデルを消す（取得途中のファイルも）。
    func remove() throws {
        guard !isWorking else { return }
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        state = .notInstalled
    }

    /// 入れ終わっていて、印の版が今の一覧と同じか。
    nonisolated static func isInstalled(at directory: URL, manifest: [QwenModelFile]) -> Bool {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(markerName)),
              let marker = try? JSONDecoder().decode(Marker.self, from: data) else {
            return false
        }
        return marker.fingerprint == fingerprint(of: manifest)
    }

    // MARK: - 手順

    private func run() async {
        do {
            let ref: String = try await resolveRef()
            try await downloadAll(from: ref)
            try await compileAll()
            try finish()
            state = .installed
        } catch is CancellationError {
            state = .notInstalled
        } catch let error as QwenModelInstallError {
            state = .failed(error.message)
        } catch {
            state = .failed(QwenModelInstallError.message(for: error))
        }
    }

    /// 一覧と同じ版のファイルがある最初のブランチ・コミット。
    private func resolveRef() async throws -> String {
        var lastProblem: QwenModelInstallError = .notFound
        for ref in refs {
            try Task.checkCancellation()
            guard let url = QwenModelInstaller.treeURL(ref: ref) else { continue }
            let response: TransportResponse = try await transport.get(url)
            guard response.status == 200 else {
                lastProblem = response.status == 403 || response.status == 429 ? .rateLimited : .notFound
                continue
            }
            let remote: [String: String] = try QwenModelInstaller.blobs(in: response.data)
            if remote.isEmpty {
                lastProblem = .notFound
                continue
            }
            let matches: Bool = manifest.allSatisfy { (file: QwenModelFile) -> Bool in
                remote[QwenModelManifest.repositoryFolder + "/" + file.path] == file.blob
            }
            if matches {
                return ref
            }
            lastProblem = .versionMismatch
        }
        throw lastProblem
    }

    private func downloadAll(from ref: String) async throws {
        var bytes: Int = 0
        for (index, file) in manifest.enumerated() {
            try Task.checkCancellation()
            state = .downloading(file: index + 1, of: manifest.count, bytes: bytes)
            let destination: URL = stagingURL(for: file.path)
            if !QwenModelInstaller.isValid(destination, file: file) {
                try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? FileManager.default.removeItem(at: destination)
                guard let url = QwenModelInstaller.rawURL(ref: ref, path: file.path) else { throw QwenModelInstallError.notFound }
                let status: Int = try await downloader.download(url, to: destination)
                guard status == 200 else { throw QwenModelInstallError.httpStatus(status) }
                guard QwenModelInstaller.isValid(destination, file: file) else {
                    try? FileManager.default.removeItem(at: destination)
                    throw QwenModelInstallError.corrupted(file.path)
                }
            }
            bytes += file.size
        }
        state = .downloading(file: manifest.count, of: manifest.count, bytes: bytes)
    }

    private func compileAll() async throws {
        let compiledFolder: URL = directory.appendingPathComponent("compiled", isDirectory: true)
        try FileManager.default.createDirectory(at: compiledFolder, withIntermediateDirectories: true)
        for (index, name) in QwenModelManifest.packages.enumerated() {
            try Task.checkCancellation()
            state = .compiling(model: index + 1, of: QwenModelManifest.packages.count)
            let source: URL = stagingURL(for: name + ".mlpackage")
            let compiled: URL = try await compiler(source)
            let target: URL = compiledFolder.appendingPathComponent(name + ".mlmodelc", isDirectory: true)
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.moveItem(at: compiled, to: target)
        }
    }

    private func finish() throws {
        for name in QwenModelManifest.tokenizerFiles {
            let target: URL = directory.appendingPathComponent(name)
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.copyItem(at: stagingURL(for: name), to: target)
        }
        let marker = Marker(fingerprint: QwenModelInstaller.fingerprint(of: manifest))
        try JSONEncoder().encode(marker).write(to: directory.appendingPathComponent(QwenModelInstaller.markerName), options: .atomic)
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("staging", isDirectory: true))
    }

    private func stagingURL(for path: String) -> URL {
        directory.appendingPathComponent("staging", isDirectory: true).appendingPathComponent(path)
    }

    // MARK: - 補助

    private struct Marker: Codable {
        let fingerprint: String
    }

    private nonisolated static let markerName: String = "installed.json"

    /// 一覧の版（全部のファイルのハッシュをつないだものの SHA-1）。一覧が変われば入れ直す。
    nonisolated static func fingerprint(of manifest: [QwenModelFile]) -> String {
        let joined: String = manifest.map { (file: QwenModelFile) -> String in file.path + ":" + file.blob }.joined(separator: "\n")
        return SHA1.hexDigest(Data(joined.utf8))
    }

    nonisolated static func isValid(_ url: URL, file: QwenModelFile) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              fileSize(attributes) == file.size else {
            return false
        }
        guard file.verifiesContent else { return true }
        guard let data = try? Data(contentsOf: url) else { return false }
        return SHA1.gitBlobHash(data) == file.blob
    }

    private nonisolated static func fileSize(_ attributes: [FileAttributeKey: Any]) -> Int {
        let value: Any? = attributes[.size]
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let unsigned = value as? UInt64 {
            return Int(clamping: unsigned)
        }
        return (value as? Int) ?? -1
    }

    nonisolated static func treeURL(ref: String) -> URL? {
        guard let encoded = ref.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        let owner: String = PackageIdentity.repositoryOwner
        let repository: String = PackageIdentity.repositoryName
        return URL(string: "https://\(GitHubUpdateClient.apiHost)/repos/\(owner)/\(repository)/git/trees/\(encoded)?recursive=1")
    }

    nonisolated static func rawURL(ref: String, path: String) -> URL? {
        let full: String = ref + "/" + QwenModelManifest.repositoryFolder + "/" + path
        guard let encoded = full.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        let owner: String = PackageIdentity.repositoryOwner
        let repository: String = PackageIdentity.repositoryName
        return URL(string: "https://\(GitHubUpdateClient.rawHost)/\(owner)/\(repository)/\(encoded)")
    }

    private struct TreeJSON: Decodable {
        struct Entry: Decodable {
            let path: String
            let type: String
            let sha: String
        }

        let tree: [Entry]
    }

    /// tree の中の、モデルのフォルダのファイル（パス → sha）。
    nonisolated static func blobs(in data: Data) throws -> [String: String] {
        let tree: TreeJSON
        do {
            tree = try JSONDecoder().decode(TreeJSON.self, from: data)
        } catch {
            throw QwenModelInstallError.badResponse
        }
        var result: [String: String] = [:]
        let prefix: String = QwenModelManifest.repositoryFolder + "/"
        for entry in tree.tree where entry.type == "blob" && entry.path.hasPrefix(prefix) {
            result[entry.path] = entry.sha
        }
        return result
    }
}

enum QwenModelInstallError: Error, Hashable, Sendable {
    /// どのブランチ・コミットにもモデルのファイルがない。
    case notFound
    /// ファイルはあるが、このアプリの版と合わない。
    case versionMismatch
    case rateLimited
    case httpStatus(Int)
    case badResponse
    case corrupted(String)
    /// インターネットにつながっていない（アプリ側のダウンローダーが URLError から置き換える）。
    case offline
    case timedOut

    var message: String {
        switch self {
        case .notFound:
            return "モデルのファイルが見つかりませんでした。ソフトウェアアップデートで、モデルの入った版にしてから試してください。"
        case .versionMismatch:
            return "このアプリの版と合うモデルが見つかりませんでした。ソフトウェアアップデートで、アプリとモデルの版をそろえてください。"
        case .rateLimited:
            return "GitHub の利用回数の上限に達しました。しばらく待ってから試してください。"
        case .httpStatus(let status):
            return "取得に失敗しました（HTTP \(status)）。"
        case .badResponse:
            return "GitHub から読めない応答が返りました。"
        case .corrupted(let path):
            return "取得したファイル（\(path)）が壊れていました。もう一度試してください。"
        case .offline:
            return "インターネットにつながっていません。つながってから、もう一度試してください（取得済みのファイルは取り直しません）。"
        case .timedOut:
            return "時間内に取得できませんでした。もう一度試してください（取得済みのファイルは取り直しません）。"
        }
    }

    static func message(for error: Error) -> String {
        if let known = error as? QwenModelInstallError {
            return known.message
        }
        return "モデルを入れられませんでした（\(error.localizedDescription)）。"
    }
}
