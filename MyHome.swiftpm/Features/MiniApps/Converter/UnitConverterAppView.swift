import SwiftUI

/// 単位変換（F0505）。値と単位を選ぶと、同じ種類のすべての単位での値を並べる。
@MainActor
struct UnitConverterAppView: View {
    @Environment(MiniAppLibrary.self) private var library

    var body: some View {
        let document: MiniAppDocument<ConverterState> = library.document(ConverterState.self)
        MiniAppScaffold(title: "単位変換") {
            MiniAppHost(document: document) {
                UnitConverterView(document: document)
            }
        }
    }
}

@MainActor
struct UnitConverterView: View {
    let document: MiniAppDocument<ConverterState>

    var body: some View {
        let state: ConverterState = document.content
        Form {
            Section {
                Picker("種類", selection: categoryBinding) {
                    ForEach(UnitCatalog.categories) { (category: UnitCategory) in
                        Label(category.title, systemImage: category.symbolName).tag(category.id)
                    }
                }
                TextField("値", text: inputBinding)
                    .keyboardType(.numbersAndPunctuation)
                    .font(.title2.monospacedDigit())
                Picker("単位", selection: sourceBinding) {
                    ForEach(state.category.units) { (unit: MeasureUnit) in
                        Text("\(unit.name)（\(unit.symbol)）").tag(unit.id)
                    }
                }
            } footer: {
                Text("全角の数字や「,」の区切りもそのまま入力できます。")
            }
            ConversionResultsSection(results: state.results(), source: state.sourceUnit)
        }
    }

    private var categoryBinding: Binding<String> {
        Binding<String>(
            get: { document.content.category.id },
            set: { (id: String) in
                document.update { (state: inout ConverterState) in
                    state.selectCategory(id)
                }
            }
        )
    }

    private var sourceBinding: Binding<String> {
        Binding<String>(
            get: { document.content.sourceUnit.id },
            set: { (id: String) in
                document.update { (state: inout ConverterState) in
                    state.selectSourceUnit(id)
                }
            }
        )
    }

    private var inputBinding: Binding<String> {
        Binding<String>(
            get: { document.content.input },
            set: { (text: String) in
                document.update { (state: inout ConverterState) in
                    state.setInput(text)
                }
            }
        )
    }
}

@MainActor
struct ConversionResultsSection: View {
    let results: [ConversionResult]
    let source: MeasureUnit

    var body: some View {
        Section("換算した値") {
            if results.isEmpty {
                Text("数を入力してください。")
                    .foregroundStyle(.secondary)
            }
            ForEach(results) { (result: ConversionResult) in
                ConversionResultRow(result: result, isSource: result.unit.id == source.id)
            }
        }
    }
}

@MainActor
struct ConversionResultRow: View {
    let result: ConversionResult
    let isSource: Bool

    var body: some View {
        HStack {
            Text(result.unit.name)
                .foregroundStyle(isSource ? Color.secondary : Color.primary)
            Spacer()
            Text("\(result.text) \(result.unit.symbol)")
                .monospacedDigit()
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }
}
