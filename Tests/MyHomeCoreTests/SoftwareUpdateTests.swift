import Foundation
import XCTest
@testable import MyHomeCore

/// ソフトウェアアップデート: ハッシュ、差分の計算、書き込み・退避・元に戻す、取得の検証、書き込み先の確認。
final class SoftwareUpdateTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = UpdateFixtures.makeTemporaryDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - ハッシュ

    func testSHA1MatchesKnownVectors() {
        XCTAssertEqual(SHA1.hexDigest(Data("abc".utf8)), "a9993e364706816aba3e25717850c26c9cd0d89d")
        XCTAssertEqual(SHA1.hexDigest(Data()), "da39a3ee5e6b4b0d3255bfef95601890afd80709")
        let long: String = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
        XCTAssertEqual(SHA1.hexDigest(Data(long.utf8)), "84983e441c3bd26ebaae4aa1f95129e5e54670f1")
    }

    func testGitBlobHashMatchesGit() throws {
        XCTAssertEqual(SHA1.gitBlobHash(Data()), "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
        XCTAssertEqual(SHA1.gitBlobHash(Data("hello\n".utf8)), "ce013625030ba8dba906f756967f9e9ca394464a")
        // git hash-object scripts/fixtures/home-restore.json の値
        let root: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data: Data = try Data(contentsOf: root.appendingPathComponent("scripts/fixtures/home-restore.json"))
        XCTAssertEqual(SHA1.gitBlobHash(data), "0efa354783b47ec1c83fd8f876913e3a76d3922d")
    }

    // MARK: - パスとフォルダ

    func testUnsafePathsAreRejected() {
        XCTAssertTrue(PackagePath.isSafe("Core/AppInfo.swift"))
        for path in ["", "/etc/passwd", "../Package.swift", "Core/../../x", "a//b", ".swiftpm/x", "Core/.hidden", "a\\b", "./a"] {
            XCTAssertFalse(PackagePath.isSafe(path), path)
        }
    }

    func testListingSkipsHiddenFolders() throws {
        let package: DirectoryFileSystem = try UpdateFixtures.makePackage(in: directory, files: ["Core/A.swift": "a"])
        let hidden: URL = package.root.appendingPathComponent(".swiftpm/xcode/x.txt")
        try FileManager.default.createDirectory(at: hidden.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: hidden)
        XCTAssertEqual(try package.listFiles(), ["Core/A.swift", PackageIdentity.markerPath, UpdatePlanner.manifestPath].sorted())
    }

    func testVerifierAcceptsOnlyThisPackage() throws {
        let good: DirectoryFileSystem = try UpdateFixtures.makePackage(in: directory, files: [:])
        XCTAssertNoThrow(try PackageVerifier.verify(folderName: "MyHome.swiftpm", package: good))
        XCTAssertNoThrow(try PackageVerifier.verify(folderName: "MyHome 2.swiftpm", package: good), "複製した名前でも中身で判断する")
        XCTAssertThrowsError(try PackageVerifier.verify(folderName: "Documents", package: good))

        let other: DirectoryFileSystem = try UpdateFixtures.makePackage(in: directory, name: "Other.swiftpm", files: [
            PackageIdentity.markerPath: "enum PackageIdentity { static let id = \"someone-else\" }"
        ])
        XCTAssertThrowsError(try PackageVerifier.verify(folderName: "Other.swiftpm", package: other)) { error in
            guard case .wrongPackage = error as? UpdateError else { return XCTFail("wrongPackage のはず") }
        }

        let library: DirectoryFileSystem = try UpdateFixtures.makePackage(in: directory, name: "Lib.swiftpm", files: [
            UpdatePlanner.manifestPath: "let package = Package(name: \"Lib\")"
        ])
        XCTAssertThrowsError(try PackageVerifier.verify(folderName: "Lib.swiftpm", package: library))
    }

    func testRealPackagePassesVerification() throws {
        // リポジトリの MyHome.swiftpm 自体が、書き込み先として認められる（識別ファイルが入っている）
        let root: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let package = DirectoryFileSystem(root: root.appendingPathComponent("MyHome.swiftpm", isDirectory: true))
        XCTAssertNoThrow(try PackageVerifier.verify(folderName: "MyHome.swiftpm", package: package))
        XCTAssertTrue(try package.listFiles().contains(BuildStampWriter.path))
        XCTAssertFalse(try package.listFiles().contains { $0.hasPrefix(".") })
    }

    // MARK: - 差分の計算

    func testFirstUpdatePlan() {
        let snapshot: RemoteSnapshot = UpdateFixtures.snapshot([
            "Core/A.swift": "same", "Core/B.swift": "new version", "Core/C.swift": "added",
            UpdatePlanner.manifestPath: "manifest v2 .iOSApplication(", BuildStampWriter.path: "enum BuildStamp {}"
        ])
        let local: [String: String] = [
            "Core/A.swift": SHA1.gitBlobHash(Data("same".utf8)),
            "Core/B.swift": SHA1.gitBlobHash(Data("old version".utf8)),
            "Core/Mine.swift": SHA1.gitBlobHash(Data("mine".utf8)),
            UpdatePlanner.manifestPath: SHA1.gitBlobHash(Data(UpdateFixtures.manifest.utf8)),
            PackageIdentity.markerPath: SHA1.gitBlobHash(Data(UpdateFixtures.marker.utf8)),
            BuildStampWriter.path: SHA1.gitBlobHash(Data("anything".utf8))
        ]
        let plan: UpdatePlan = UpdatePlanner.plan(snapshot: snapshot, local: local, installed: nil)
        XCTAssertEqual(plan.additions.map(\.path), ["Core/C.swift"])
        XCTAssertEqual(plan.modifications.map(\.path), ["Core/B.swift"])
        XCTAssertEqual(plan.locallyEdited, [], "初めての更新では手元の変更かどうか分からない（上書き前に退避する）")
        XCTAssertEqual(plan.untracked, ["Core/Mine.swift"], "記録のないファイルは消さない")
        XCTAssertEqual(plan.deletions, [])
        XCTAssertEqual(plan.manifestChange?.path, UpdatePlanner.manifestPath)
        XCTAssertEqual(plan.unchangedCount, 2, "A.swift と識別ファイル（BuildStamp は比べない）")
        XCTAssertFalse(plan.isUpToDate)
    }

    func testPlanDetectsLocalEditsAndSafeDeletions() {
        let snapshot: RemoteSnapshot = UpdateFixtures.snapshot(["Core/A.swift": "a2", "Core/B.swift": "b2"])
        let hash: (String) -> String = { (text: String) -> String in SHA1.gitBlobHash(Data(text.utf8)) }
        let installed: [String: String] = [
            "Core/A.swift": hash("a1"), "Core/B.swift": hash("b1"), "Core/Old.swift": hash("old"), "Core/Edited.swift": hash("e1"),
            UpdatePlanner.manifestPath: hash(UpdateFixtures.manifest)
        ]
        let local: [String: String] = [
            "Core/A.swift": hash("a1"), "Core/B.swift": hash("b1 edited on iPad"), "Core/Old.swift": hash("old"),
            "Core/Edited.swift": hash("e1 edited"), UpdatePlanner.manifestPath: hash(UpdateFixtures.manifest),
            PackageIdentity.markerPath: hash(UpdateFixtures.marker)
        ]
        let plan: UpdatePlan = UpdatePlanner.plan(snapshot: snapshot, local: local, installed: installed)
        XCTAssertEqual(plan.modifications.map(\.path), ["Core/A.swift", "Core/B.swift"])
        XCTAssertEqual(plan.locallyEdited, ["Core/B.swift"])
        XCTAssertEqual(plan.deletions, ["Core/Old.swift"], "更新で入れて手元で変えていないものだけ消す")
        XCTAssertEqual(plan.untracked, ["Core/Edited.swift"], "手元で変えたファイルは消さない")
        XCTAssertNil(plan.manifestChange)
    }

    func testIdenticalPackageIsUpToDate() {
        let snapshot: RemoteSnapshot = UpdateFixtures.snapshot(["Core/A.swift": "a"])
        var local: [String: String] = [:]
        for file in snapshot.files {
            local[file.path] = file.blobSHA
        }
        XCTAssertTrue(UpdatePlanner.plan(snapshot: snapshot, local: local, installed: nil).isUpToDate)
    }

    // MARK: - 書き込み・元に戻す

    private func installEverything(_ plan: UpdatePlan, files: [String: String], package: PackageFileSystem, backupID: String = "update-1") throws -> InstallResult {
        var contents: [String: Data] = [:]
        for (path, text) in files {
            contents[path] = Data(text.utf8)
        }
        let backups = DirectoryFileSystem(root: directory.appendingPathComponent("Backups/\(backupID)", isDirectory: true))
        return try UpdateInstaller.install(
            plan: plan, selection: UpdateSelection(includeManifest: true, overwriteLocalEdits: true), contents: contents,
            package: package, backups: backups, backupID: backupID, previous: UpdateInstaller.Previous(commit: nil, branch: nil, installed: nil)
        )
    }

    func testInstallWritesChangesAndStampAndRollbackRestoresExactly() throws {
        let package: DirectoryFileSystem = try UpdateFixtures.makePackage(in: directory, files: [
            "Core/A.swift": "a1", "Core/B.swift": "b1", BuildStampWriter.path: "enum BuildStamp { static let commit = \"\" }"
        ])
        let before: [String: String] = try UpdateFixtures.contents(of: package)
        let remoteFiles: [String: String] = ["Core/A.swift": "a1", "Core/B.swift": "b2", "Core/C.swift": "c1"]
        let snapshot: RemoteSnapshot = UpdateFixtures.snapshot(remoteFiles)
        let local: [String: String] = try UpdateController.localHashes(of: package)
        let plan: UpdatePlan = UpdatePlanner.plan(snapshot: snapshot, local: local, installed: nil)
        let result: InstallResult = try installEverything(plan, files: remoteFiles, package: package)

        let after: [String: String] = try UpdateFixtures.contents(of: package)
        XCTAssertEqual(after["Core/B.swift"], "b2")
        XCTAssertEqual(after["Core/C.swift"], "c1")
        XCTAssertTrue(after[BuildStampWriter.path]?.contains(snapshot.commitSHA) ?? false, "BuildStamp に書き込んだコミットを入れる")
        XCTAssertEqual(Set(result.written), ["Core/B.swift", "Core/C.swift"])
        XCTAssertEqual(result.installed["Core/B.swift"], SHA1.gitBlobHash(Data("b2".utf8)))

        let backups = DirectoryFileSystem(root: directory.appendingPathComponent("Backups/update-1", isDirectory: true))
        _ = try UpdateInstaller.rollback(package: package, backups: backups)
        XCTAssertEqual(try UpdateFixtures.contents(of: package), before, "元に戻すと、追加したファイルも消えて完全に元通り")
    }

    func testFailureWhileWritingLeavesPackageUnchanged() throws {
        let base: DirectoryFileSystem = try UpdateFixtures.makePackage(in: directory, files: [
            "Core/A.swift": "a1", "Core/B.swift": "b1", BuildStampWriter.path: "stamp"
        ])
        let before: [String: String] = try UpdateFixtures.contents(of: base)
        let remoteFiles: [String: String] = ["Core/A.swift": "a2", "Core/B.swift": "b2", "Core/C.swift": "c"]
        let plan: UpdatePlan = UpdatePlanner.plan(
            snapshot: UpdateFixtures.snapshot(remoteFiles), local: try UpdateController.localHashes(of: base), installed: nil
        )
        for failOn in 1...4 {
            let failing = FailingFileSystem(base: base, failOnWrite: failOn)
            XCTAssertThrowsError(try installEverything(plan, files: remoteFiles, package: failing, backupID: "update-fail-\(failOn)"))
            XCTAssertEqual(try UpdateFixtures.contents(of: base), before, "\(failOn) 回目の書き込みで失敗しても元のまま")
        }
    }

    func testMissingDownloadWritesNothing() throws {
        let package: DirectoryFileSystem = try UpdateFixtures.makePackage(in: directory, files: ["Core/A.swift": "a1"])
        let before: [String: String] = try UpdateFixtures.contents(of: package)
        let plan: UpdatePlan = UpdatePlanner.plan(
            snapshot: UpdateFixtures.snapshot(["Core/A.swift": "a2", "Core/B.swift": "b"]),
            local: try UpdateController.localHashes(of: package), installed: nil
        )
        XCTAssertThrowsError(try installEverything(plan, files: ["Core/A.swift": "a2"], package: package)) { error in
            XCTAssertEqual(error as? UpdateError, .integrity("Core/B.swift"))
        }
        XCTAssertEqual(try UpdateFixtures.contents(of: package), before)
    }

    func testLocalEditsAndManifestAreSkippedUnlessChosen() throws {
        let package: DirectoryFileSystem = try UpdateFixtures.makePackage(in: directory, files: ["Core/A.swift": "a-edited"])
        let hash: (String) -> String = { (text: String) -> String in SHA1.gitBlobHash(Data(text.utf8)) }
        let installed: [String: String] = ["Core/A.swift": hash("a1"), UpdatePlanner.manifestPath: hash("old manifest")]
        let remoteFiles: [String: String] = ["Core/A.swift": "a2", UpdatePlanner.manifestPath: "new manifest .iOSApplication("]
        let plan: UpdatePlan = UpdatePlanner.plan(
            snapshot: UpdateFixtures.snapshot(remoteFiles), local: try UpdateController.localHashes(of: package), installed: installed
        )
        XCTAssertEqual(plan.locallyEdited, ["Core/A.swift"])
        XCTAssertTrue(plan.manifestLocallyEdited)
        let backups = DirectoryFileSystem(root: directory.appendingPathComponent("Backups/skip", isDirectory: true))
        let result: InstallResult = try UpdateInstaller.install(
            plan: plan, selection: UpdateSelection(includeManifest: false, overwriteLocalEdits: false), contents: [:],
            package: package, backups: backups, backupID: "skip", previous: UpdateInstaller.Previous(commit: nil, branch: nil, installed: installed)
        )
        XCTAssertEqual(Set(result.skipped), ["Core/A.swift", UpdatePlanner.manifestPath])
        XCTAssertEqual(try UpdateFixtures.contents(of: package)["Core/A.swift"], "a-edited", "手元の変更は残す")
        XCTAssertEqual(result.installed["Core/A.swift"], hash("a1"), "次も「手元で変更あり」と分かるよう前の値のまま")
    }

    // MARK: - GitHub からの取得

    func testClientReadsBranchesTreeAndVerifiesFiles() async throws {
        let transport = FakeTransport()
        UpdateFixtures.serve(["Core/A.swift": "a"], branch: "claude/feature", on: transport)
        let client = GitHubUpdateClient(transport: transport)
        let branches: [RemoteBranch] = try await client.branches()
        XCTAssertEqual(branches.map(\.name), ["claude/feature"])
        let snapshot: RemoteSnapshot = try await client.snapshot(of: branches[0])
        XCTAssertEqual(snapshot.files.map(\.path), ["Core/A.swift", PackageIdentity.markerPath, UpdatePlanner.manifestPath].sorted())
        let file: RemoteFile = try XCTUnwrap(snapshot.files.first { $0.path == "Core/A.swift" })
        let data: Data = try await client.download(file, commit: snapshot.commitSHA)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "a")
        XCTAssertTrue(transport.requestedURLs.contains { $0.contains("raw.githubusercontent.com") && $0.contains(snapshot.commitSHA) },
                      "ファイルはブランチ名ではなくコミットで取得する（途中で更新されても混ざらない）")
    }

    func testClientRejectsTamperedOrMissingData() async throws {
        let transport = FakeTransport()
        let client = GitHubUpdateClient(transport: transport)
        let file = RemoteFile(path: "Core/A.swift", blobSHA: SHA1.gitBlobHash(Data("expected".utf8)), size: 8)
        let raw: String = "https://raw.githubusercontent.com/\(PackageIdentity.repositoryOwner)/\(PackageIdentity.repositoryName)/abc/MyHome.swiftpm/Core/A.swift"
        transport.respond(raw, data: Data("tampered".utf8))
        do {
            _ = try await client.download(file, commit: "abc")
            XCTFail("ハッシュが違えば拒否する")
        } catch {
            XCTAssertEqual(error as? UpdateError, .integrity("Core/A.swift"))
        }
        transport.respond(raw, status: 403, data: Data())
        do {
            _ = try await client.download(file, commit: "abc")
            XCTFail("上限に達したことを知らせる")
        } catch {
            XCTAssertEqual(error as? UpdateError, .rateLimited)
        }
    }

    func testTreeWithoutPackageOrTruncatedIsRejected() async throws {
        let transport = FakeTransport()
        let client = GitHubUpdateClient(transport: transport)
        let api: String = "https://api.github.com/repos/\(PackageIdentity.repositoryOwner)/\(PackageIdentity.repositoryName)"
        let branch = RemoteBranch(name: "main", commitSHA: "abc")
        transport.respond("\(api)/git/trees/abc?recursive=1", json: #"{"tree": [{"path": "README.md", "mode": "100644", "type": "blob", "sha": "x", "size": 1}], "truncated": false}"#)
        do {
            _ = try await client.snapshot(of: branch)
            XCTFail("MyHome.swiftpm がないブランチは拒否する")
        } catch {
            XCTAssertEqual(error as? UpdateError, .packageMissing)
        }
        transport.respond("\(api)/git/trees/abc?recursive=1", json: #"{"tree": [], "truncated": true}"#)
        do {
            _ = try await client.snapshot(of: branch)
            XCTFail("途中で切れた一覧は使わない")
        } catch {
            XCTAssertEqual(error as? UpdateError, .truncatedTree)
        }
    }

    func testTreeSkipsHiddenSymlinksAndSubmodules() async throws {
        let transport = FakeTransport()
        let client = GitHubUpdateClient(transport: transport)
        let api: String = "https://api.github.com/repos/\(PackageIdentity.repositoryOwner)/\(PackageIdentity.repositoryName)"
        let manifest: String = SHA1.gitBlobHash(Data("m".utf8))
        let json: String = """
        {"tree": [
          {"path": "MyHome.swiftpm/Package.swift", "mode": "100644", "type": "blob", "sha": "\(manifest)", "size": 1},
          {"path": "MyHome.swiftpm/Core/PackageIdentity.swift", "mode": "100644", "type": "blob", "sha": "\(manifest)", "size": 1},
          {"path": "MyHome.swiftpm/.swiftpm/config", "mode": "100644", "type": "blob", "sha": "\(manifest)", "size": 1},
          {"path": "MyHome.swiftpm/Link.swift", "mode": "120000", "type": "blob", "sha": "\(manifest)", "size": 1},
          {"path": "MyHome.swiftpm/Vendor", "mode": "160000", "type": "commit", "sha": "\(manifest)"},
          {"path": "MyHome.swiftpm/Core", "mode": "040000", "type": "tree", "sha": "\(manifest)"},
          {"path": "Tests/X.swift", "mode": "100644", "type": "blob", "sha": "\(manifest)", "size": 1}
        ], "truncated": false}
        """
        transport.respond("\(api)/git/trees/abc?recursive=1", json: json)
        let snapshot: RemoteSnapshot = try await client.snapshot(of: RemoteBranch(name: "main", commitSHA: "abc"))
        XCTAssertEqual(snapshot.files.map(\.path), [PackageIdentity.markerPath, UpdatePlanner.manifestPath])
    }

    // MARK: - 全体の流れ

    @MainActor
    func testControllerInstallsAndRollsBackEndToEnd() async throws {
        let package: DirectoryFileSystem = try UpdateFixtures.makePackage(in: directory, files: [
            "Core/A.swift": "a1", BuildStampWriter.path: "enum BuildStamp {}"
        ])
        let before: [String: String] = try UpdateFixtures.contents(of: package)
        let transport = FakeTransport()
        UpdateFixtures.serve(["Core/A.swift": "a2", "Core/New.swift": "new", BuildStampWriter.path: "enum BuildStamp {}"], on: transport)
        let controller = UpdateController(
            client: GitHubUpdateClient(transport: transport),
            stateStore: UpdateStateStore(fileURL: directory.appendingPathComponent("update-state.json")),
            backups: DirectoryFileSystem(root: directory.appendingPathComponent("UpdateBackups", isDirectory: true)),
            runningCommit: ""
        )
        await controller.loadBranches()
        XCTAssertEqual(controller.selectedBranchName, "main")
        await controller.check(package: package, folderName: "MyHome.swiftpm")
        let plan: UpdatePlan = try XCTUnwrap(controller.plan)
        XCTAssertEqual(plan.additions.map(\.path), ["Core/New.swift"])
        XCTAssertEqual(plan.modifications.map(\.path), ["Core/A.swift"])
        await controller.install(package: package, folderName: "MyHome.swiftpm")
        guard case .installed(let result) = controller.phase else {
            return XCTFail("書き込めるはず: \(controller.phase)")
        }
        XCTAssertEqual(try UpdateFixtures.contents(of: package)["Core/A.swift"], "a2")
        XCTAssertEqual(controller.state.installedCommit, result.commitSHA)
        guard case .needsRebuild = controller.buildStatus else {
            return XCTFail("書き込んだ後、実行し直すまでは「未反映」")
        }

        // 記録は保存され、作り直しても残る（再起動の代わり）
        let reloaded = UpdateStateStore(fileURL: directory.appendingPathComponent("update-state.json")).load()
        XCTAssertEqual(reloaded.installedCommit, result.commitSHA)
        XCTAssertEqual(BuildStatus.evaluate(runningCommit: result.commitSHA, state: reloaded), .upToDate(commit: result.commitSHA))

        await controller.check(package: package, folderName: "MyHome.swiftpm")
        XCTAssertTrue(controller.plan?.isUpToDate ?? false, "書き込んだ後は差分なし")

        await controller.rollback(package: package, folderName: "MyHome.swiftpm")
        guard case .rolledBack = controller.phase else {
            return XCTFail("元に戻せるはず: \(controller.phase)")
        }
        XCTAssertEqual(try UpdateFixtures.contents(of: package), before)
        XCTAssertNil(controller.state.installedCommit)
    }

    @MainActor
    func testControllerRefusesWrongFolderWithoutWriting() async throws {
        let other: DirectoryFileSystem = try UpdateFixtures.makePackage(in: directory, name: "Other.swiftpm", files: [
            PackageIdentity.markerPath: "not this app", "Core/A.swift": "a1"
        ])
        let before: [String: String] = try UpdateFixtures.contents(of: other)
        let transport = FakeTransport()
        UpdateFixtures.serve(["Core/A.swift": "a2"], on: transport)
        let controller = UpdateController(
            client: GitHubUpdateClient(transport: transport),
            stateStore: UpdateStateStore(fileURL: directory.appendingPathComponent("update-state.json")),
            backups: DirectoryFileSystem(root: directory.appendingPathComponent("UpdateBackups", isDirectory: true))
        )
        await controller.loadBranches()
        await controller.check(package: other, folderName: "Other.swiftpm")
        guard case .failed(let message) = controller.phase else {
            return XCTFail("別のフォルダは拒否する")
        }
        XCTAssertTrue(message.contains("MyHome のパッケージではありません"), message)
        XCTAssertNil(controller.plan)
        XCTAssertEqual(try UpdateFixtures.contents(of: other), before)
    }

    func testCheckStatusRequiresBothAppJobs() {
        let ok = CheckRunSummary(name: "App / iOS Simulator / Xcode 16.4", status: "completed", conclusion: "success")
        let running = CheckRunSummary(name: "App / iOS Simulator / Xcode 26.3", status: "in_progress", conclusion: nil)
        let broken = CheckRunSummary(name: "App / iOS Simulator / Xcode 26.3", status: "completed", conclusion: "failure")
        let linux = CheckRunSummary(name: "Core / Linux / Swift 6.4.1", status: "completed", conclusion: "success")
        XCTAssertEqual(CommitCheckStatus.evaluate([ok, linux]), .passed)
        XCTAssertEqual(CommitCheckStatus.evaluate([ok, running]), .pending)
        XCTAssertEqual(CommitCheckStatus.evaluate([ok, broken]), .failed)
        XCTAssertEqual(CommitCheckStatus.evaluate([linux]), .unknown, "アプリのビルドを確かめていない")
    }

    @MainActor
    func testUnverifiedCommitNeedsExplicitConsent() async throws {
        let package: DirectoryFileSystem = try UpdateFixtures.makePackage(in: directory, files: ["Core/A.swift": "a1"])
        let transport = FakeTransport()
        UpdateFixtures.serve(["Core/A.swift": "a2"], on: transport)
        let api: String = "https://api.github.com/repos/\(PackageIdentity.repositoryOwner)/\(PackageIdentity.repositoryName)"
        let commit: String = "c0ffee0000000000000000000000000000000001"
        transport.respond("\(api)/commits/\(commit)/check-runs?per_page=100", json: #"{"total_count": 1, "check_runs": [{"name": "App / iOS Simulator / Xcode 26.3", "status": "completed", "conclusion": "failure"}]}"#)
        let controller = UpdateController(
            client: GitHubUpdateClient(transport: transport),
            stateStore: UpdateStateStore(fileURL: directory.appendingPathComponent("update-state.json")),
            backups: DirectoryFileSystem(root: directory.appendingPathComponent("UpdateBackups", isDirectory: true))
        )
        await controller.loadBranches()
        await controller.check(package: package, folderName: "MyHome.swiftpm")
        XCTAssertEqual(controller.checkStatus, .failed)
        XCTAssertFalse(controller.canInstall)
        await controller.install(package: package, folderName: "MyHome.swiftpm")
        XCTAssertEqual(try UpdateFixtures.contents(of: package)["Core/A.swift"], "a1", "承知していなければ書き込まない")
        controller.allowsUnverifiedCommit = true
        XCTAssertTrue(controller.canInstall)
    }

    func testBuildStatusAndStampText() {
        XCTAssertEqual(BuildStatus.evaluate(runningCommit: "", state: .empty), .notInstalledByUpdater)
        var state: UpdateState = .empty
        state.installedCommit = "abc"
        XCTAssertEqual(BuildStatus.evaluate(runningCommit: "", state: state), .needsRebuild(running: "", installed: "abc"))
        XCTAssertEqual(BuildStatus.evaluate(runningCommit: "abc", state: state), .upToDate(commit: "abc"))
        XCTAssertEqual(BuildStampWriter.sanitized("feature/\"x\"\n"), "feature/_x__")
        XCTAssertTrue(BuildStampWriter.source(commit: "abc", branch: "main").contains("static let commit: String = \"abc\""))
    }
}
