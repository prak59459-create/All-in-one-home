import SwiftUI
import UniformTypeIdentifiers

/// GGUF のモデルを選んで読み込み、1つのプロンプトに答えさせて、かかった時間と速さを表示する。
struct ContentView: View {
    @State private var model: PoCModel = PoCModel()
    @State private var prompt: String = "日本の首都はどこですか？一文で答えてください。"
    @State private var maxTokens: Int = 128
    @State private var isImporting: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                ModelSection(model: model, isImporting: $isImporting)
                PromptSection(model: model, prompt: $prompt, maxTokens: $maxTokens)
                OutputSection(model: model)
            }
            .navigationTitle("llama.cpp PoC")
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.data]) { (result: Result<URL, Error>) in
            if case .success(let url) = result {
                model.load(url: url)
            }
        }
    }
}

private struct ModelSection: View {
    let model: PoCModel
    @Binding var isImporting: Bool

    var body: some View {
        Section {
            if !model.modelName.isEmpty {
                LabeledContent("モデル", value: model.modelName)
            }
            Text(model.status)
                .foregroundStyle(.secondary)
            HStack {
                Button("GGUF ファイルを選ぶ") {
                    isImporting = true
                }
                .disabled(model.phase == .loading || model.phase == .generating)
                Spacer()
                if model.phase == .loading {
                    ProgressView()
                }
                if model.phase == .ready {
                    Button("解放する", role: .destructive) {
                        model.unload()
                    }
                }
            }
            .buttonStyle(.borderless)
        } header: {
            Text("モデル")
        } footer: {
            Text(model.memoryText)
        }
    }
}

private struct PromptSection: View {
    let model: PoCModel
    @Binding var prompt: String
    @Binding var maxTokens: Int

    var body: some View {
        Section("プロンプト") {
            TextField("質問", text: $prompt, axis: .vertical)
                .lineLimit(2...6)
            Stepper("生成の上限: \(maxTokens) トークン", value: $maxTokens, in: 16...1024, step: 16)
            HStack {
                Button("生成する") {
                    model.generate(prompt: prompt, maxTokens: maxTokens)
                }
                .disabled(model.phase != .ready || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
                if model.phase == .generating {
                    Button("止める", role: .destructive) {
                        model.stop()
                    }
                }
            }
            .buttonStyle(.borderless)
        }
    }
}

private struct OutputSection: View {
    let model: PoCModel

    var body: some View {
        Section("出力") {
            Text(model.output.isEmpty ? "（まだありません）" : model.output)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !model.report.isEmpty {
                Text(model.report)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}
