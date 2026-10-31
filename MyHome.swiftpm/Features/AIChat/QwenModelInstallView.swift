import SwiftUI

/// Qwen のモデルを入れる（取得・コンパイル）。AI の画面で Qwen を選び、まだ入っていない時に出す。
/// 取得は利用者がボタンを押した時だけ行う（通信する。大きさは QwenModelManifest.totalSize。Wi-Fi をすすめる）。
@MainActor
struct QwenModelInstallView: View {
    let onInstalled: () -> Void
    @State private var installer: QwenModelInstaller?
    @State private var isConfirming: Bool = false

    init(onInstalled: @escaping () -> Void) {
        self.onInstalled = onInstalled
        _installer = State(initialValue: QwenModelSupport.makeInstaller())
    }

    var body: some View {
        if let installer {
            QwenInstallPanel(installer: installer, isConfirming: $isConfirming, onInstalled: onInstalled)
        } else {
            Label("保存先を用意できないため、モデルを入れられません。", systemImage: "exclamationmark.triangle")
                .font(.footnote)
        }
    }
}

@MainActor
struct QwenInstallPanel: View {
    let installer: QwenModelInstaller
    @Binding var isConfirming: Bool
    let onInstalled: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            status
            buttons
        }
        .onChange(of: installer.state) { (_: QwenModelInstaller.State, state: QwenModelInstaller.State) in
            if state == .installed {
                onInstalled()
            }
        }
        .alert("モデルを入れますか？", isPresented: $isConfirming) {
            Button("入れる") {
                Task { await installer.install() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text(confirmation)
        }
    }

    private var confirmation: String {
        var text: String = "GitHub（このアプリのリポジトリ）から、Qwen2.5 0.5B のモデル（約 \(QwenModelSupport.sizeText)）を取得し、この iPad の中で使える形にします。"
            + "Wi-Fi をおすすめします。取得したモデルは、AI との会話をどこにも送りません。"
        if !QwenModelSupport.hasEnoughSpace() {
            text += "\n空き容量が足りないかもしれません（約 \(BackupFormat.size(QwenModelManifest.requiredSpace)) 必要）。"
        }
        return text
    }

    @ViewBuilder
    private var status: some View {
        switch installer.state {
        case .notInstalled:
            Text("モデルはまだ入っていません（約 \(QwenModelSupport.sizeText)。取得は 1 回だけ）。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .checking:
            ProgressView("取得するファイルを確かめています…")
        case .downloading(let file, let total, let bytes):
            ProgressView(value: Double(bytes), total: Double(max(QwenModelManifest.totalSize, 1))) {
                Text("取得しています（\(file) / \(total)、\(BackupFormat.size(bytes))）")
            }
        case .compiling(let model, let total):
            ProgressView(value: Double(model), total: Double(total)) {
                Text("この iPad で使える形にしています（\(model) / \(total)）")
            }
        case .installed:
            Label("モデルを入れました。「読み込む」で使えます。", systemImage: "checkmark.circle")
                .font(.footnote)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var buttons: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            if installer.isWorking {
                Button("止める") {
                    installer.cancel()
                }
                .buttonStyle(.bordered)
            } else if installer.state != .installed {
                Button {
                    isConfirming = true
                } label: {
                    Label("モデルを入れる", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
