/// 単位の換算の仕方。基準の単位（長さはメートルなど）との関係で表す。
enum UnitConversion: Hashable, Sendable {
    /// 値 × factor が基準の単位の値。
    case linear(Double)
    /// 値 × scale + offset が基準の単位の値（温度。基準はケルビン）。
    case affine(scale: Double, offset: Double)

    func toBase(_ value: Double) -> Double {
        switch self {
        case .linear(let factor): return value * factor
        case .affine(let scale, let offset): return value * scale + offset
        }
    }

    func fromBase(_ value: Double) -> Double {
        switch self {
        case .linear(let factor): return value / factor
        case .affine(let scale, let offset): return (value - offset) / scale
        }
    }
}

struct MeasureUnit: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let symbol: String
    let conversion: UnitConversion
}

struct UnitCategory: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    /// SF Symbols の名前。
    let symbolName: String
    let units: [MeasureUnit]
}

/// 単位の一覧（F0505）。値は国際単位系と計量法の定義による（尺貫法は 1 尺 = 10/33 m、1 坪 = 400/121 m²）。
enum UnitCatalog {
    static let categories: [UnitCategory] = [
        UnitCatalog.length, UnitCatalog.mass, UnitCatalog.temperature, UnitCatalog.area,
        UnitCatalog.volume, UnitCatalog.speed, UnitCatalog.time, UnitCatalog.data
    ]

    static func category(id: String) -> UnitCategory? {
        categories.first { (category: UnitCategory) -> Bool in category.id == id }
    }

    static func unit(id: String) -> MeasureUnit? {
        for category in categories {
            if let unit = category.units.first(where: { (unit: MeasureUnit) -> Bool in unit.id == id }) {
                return unit
            }
        }
        return nil
    }
}
