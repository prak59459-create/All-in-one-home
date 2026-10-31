import SwiftUI
import UIKit

/// テキストツール（F0511–F0514）。文字数を数え、整形・変換する。書いた文章は自動で保存する。
@MainActor
struct TextToolsAppView: View {
    @Environment(MiniAppLibrary.self) private var library

    var body: some View {
        let document: MiniAppDocument<TextToolsState> = library.document(TextToolsState.self)
        MiniAppScaffold(title: "テキストツール") {
            MiniAppHost(document: document) {
                TextToolsView(document: document)
            }
        }
    }
}

@MainActor
struct TextToolsView: View {
    let document: MiniAppDocument<TextToolsState>
    /// 直前の整形・変換の前の文章（「元に戻す」で戻す）。
    @State private var previous: String?
    @State private var message: String?
    @State private var isConfirmingClear: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: textBinding)
                .font(.body)
                .padding(.horizontal, DesignTokens.Spacing.small)
                .accessibilityLabel("文章")
            TextStatisticsBar(statistics: TextStatistics(document.content.text))
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                TextToolsMenu(onTransform: apply, onCodec: apply, onJSON: formatJSON)
                Button {
                    undo()
                } label: {
                    Label("元に戻す", systemImage: "arrow.uturn.backward")
                }
                .disabled(previous == nil)
                TextClipboardButtons(text: document.content.text, onPaste: replace, onClear: { isConfirmingClear = true })
            }
        }
        .confirmationDialog("文章をすべて消しますか？", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("消す", role: .destructive) {
                replace(with: "")
            }
        }
        .alert("テキストツール", isPresented: isShowingMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private var textBinding: Binding<String> {
        Binding<String>(
            get: { document.content.text },
            set: { (text: String) in
                setText(text)
            }
        )
    }

    private var isShowingMessage: Binding<Bool> {
        Binding<Bool>(
            get: { message != nil },
            set: { (isShown: Bool) in
                if !isShown {
                    message = nil
                }
            }
        )
    }

    private func setText(_ text: String) {
        var truncated: Bool = false
        document.update { (state: inout TextToolsState) in
            truncated = state.setText(text)
        }
        if truncated {
            message = "\(TextToolsState.maximumLength) 文字を超えた分は切り捨てました。"
        }
    }

    /// 整形・変換の結果で置き換える（前の文章を「元に戻す」用に覚える）。
    private func replace(with text: String) {
        previous = document.content.text
        setText(text)
    }

    private func apply(_ transform: TextTransform) {
        replace(with: transform.apply(document.content.text))
    }

    private func apply(_ codec: TextCodec) {
        switch codec.apply(document.content.text) {
        case .success(let text):
            replace(with: text)
        case .failure(let error):
            message = error.message
        }
    }

    private func formatJSON(_ style: JSONFormatter.Style) {
        switch JSONFormatter.format(document.content.text, style: style) {
        case .success(let text):
            replace(with: text)
        case .failure(let error):
            message = error.message
        }
    }

    private func undo() {
        guard let previous else { return }
        setText(previous)
        self.previous = nil
    }
}

/// 整形・変換のメニュー。
@MainActor
struct TextToolsMenu: View {
    let onTransform: @MainActor (TextTransform) -> Void
    let onCodec: @MainActor (TextCodec) -> Void
    let onJSON: @MainActor (JSONFormatter.Style) -> Void

    var body: some View {
        Menu {
            Section("整形") {
                ForEach(TextTransform.allCases) { (transform: TextTransform) in
                    Button(transform.title) {
                        onTransform(transform)
                    }
                }
            }
            Section("変換") {
                ForEach(TextCodec.allCases) { (codec: TextCodec) in
                    Button(codec.title) {
                        onCodec(codec)
                    }
                }
            }
            Section("JSON") {
                Button("JSON を読みやすく整形") {
                    onJSON(.pretty)
                }
                Button("JSON を1行に詰める") {
                    onJSON(.compact)
                }
            }
        } label: {
            Label("整形・変換", systemImage: "wand.and.stars")
        }
    }
}

/// コピー・貼り付け・消去。貼り付けは PasteButton を使い、他のアプリの内容を勝手に読まない（読む時は iPadOS が確認する）。
@MainActor
struct TextClipboardButtons: View {
    let text: String
    let onPaste: @MainActor (String) -> Void
    let onClear: @MainActor () -> Void

    var body: some View {
        Button {
            UIPasteboard.general.string = text
        } label: {
            Label("すべてコピー", systemImage: "doc.on.doc")
        }
        .disabled(text.isEmpty)
        PasteButton(payloadType: String.self) { (strings: [String]) in
            guard let first = strings.first else { return }
            Task { @MainActor in
                onPaste(first)
            }
        }
        .labelStyle(.iconOnly)
        Button(role: .destructive) {
            onClear()
        } label: {
            Label("すべて消す", systemImage: "trash")
        }
        .disabled(text.isEmpty)
    }
}

/// 文字数などの数（F0514）。
@MainActor
struct TextStatisticsBar: View {
    let statistics: TextStatistics

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.medium) {
                StatisticItem(label: "文字", value: statistics.characters)
                StatisticItem(label: "空白・改行を除く", value: statistics.charactersExcludingWhitespace)
                StatisticItem(label: "行", value: statistics.lines)
                StatisticItem(label: "語", value: statistics.words)
                StatisticItem(label: "バイト（UTF-8）", value: statistics.utf8Bytes)
                StatisticItem(label: "原稿用紙（目安）", value: statistics.manuscriptPages)
            }
            .padding(.horizontal, DesignTokens.Spacing.medium)
            .padding(.vertical, DesignTokens.Spacing.small)
        }
        .background(.bar)
    }
}

@MainActor
struct StatisticItem: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value, format: .number)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
