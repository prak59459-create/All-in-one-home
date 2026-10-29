import SwiftUI

/// 確認した差分と、書き込みの選択。
@MainActor
struct UpdatePlanSection: View {
    let plan: UpdatePlan
    @Bindable var controller: UpdateController

    var body: some View {
        Section {
            Text("コミット \(String(plan.snapshot.commitSHA.prefix(7)))（\(plan.snapshot.branch)）")
            if let status = controller.checkStatus {
                Label(status.message, systemImage: status == .passed ? "checkmark.seal" : "exclamationmark.triangle")
                    .foregroundStyle(status == .passed ? Color.green : Color.orange)
            }
            if plan.isUpToDate {
                Text("手元のファイルは、このコミットと同じです。書き込むものはありません。")
            } else {
                Text("追加 \(plan.additions.count)・変更 \(plan.modifications.count)・削除 \(plan.deletions.count)（同じ \(plan.unchangedCount)）")
                UpdateFileList(plan: plan)
            }
            options
        } header: {
            Text("確認の結果")
        }
    }

    @ViewBuilder
    private var options: some View {
        if !plan.locallyEdited.isEmpty {
            Toggle("手元で変更された \(plan.locallyEdited.count) 個のファイルも上書きする（上書き前に退避します）", isOn: $controller.selection.overwriteLocalEdits)
        }
        if plan.manifestChange != nil {
            Toggle("Package.swift も書き込む", isOn: $controller.selection.includeManifest)
            Text(manifestNote)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        if let status = controller.checkStatus, status != .passed, !plan.isUpToDate {
            Toggle("CI でビルドを確かめていないコミットでも書き込む", isOn: $controller.allowsUnverifiedCommit)
        }
        if !plan.untracked.isEmpty {
            DisclosureGroup("リポジトリにない手元のファイル（\(plan.untracked.count) 個。消しません）") {
                ForEach(plan.untracked, id: \.self) { path in
                    Text(path).font(.caption.monospaced())
                }
            }
        }
    }

    private var manifestNote: String {
        if plan.manifestLocallyEdited {
            return "Package.swift が手元で変更されています（Swift Playgrounds の「App 設定」を変えた時など）。書き込むと、名前・アイコン・権限などの設定が新しい版の内容になります。"
        }
        return "新しい版で権限などのアプリ設定が変わっています。書き込まないと、新しい機能が動かないことがあります。"
    }
}

@MainActor
struct UpdateFileList: View {
    let plan: UpdatePlan

    var body: some View {
        DisclosureGroup("ファイルの一覧") {
            ForEach(plan.additions, id: \.path) { file in
                row(file.path, mark: "追加")
            }
            ForEach(plan.modifications, id: \.path) { file in
                row(file.path, mark: plan.locallyEdited.contains(file.path) ? "変更（手元でも変更あり）" : "変更")
            }
            ForEach(plan.deletions, id: \.self) { path in
                row(path, mark: "削除")
            }
            if let manifest = plan.manifestChange {
                row(manifest.path, mark: "変更（選んだ時だけ）")
            }
        }
    }

    private func row(_ path: String, mark: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(path).font(.caption.monospaced())
            Text(mark).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

/// 進み具合・結果・失敗の表示と、書き込み後の手順。
@MainActor
struct UpdateStatusSection: View {
    let controller: UpdateController
    @Environment(PersistenceController.self) private var persistence

    var body: some View {
        switch controller.phase {
        case .idle, .planned:
            EmptyView()
        case .working(let text):
            Section {
                if let progress = controller.progress, progress.total > 0 {
                    ProgressView(text, value: Double(progress.done), total: Double(progress.total))
                } else {
                    ProgressView(text)
                }
            }
        case .installed(let result):
            Section("書き込みました") {
                Text("コミット \(String(result.commitSHA.prefix(7))) の \(result.written.count) 個のファイルを書き込み、\(result.deleted.count) 個を削除しました。")
                if !result.skipped.isEmpty {
                    Text("書き込まなかったファイル: \(result.skipped.joined(separator: "、"))")
                        .font(.footnote)
                }
                Text("新しい版にするには:\n1. Swift Playgrounds で ■（停止）を押す（または下のボタンで MyHome を終了）\n2. 左上からプロジェクトの一覧に戻り、MyHome を開き直す\n3. ▶ を押す（新しいファイルでビルドし直されます）")
                Button("MyHome を終了する") {
                    Task {
                        await persistence.flush()
                        exit(0)
                    }
                }
            }
        case .rolledBack(let text):
            Section("元に戻しました") {
                Text(text + " Swift Playgrounds で実行し直してください。")
            }
        case .failed(let text):
            Section {
                Label(text, systemImage: "xmark.octagon")
                    .foregroundStyle(.red)
            }
        }
    }
}
