import SwiftUI
import UIKit

/// 電卓（F0504）。四則演算とかっこ、%、±。10 進数で計算するので 0.1 + 0.2 は 0.3 になる。
@MainActor
struct CalculatorAppView: View {
    @Environment(MiniAppLibrary.self) private var library

    var body: some View {
        let document: MiniAppDocument<CalculatorState> = library.document(CalculatorState.self)
        MiniAppScaffold(title: "電卓") {
            MiniAppHost(document: document) {
                CalculatorView(document: document)
            }
        }
    }
}

@MainActor
struct CalculatorView: View {
    let document: MiniAppDocument<CalculatorState>
    @State private var error: String?
    @State private var isShowingHistory: Bool = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            CalculatorDisplay(state: document.content, error: error)
            CalculatorKeypad(onPress: press, onEquals: evaluate)
        }
        .padding(DesignTokens.Spacing.medium)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingHistory = true
                } label: {
                    Label("履歴", systemImage: "clock.arrow.circlepath")
                }
            }
        }
        .sheet(isPresented: $isShowingHistory) {
            CalculatorHistoryView(document: document)
        }
    }

    private func press(_ key: CalculatorKey) {
        error = nil
        document.update { (state: inout CalculatorState) in
            state.press(key)
        }
    }

    private func evaluate() {
        var failure: CalculatorError?
        document.update { (state: inout CalculatorState) in
            failure = state.evaluate(now: Date(), id: CalculatorState.newRecordID())
        }
        error = failure?.message
    }
}

/// 表示部。上に途中結果、下に式または結果。長い時は文字を小さくする。
@MainActor
struct CalculatorDisplay: View {
    let state: CalculatorState
    let error: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xSmall) {
            Text(topText)
                .font(.title3)
                .foregroundStyle(error == nil ? Color.secondary : Color.red)
                .lineLimit(2)
            Text(state.mainText)
                .font(.system(size: 52, weight: .light, design: .rounded))
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.3)
                .textSelection(.enabled)
                .contextMenu {
                    Button("コピー", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = state.mainText.replacingOccurrences(of: ",", with: "")
                    }
                }
        }
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .bottomTrailing)
        .accessibilityElement(children: .combine)
    }

    /// エラーがあればその理由、なければ途中結果。どちらもなければ空白（高さを保つため）。
    private var topText: String {
        if let error {
            return error
        }
        if let preview = state.previewText {
            return "= " + preview
        }
        return " "
    }
}

/// 計算の履歴（新しい順、50 件まで）。タップすると、その結果を次の計算に使う。
@MainActor
struct CalculatorHistoryView: View {
    let document: MiniAppDocument<CalculatorState>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if document.content.history.isEmpty {
                    Text("履歴はまだありません。")
                        .foregroundStyle(.secondary)
                }
                ForEach(document.content.history) { (record: CalculationRecord) in
                    Button {
                        reuse(record)
                    } label: {
                        CalculationRecordRow(record: record)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("履歴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("消去", role: .destructive) {
                        document.update { (state: inout CalculatorState) in
                            state.clearHistory()
                        }
                    }
                    .disabled(document.content.history.isEmpty)
                }
            }
        }
    }

    private func reuse(_ record: CalculationRecord) {
        document.update { (state: inout CalculatorState) in
            state.reuse(record)
        }
        dismiss()
    }
}

@MainActor
struct CalculationRecordRow: View {
    let record: CalculationRecord

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(record.expression)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("= " + (DecimalText.parse(record.result).map(DecimalText.display) ?? record.result))
                .font(.title3)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .contentShape(Rectangle())
        .accessibilityHint("この結果を次の計算に使います")
    }
}
