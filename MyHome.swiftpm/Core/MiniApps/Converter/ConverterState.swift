/// 単位変換（Apps/converter.json。F0505）。最後に使った種類・単位・入力を覚える。
struct ConverterState: MiniAppContent {
    static let fileID: String = "converter"
    static let formatVersion: Int = 1
    static let maximumByteCount: Int = 100_000
    static let initial: ConverterState = ConverterState(categoryID: "length", sourceUnitID: "length.m", input: "1")
    static let maximumInputLength: Int = 40

    var categoryID: String
    var sourceUnitID: String
    var input: String

    /// 単位の一覧が変わって見つからない ID は、読み込みを失敗にせず初めの単位を使う（resolved で直す）。
    var problems: [String] {
        input.count > ConverterState.maximumInputLength ? ["入力が長すぎます。"] : []
    }

    var category: UnitCategory {
        UnitCatalog.category(id: categoryID) ?? UnitCatalog.length
    }

    var sourceUnit: MeasureUnit {
        let units: [MeasureUnit] = category.units
        return units.first { (unit: MeasureUnit) -> Bool in unit.id == sourceUnitID } ?? units[0]
    }

    /// 種類を変える。単位はその種類の最初のもの（長さならメートルにしたいので、基準の単位があればそれ）。
    mutating func selectCategory(_ id: String) {
        guard let selected = UnitCatalog.category(id: id), selected.id != categoryID else { return }
        categoryID = selected.id
        let base: MeasureUnit? = selected.units.first { (unit: MeasureUnit) -> Bool in unit.conversion == .linear(1) }
        sourceUnitID = (base ?? selected.units[0]).id
    }

    mutating func selectSourceUnit(_ id: String) {
        guard category.units.contains(where: { (unit: MeasureUnit) -> Bool in unit.id == id }) else { return }
        sourceUnitID = id
    }

    mutating func setInput(_ text: String) {
        input = String(text.prefix(ConverterState.maximumInputLength))
    }

    /// 入力をすべての単位に換算した結果（読めない入力なら空）。
    func results() -> [ConversionResult] {
        guard let value = UnitConverter.parse(input) else { return [] }
        let source: MeasureUnit = sourceUnit
        return category.units.map { (unit: MeasureUnit) -> ConversionResult in
            ConversionResult(unit: unit, text: UnitConverter.format(UnitConverter.convert(value, from: source, to: unit)))
        }
    }
}

struct ConversionResult: Identifiable, Hashable, Sendable {
    let unit: MeasureUnit
    let text: String

    var id: String { unit.id }
}
