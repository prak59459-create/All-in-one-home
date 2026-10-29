import SwiftUI

/// 設定 → ソフトウェアアップデート。GitHub のブランチから、変わったファイルだけを MyHome.swiftpm に書き込む。
/// アプリ自身はビルドし直せないので、書き込んだ後は Swift Playgrounds で実行し直してもらう（その手順を表示する）。
@MainActor
struct SoftwareUpdateView: View {
    @State private var controller: UpdateController?
    @State private var setupError: String?

    var body: some View {
        Group {
            if let controller {
                SoftwareUpdateForm(controller: controller)
            } else if let setupError {
                ContentUnavailableView("アップデートを使えません", systemImage: "exclamationmark.triangle", description: Text(setupError))
            } else {
                ProgressView()
            }
        }
        .navigationTitle("ソフトウェアアップデート")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            prepare()
        }
    }

    private func prepare() {
        guard controller == nil else { return }
        do {
            let directory: URL = try FileHomeArchiveStorage.standard().directory
            controller = UpdateController(
                client: GitHubUpdateClient(transport: URLSessionTransport()),
                stateStore: UpdateStateStore(fileURL: directory.appendingPathComponent("update-state.json")),
                backups: DirectoryFileSystem(root: directory.appendingPathComponent("UpdateBackups", isDirectory: true))
            )
        } catch {
            setupError = "アプリの保存先を用意できませんでした。"
        }
    }
}

@MainActor
struct SoftwareUpdateForm: View {
    @Bindable var controller: UpdateController
    @State private var isPickingFolder: Bool = false
    @State private var isConfirmingInstall: Bool = false
    @State private var isConfirmingRollback: Bool = false
    @State private var folderMessage: String?

    var body: some View {
        Form {
            Section("いま動いている版") {
                Text(controller.buildStatus.message)
                if let branch = controller.state.branch, let date = controller.state.installedAt {
                    Text("最後に書き込んだ日時: \(date.formatted(date: .abbreviated, time: .shortened))（\(branch)）")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            folderSection
            branchSection
            if let plan = controller.plan {
                UpdatePlanSection(plan: plan, controller: controller)
                installSection
            }
            UpdateStatusSection(controller: controller)
            rollbackSection
            Section {
                Text("通信するのは、この画面でボタンを押した時だけです。GitHub の公開リポジトリ（\(PackageIdentity.repositoryOwner)/\(PackageIdentity.repositoryName)）から、api.github.com と raw.githubusercontent.com を使って取得します。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $isPickingFolder) {
            PackageFolderPicker { url in
                isPickingFolder = false
                Task { await remember(url) }
            }
        }
        .confirmationDialog("書き込みますか？", isPresented: $isConfirmingInstall, titleVisibility: .visible) {
            Button("書き込む") {
                Task { await withPackage { package, name in await controller.install(package: package, folderName: name) } }
            }
        } message: {
            Text("書き込む前のファイルはアプリの中に退避し、「元に戻す」で戻せます。Swift Playgrounds でコードを編集している途中なら、先に閉じてください。")
        }
        .confirmationDialog("更新の前に戻しますか？", isPresented: $isConfirmingRollback, titleVisibility: .visible) {
            Button("元に戻す", role: .destructive) {
                Task { await withPackage { package, name in await controller.rollback(package: package, folderName: name) } }
            }
        }
    }

    private var folderSection: some View {
        Section {
            if let location = controller.state.packageLocation {
                Label(location, systemImage: "folder")
            } else {
                Text("まだ選んでいません")
                    .foregroundStyle(.secondary)
            }
            Button("MyHome.swiftpm を選ぶ") {
                isPickingFolder = true
            }
            .disabled(controller.isWorking)
            if let folderMessage {
                Text(folderMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("書き込み先")
        } footer: {
            Text("Files の「ブラウズ」から、Swift Playgrounds が使っている MyHome.swiftpm（ふつうは iCloud Drive の「Playgrounds」フォルダ）を選んでください。選んだフォルダの Package.swift と識別ファイルを確かめ、MyHome でなければ何も書き込みません。")
        }
    }

    private var branchSection: some View {
        Section("ブランチ") {
            Button("ブランチを読み込む") {
                Task { await controller.loadBranches() }
            }
            .disabled(controller.isWorking)
            if !controller.branches.isEmpty {
                Picker("ブランチ", selection: $controller.selectedBranchName) {
                    ForEach(controller.branches) { branch in
                        Text(branch.name).tag(Optional(branch.name))
                    }
                }
                Button("違うファイルを確認") {
                    Task { await withPackage { package, name in await controller.check(package: package, folderName: name) } }
                }
                .disabled(controller.isWorking || controller.selectedBranch == nil || controller.state.packageBookmark == nil)
            }
        }
    }

    @ViewBuilder
    private var installSection: some View {
        if let plan = controller.plan, !plan.isUpToDate {
            Section {
                Button("書き込む") {
                    isConfirmingInstall = true
                }
                .disabled(!controller.canInstall)
            }
        }
    }

    @ViewBuilder
    private var rollbackSection: some View {
        if controller.state.lastBackupID != nil {
            Section {
                Button("最後の更新の前に戻す", role: .destructive) {
                    isConfirmingRollback = true
                }
                .disabled(controller.isWorking)
            } footer: {
                Text("書き込んだ版でアプリがおかしい時に使います。戻した後も、Swift Playgrounds で実行し直してください。")
            }
        }
    }

    /// 選んだフォルダを確かめてから覚える（iCloud Drive のファイルの取得を待つことがあるので、確認はメインスレッドの外で行う）。
    private func remember(_ url: URL) async {
        folderMessage = nil
        do {
            let access: PackageAccess = try PackageAccess.open(picked: url)
            defer { access.stop() }
            let package: CoordinatedPackageFileSystem = access.fileSystem
            let name: String = access.folderName
            try await UpdateController.offMain { try PackageVerifier.verify(folderName: name, package: package) }
            controller.rememberPackage(bookmark: try access.makeBookmark(), location: access.location)
        } catch {
            folderMessage = UpdateController.message(for: error)
        }
    }

    /// 覚えておいたフォルダを開いて作業し、終わったら閉じる。
    private func withPackage(_ work: (CoordinatedPackageFileSystem, String) async -> Void) async {
        guard let bookmark = controller.state.packageBookmark else {
            folderMessage = UpdateError.folderNotSelected.message
            return
        }
        do {
            let opened: (access: PackageAccess, refreshedBookmark: Data?) = try PackageAccess.open(bookmark: bookmark)
            defer { opened.access.stop() }
            if let refreshed = opened.refreshedBookmark {
                controller.rememberPackage(bookmark: refreshed, location: opened.access.location)
            }
            await work(opened.access.fileSystem, opened.access.folderName)
        } catch {
            folderMessage = UpdateController.message(for: error)
        }
    }
}
