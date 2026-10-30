import SwiftUI
import UniformTypeIdentifiers

/// 設定 → バックアップと復元（F0812–F0832、F0839、F0861、F0862、F0868）。処理は BackupController（Core）が行う。
@MainActor
struct BackupSettingsView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        BackupControllerHost(session: session)
    }
}

/// BackupController を最初の表示の時に @State の初期値として作って持つ（天気の画面と同じ作り。後から入れ直さない）。
/// AppSession は復元の後も同じものなので、作り直す必要はない。
@MainActor
struct BackupControllerHost: View {
    @State private var controller: BackupController

    init(session: AppSession) {
        _controller = State(initialValue: BackupController(session: session))
    }

    var body: some View {
        BackupScreen(controller: controller)
    }
}

/// 結果やエラー、読み込んだバックアップは、ダイアログではなくページの一番上に出す
/// （ファイルを選ぶ画面やダイアログが閉じる途中で次の画面を出すと、表示されないことがあるため）。
@MainActor
struct BackupScreen: View {
    @Bindable var controller: BackupController
    @State private var isImporting: Bool = false
    @State private var isConfirmingErase: Bool = false

    var body: some View {
        ScrollViewReader { (proxy: ScrollViewProxy) in
            Form {
                if let reason = controller.unavailableReason {
                    Section {
                        Label(reason, systemImage: "exclamationmark.triangle")
                    }
                }
                if let message = controller.message {
                    BackupMessageSection(message: message) {
                        controller.message = nil
                    }
                }
                if let pending = controller.pending {
                    PendingRestoreSection(controller: controller, pending: pending)
                        .id(pending.id)
                }
                BackupCreateSection(controller: controller)
                restoreSection
                LocalBackupsSection(controller: controller)
                eraseSection
            }
            // 中身（画像など）ごと比べないよう、ID の変化だけを見る
            .onChange(of: controller.message?.id) { (_: UUID?, id: UUID?) in
                if let id {
                    withAnimation { proxy.scrollTo(id, anchor: .top) }
                }
            }
            .onChange(of: controller.pending?.id) { (_: UUID?, id: UUID?) in
                if let id {
                    withAnimation { proxy.scrollTo(PendingRestoreSection.anchor(id), anchor: .top) }
                }
            }
        }
        .disabled(controller.isBusy || controller.unavailableReason != nil)
        .overlay {
            if controller.isBusy {
                BackupProgressView(title: controller.activity.title)
            }
        }
        .navigationTitle("バックアップと復元")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            controller.refresh()
        }
        .fileExporter(
            isPresented: isExporting,
            document: controller.exportFile.map { (file: BackupExportFile) -> BackupDocument in BackupDocument(data: file.data) },
            contentType: .json,
            defaultFilename: controller.exportFile?.fileName,
            onCompletion: { (result: Result<URL, Error>) in
                finishExport(result)
            }
        )
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            onCompletion: { (result: Result<URL, Error>) in
                startImport(result)
            }
        )
        .alert("すべてのデータを消しますか？", isPresented: $isConfirmingErase) {
            Button("消す", role: .destructive) {
                Task { await controller.eraseAll() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("ホーム画面の配置・設定・タイマー、ミニアプリのデータ、アイコンと壁紙の画像を消して、初めて起動した時の状態に戻します。消す前のデータは、この iPad のバックアップ（消去の前）に残ります。")
        }
    }

    private var restoreSection: some View {
        Section {
            Button {
                isImporting = true
            } label: {
                Label("ファイルから復元", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("復元")
        } footer: {
            Text("ファイルを選ぶと、中身を確かめてから、戻すものを選んで復元できます。")
        }
    }

    private var eraseSection: some View {
        Section {
            Button(role: .destructive) {
                isConfirmingErase = true
            } label: {
                Label("すべてのデータを消す", systemImage: "trash")
            }
        } footer: {
            Text("この iPad のバックアップと、ソフトウェアアップデートの記録は消しません。")
        }
    }

    private var isExporting: Binding<Bool> {
        Binding<Bool>(
            get: { controller.exportFile != nil },
            set: { (presented: Bool) in
                if !presented {
                    controller.exportFile = nil
                }
            }
        )
    }

    private func finishExport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            controller.message = BackupMessage(title: "書き出しました", text: "「\(url.lastPathComponent)」として保存しました。")
        case .failure(let error):
            if (error as? CocoaError)?.code == .userCancelled {
                return
            }
            controller.message = BackupMessage(title: "書き出せませんでした", text: error.localizedDescription)
        }
        controller.exportFile = nil
    }

    private func startImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            Task {
                let read: Result<Data, Error> = await Task.detached(priority: .userInitiated) { () -> Result<Data, Error> in
                    BackupFileReader.read(url)
                }.value
                switch read {
                case .success(let data):
                    await controller.inspect(data, source: url.lastPathComponent)
                case .failure(let error):
                    controller.message = BackupMessage(title: "読み込めませんでした", text: BackupError.message(for: error))
                }
            }
        case .failure(let error):
            if (error as? CocoaError)?.code == .userCancelled {
                return
            }
            controller.message = BackupMessage(title: "読み込めませんでした", text: error.localizedDescription)
        }
    }
}

/// バックアップを作る（ファイルに書き出す・この iPad に保存）。
@MainActor
struct BackupCreateSection: View {
    let controller: BackupController

    var body: some View {
        Section {
            Button {
                Task { await controller.prepareExport() }
            } label: {
                Label("ファイルに書き出す", systemImage: "square.and.arrow.up")
            }
            Button {
                Task { await controller.saveOnDevice() }
            } label: {
                Label("この iPad に保存", systemImage: "internaldrive")
            }
        } header: {
            Text("バックアップ")
        } footer: {
            Text("ホーム画面の配置・設定・タイマー、ミニアプリのデータ、アイコンと壁紙の画像を 1 つのファイル（JSON）にまとめます。AI との会話は保存していないので含まれません。書き出したファイルは暗号化していないので、渡す相手に気をつけてください。")
        }
    }
}

/// 結果やエラーの知らせ。
@MainActor
struct BackupMessageSection: View {
    let message: BackupMessage
    let close: () -> Void

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
                Text(message.title)
                    .font(.headline)
                Text(message.text)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .id(message.id)
            Button("閉じる", action: close)
        }
    }
}

/// 作業中の表示（ページの真ん中に重ねる）。
@MainActor
struct BackupProgressView: View {
    let title: String

    var body: some View {
        ProgressView(title)
            .padding(DesignTokens.Spacing.large)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous))
    }
}
