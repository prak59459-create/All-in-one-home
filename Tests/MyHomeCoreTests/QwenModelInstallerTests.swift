import Foundation
import XCTest
@testable import MyHomeCore

/// 追加フェーズ A: Qwen のモデルの取得と導入（小さな偽のモデルで確かめる）。
final class QwenModelInstallerTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = try MigrationFixtureTests.makeDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    /// 決まった中身を返すダウンローダー（取得した回数を数える。fail に入れたパスは失敗させる）。
    private final class FakeDownloader: QwenFileDownloader, @unchecked Sendable {
        private let lock = NSLock()
        private var contents: [String: Data] = [:]
        private var counts: [String: Int] = [:]
        var failing: Set<String> = []

        func serve(_ url: URL, _ data: Data) {
            lock.lock()
            contents[url.absoluteString] = data
            lock.unlock()
        }

        func count(_ url: URL) -> Int {
            lock.lock()
            defer { lock.unlock() }
            return counts[url.absoluteString] ?? 0
        }

        func download(_ url: URL, to destination: URL) async throws -> Int {
            lock.lock()
            counts[url.absoluteString, default: 0] += 1
            let data: Data? = contents[url.absoluteString]
            let fails: Bool = failing.contains(url.absoluteString)
            lock.unlock()
            if fails {
                throw QwenModelInstallError.offline
            }
            guard let data else { return 404 }
            try data.write(to: destination)
            return 200
        }
    }

    /// パッケージごとに 1 ファイルと、トークナイザーの 2 ファイルの偽のモデル。
    private func fakeModel() -> [(file: QwenModelFile, data: Data)] {
        var result: [(file: QwenModelFile, data: Data)] = []
        let paths: [String] = QwenModelManifest.packages.map { (name: String) -> String in name + ".mlpackage/Manifest.json" }
            + QwenModelManifest.tokenizerFiles
        for path in paths {
            let data = Data("中身: \(path)".utf8)
            result.append((QwenModelFile(path: path, size: data.count, blob: SHA1.gitBlobHash(data)), data))
        }
        return result
    }

    private func tree(_ files: [(file: QwenModelFile, data: Data)], change: String? = nil) -> Data {
        let entries: [String] = files.map { (item: (file: QwenModelFile, data: Data)) -> String in
            let sha: String = item.file.path == change ? String(repeating: "0", count: 40) : item.file.blob
            return #"{"path": "\#(QwenModelManifest.repositoryFolder)/\#(item.file.path)", "type": "blob", "sha": "\#(sha)", "mode": "100644"}"#
        }
        return Data(#"{"tree": [{"path": "README.md", "type": "blob", "sha": "abc", "mode": "100644"}, \#(entries.joined(separator: ", "))], "truncated": false}"#.utf8)
    }

    /// コンパイルの代わりに、フォルダをコピーする。
    private let copyCompiler: QwenModelCompiler = { (source: URL) async throws -> URL in
        let output: URL = FileManager.default.temporaryDirectory.appendingPathComponent("compiled-\(UUID().uuidString).mlmodelc")
        try FileManager.default.copyItem(at: source, to: output)
        return output
    }

    @MainActor
    private func makeInstaller(
        _ model: [(file: QwenModelFile, data: Data)],
        transport: FakeTransport,
        downloader: FakeDownloader,
        refs: [String] = ["", "feature/x", "main"]
    ) -> QwenModelInstaller {
        QwenModelInstaller(
            directory: directory.appendingPathComponent("Models/qwen", isDirectory: true),
            transport: transport,
            downloader: downloader,
            compiler: copyCompiler,
            refs: refs,
            manifest: model.map { (item: (file: QwenModelFile, data: Data)) -> QwenModelFile in item.file }
        )
    }

    @MainActor
    func testInstallsFromTheFirstRefWithTheSameFiles() async throws {
        let model = fakeModel()
        let transport = FakeTransport()
        let downloader = FakeDownloader()
        transport.respond(QwenModelInstaller.treeURL(ref: "feature/x")!.absoluteString, status: 404, data: Data())
        transport.respond(QwenModelInstaller.treeURL(ref: "main")!.absoluteString, data: tree(model))
        for item in model {
            downloader.serve(QwenModelInstaller.rawURL(ref: "main", path: item.file.path)!, item.data)
        }
        let installer: QwenModelInstaller = makeInstaller(model, transport: transport, downloader: downloader)
        XCTAssertEqual(installer.state, .notInstalled)

        await installer.install()

        XCTAssertEqual(installer.state, .installed)
        let folder: URL = installer.directory
        for name in QwenModelManifest.packages {
            XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("compiled/\(name).mlmodelc/Manifest.json").path), name)
        }
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("vocab.json")), model.first { $0.file.path == "vocab.json" }?.data)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("staging").path), "取得途中のフォルダは消す")
        XCTAssertTrue(QwenModelInstaller.isInstalled(at: folder, manifest: model.map { $0.file }))
        XCTAssertFalse(QwenModelInstaller.isInstalled(at: folder, manifest: Array(model.map { $0.file }.dropLast())), "一覧が変われば入れ直す")
        XCTAssertEqual(makeInstaller(model, transport: transport, downloader: downloader).state, .installed, "次に開いた時も入っている")

        try installer.remove()
        XCTAssertEqual(installer.state, .notInstalled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
    }

    @MainActor
    func testRefusesFilesFromAnotherVersion() async throws {
        let model = fakeModel()
        let transport = FakeTransport()
        let downloader = FakeDownloader()
        transport.respond(QwenModelInstaller.treeURL(ref: "main")!.absoluteString, data: tree(model, change: QwenModelManifest.headPackages[0] + ".mlpackage/Manifest.json"))
        let installer: QwenModelInstaller = makeInstaller(model, transport: transport, downloader: downloader, refs: ["main"])
        await installer.install()
        XCTAssertEqual(installer.state, .failed(QwenModelInstallError.versionMismatch.message))
        XCTAssertEqual(downloader.count(QwenModelInstaller.rawURL(ref: "main", path: "vocab.json")!), 0, "版が違えば 1 つも取得しない")
    }

    @MainActor
    func testCorruptedFilesAreRejectedAndARetryContinuesWhereItStopped() async throws {
        let model = fakeModel()
        let transport = FakeTransport()
        let downloader = FakeDownloader()
        transport.respond(QwenModelInstaller.treeURL(ref: "main")!.absoluteString, data: tree(model))
        for item in model {
            downloader.serve(QwenModelInstaller.rawURL(ref: "main", path: item.file.path)!, item.data)
        }
        // 同じ大きさで中身の違うファイル
        let broken = model[1]
        let brokenURL: URL = QwenModelInstaller.rawURL(ref: "main", path: broken.file.path)!
        downloader.serve(brokenURL, Data(repeating: 0x41, count: broken.file.size))
        let installer: QwenModelInstaller = makeInstaller(model, transport: transport, downloader: downloader, refs: ["main"])
        await installer.install()
        XCTAssertEqual(installer.state, .failed(QwenModelInstallError.corrupted(broken.file.path).message))

        // 直った中身で続きから。最初のファイルは取り直さない
        downloader.serve(brokenURL, broken.data)
        let firstURL: URL = QwenModelInstaller.rawURL(ref: "main", path: model[0].file.path)!
        XCTAssertEqual(downloader.count(firstURL), 1)
        await installer.install()
        XCTAssertEqual(installer.state, .installed)
        XCTAssertEqual(downloader.count(firstURL), 1, "確かめ済みのファイルは取り直さない")
        XCTAssertEqual(downloader.count(brokenURL), 2)
    }

    @MainActor
    func testOfflineIsExplained() async throws {
        let model = fakeModel()
        let transport = FakeTransport()
        let downloader = FakeDownloader()
        transport.respond(QwenModelInstaller.treeURL(ref: "main")!.absoluteString, data: tree(model))
        downloader.failing = [QwenModelInstaller.rawURL(ref: "main", path: model[0].file.path)!.absoluteString]
        let installer: QwenModelInstaller = makeInstaller(model, transport: transport, downloader: downloader, refs: ["main"])
        await installer.install()
        XCTAssertEqual(installer.state, .failed(QwenModelInstallError.offline.message))
    }

    func testURLsAndManifest() {
        XCTAssertEqual(
            QwenModelInstaller.treeURL(ref: "claude/cool-maxwell-asqk2v")?.absoluteString,
            "https://api.github.com/repos/prak59459-create/All-in-one-home/git/trees/claude/cool-maxwell-asqk2v?recursive=1"
        )
        XCTAssertEqual(
            QwenModelInstaller.rawURL(ref: "main", path: "QwenHead.mlpackage/Manifest.json")?.absoluteString,
            "https://raw.githubusercontent.com/prak59459-create/All-in-one-home/main/models/qwen2.5-0.5b-instruct-coreml/QwenHead.mlpackage/Manifest.json"
        )
        let paths: Set<String> = Set(QwenModelManifest.files.map { (file: QwenModelFile) -> String in file.path })
        XCTAssertEqual(paths.count, QwenModelManifest.files.count)
        for name in QwenModelManifest.packages {
            XCTAssertTrue(paths.contains(name + ".mlpackage/Manifest.json"), name)
            XCTAssertTrue(paths.contains(name + ".mlpackage/Data/com.apple.CoreML/weights/weight.bin"), name)
        }
        for name in QwenModelManifest.tokenizerFiles {
            XCTAssertTrue(paths.contains(name), name)
        }
        XCTAssertTrue(QwenModelManifest.files.allSatisfy { (file: QwenModelFile) -> Bool in file.size < 100_000_000 }, "GitHub の 1 ファイル 100MB の上限")
    }
}
