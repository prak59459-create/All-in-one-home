import SwiftUI

/// 読み込んだバックアップの中身と、戻すものの選択（F0819 プレビュー、F0820 確認、F0828 部分復元、F0829 全体復元、F0861）。
@MainActor
struct PendingRestoreSection: View {
    let controller: BackupController
    let pending: PendingRestore
    @State private var parts: Set<BackupPart>
    @State private var isConfirming: Bool = false

    init(controller: BackupController, pending: PendingRestore) {
        self.controller = controller
        self.pending = pending
        _parts = State(initialValue: pending.contents.allParts)
    }

    /// ページの一番上まで動かす時の目印。
    static func anchor(_ id: UUID) -> String {
        "pending-" + id.uuidString
    }

    var body: some View {
        Section {
            BackupOverviewRow(pending: pending)
                .id(PendingRestoreSection.anchor(pending.id))
            BackupPartToggle(title: "ホーム画面と設定", detail: homeDetail, part: .home, parts: $parts)
            ForEach(pending.contents.miniApps) { (entry: MiniAppBackupEntry) in
                BackupPartToggle(title: entry.title, detail: nil, part: .miniApp(entry.fileID), parts: $parts)
            }
            ForEach(notes, id: \.self) { (note: String) in
                Label(note, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            restoreButton
            Button("やめる") {
                controller.pending = nil
            }
        } header: {
            Text("読み込んだバックアップ")
        } footer: {
            Text("選んだものだけを、このバックアップの内容に置き換えます。選ばなかったものと、バックアップに入っていないミニアプリのデータは今のまま残ります。天気の通信のオン・オフは今の設定のまま、動いていたタイマーは止めた状態で戻ります。")
        }
    }

    private var restoreButton: some View {
        Button(role: .destructive) {
            isConfirming = true
        } label: {
            Label("復元する…", systemImage: "arrow.counterclockwise")
        }
        .disabled(parts.isEmpty)
        .alert("復元しますか？", isPresented: $isConfirming) {
            Button("復元する", role: .destructive) {
                let chosen: Set<BackupPart> = parts
                Task { await controller.restore(pending, parts: chosen) }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("今のデータは、復元の前に自動でこの iPad のバックアップ（復元の前）に残ります。")
        }
    }

    private var homeDetail: String {
        let summary: BackupSummary = pending.summary
        return summary.homeText + "\n" + summary.settingsText + "・画像 \(summary.imageCount) 枚"
    }

    private var notes: [String] {
        var lines: [String] = []
        let missing: Int = pending.contents.missingImageNames.count
        if missing > 0 {
            lines.append("画像 \(missing) 枚がバックアップに入っていないため、そのアイコンは記号で、壁紙はテーマの色で表示されます。")
        }
        let skipped: [String] = pending.contents.skippedPaths
        if !skipped.isEmpty {
            lines.append("この版の MyHome では使わないデータ（\(skipped.joined(separator: "、"))）は復元しません。")
        }
        return lines
    }
}

/// どこから読んだか・いつ作ったか・どの版か・大きさ（F0817、F0818）。
@MainActor
struct BackupOverviewRow: View {
    let pending: PendingRestore

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
            Text(pending.source)
                .font(.headline)
                .lineLimit(2)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var detail: String {
        let contents: BackupContents = pending.contents
        return "作成: \(BackupFormat.date(contents.createdAt))・MyHome \(contents.appVersion)・\(BackupFormat.size(contents.byteCount))"
    }
}

/// 戻すかどうかの切り替え 1 つ。
@MainActor
struct BackupPartToggle: View {
    let title: String
    let detail: String?
    let part: BackupPart
    @Binding var parts: Set<BackupPart>

    var body: some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var isOn: Binding<Bool> {
        Binding<Bool>(
            get: { parts.contains(part) },
            set: { (on: Bool) in
                if on {
                    parts.insert(part)
                } else {
                    parts.remove(part)
                }
            }
        )
    }
}

/// この iPad のバックアップの一覧（F0830–F0832）。
@MainActor
struct LocalBackupsSection: View {
    let controller: BackupController
    @State private var isConfirmingDeleteAll: Bool = false

    var body: some View {
        Section {
            if controller.backups.isEmpty {
                Text("まだありません。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(controller.backups) { (backup: LocalBackup) in
                    LocalBackupRow(backup: backup, controller: controller)
                }
                Button("すべて削除", role: .destructive) {
                    isConfirmingDeleteAll = true
                }
                .alert("この iPad のバックアップをすべて削除しますか？", isPresented: $isConfirmingDeleteAll) {
                    Button("削除", role: .destructive) {
                        controller.deleteAll()
                    }
                    Button("キャンセル", role: .cancel) {}
                } message: {
                    Text("削除したバックアップからは復元できません。")
                }
            }
        } header: {
            Text("この iPad のバックアップ")
        } footer: {
            Text("復元・消去の前に、自動で残します（新しい \(LocalBackupStore.maximumAutomatic) 個まで）。「この iPad に保存」で作ったものは \(LocalBackupStore.maximumManual) 個まで残せます。MyHome を削除すると一緒に消えます。")
        }
    }
}

/// 一覧の 1 行。… から、復元・書き出し・削除を選ぶ。
@MainActor
struct LocalBackupRow: View {
    let backup: LocalBackup
    let controller: BackupController
    @State private var isConfirmingDelete: Bool = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(BackupFormat.date(backup.createdAt))
                Text("\(backup.kind.title)・\(BackupFormat.size(backup.byteCount))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            actions
        }
        .alert("このバックアップを削除しますか？", isPresented: $isConfirmingDelete) {
            Button("削除", role: .destructive) {
                controller.delete(backup)
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("\(backup.kind.title)・\(BackupFormat.date(backup.createdAt))")
        }
    }

    private var actions: some View {
        Menu {
            Button {
                Task { await controller.inspect(backup) }
            } label: {
                Label("中身を確かめて復元", systemImage: "arrow.counterclockwise")
            }
            Button {
                Task { await controller.export(backup) }
            } label: {
                Label("ファイルに書き出す", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                Label("削除", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .imageScale(.large)
        }
        .accessibilityLabel("\(BackupFormat.date(backup.createdAt))のバックアップの操作")
    }
}
