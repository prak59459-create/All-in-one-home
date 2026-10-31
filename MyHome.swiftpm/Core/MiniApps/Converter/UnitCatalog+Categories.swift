/// 単位の一覧の中身。型推論の負荷を抑えるため、配列は要素型を明示して小さく分ける。
extension UnitCatalog {
    static let length = UnitCategory(id: "length", title: "長さ", symbolName: "ruler", units: lengthUnits())
    static let mass = UnitCategory(id: "mass", title: "重さ", symbolName: "scalemass", units: massUnits())
    static let temperature = UnitCategory(id: "temperature", title: "温度", symbolName: "thermometer.medium", units: temperatureUnits())
    static let area = UnitCategory(id: "area", title: "面積", symbolName: "square.dashed", units: areaUnits())
    static let volume = UnitCategory(id: "volume", title: "体積", symbolName: "drop", units: volumeUnits())
    static let speed = UnitCategory(id: "speed", title: "速さ", symbolName: "speedometer", units: speedUnits())
    static let time = UnitCategory(id: "time", title: "時間", symbolName: "clock", units: timeUnits())
    static let data = UnitCategory(id: "data", title: "データ量", symbolName: "internaldrive", units: dataUnits())

    private static func lengthUnits() -> [MeasureUnit] {
        let units: [MeasureUnit] = [
            make("length", "mm", "ミリメートル", "mm", 0.001),
            make("length", "cm", "センチメートル", "cm", 0.01),
            make("length", "m", "メートル", "m", 1),
            make("length", "km", "キロメートル", "km", 1000),
            make("length", "in", "インチ", "in", 0.0254),
            make("length", "ft", "フィート", "ft", 0.3048),
            make("length", "yd", "ヤード", "yd", 0.9144),
            make("length", "mi", "マイル", "mi", 1609.344),
            make("length", "nmi", "海里", "NM", 1852),
            make("length", "shaku", "尺", "尺", 10.0 / 33.0)
        ]
        return units
    }

    private static func massUnits() -> [MeasureUnit] {
        let units: [MeasureUnit] = [
            make("mass", "mg", "ミリグラム", "mg", 0.000001),
            make("mass", "g", "グラム", "g", 0.001),
            make("mass", "kg", "キログラム", "kg", 1),
            make("mass", "t", "トン", "t", 1000),
            make("mass", "oz", "オンス", "oz", 0.028349523125),
            make("mass", "lb", "ポンド", "lb", 0.45359237),
            make("mass", "kan", "貫", "貫", 3.75)
        ]
        return units
    }

    private static func temperatureUnits() -> [MeasureUnit] {
        let units: [MeasureUnit] = [
            MeasureUnit(id: "temperature.c", name: "セルシウス度", symbol: "℃", conversion: .affine(scale: 1, offset: 273.15)),
            MeasureUnit(id: "temperature.f", name: "ファーレンハイト度", symbol: "℉", conversion: .affine(scale: 5.0 / 9.0, offset: 459.67 * 5.0 / 9.0)),
            MeasureUnit(id: "temperature.k", name: "ケルビン", symbol: "K", conversion: .affine(scale: 1, offset: 0))
        ]
        return units
    }

    private static func areaUnits() -> [MeasureUnit] {
        let units: [MeasureUnit] = [
            make("area", "cm2", "平方センチメートル", "cm²", 0.0001),
            make("area", "m2", "平方メートル", "m²", 1),
            make("area", "a", "アール", "a", 100),
            make("area", "ha", "ヘクタール", "ha", 10_000),
            make("area", "km2", "平方キロメートル", "km²", 1_000_000),
            make("area", "ft2", "平方フィート", "ft²", 0.09290304),
            make("area", "ac", "エーカー", "ac", 4046.8564224),
            make("area", "tsubo", "坪", "坪", 400.0 / 121.0)
        ]
        return units
    }

    private static func volumeUnits() -> [MeasureUnit] {
        let units: [MeasureUnit] = [
            make("volume", "ml", "ミリリットル", "mL", 0.001),
            make("volume", "l", "リットル", "L", 1),
            make("volume", "m3", "立方メートル", "m³", 1000),
            make("volume", "tsp", "小さじ", "小さじ", 0.005),
            make("volume", "tbsp", "大さじ", "大さじ", 0.015),
            make("volume", "cup", "カップ（200 mL）", "カップ", 0.2),
            make("volume", "go", "合", "合", 2401.0 / 13310.0),
            make("volume", "gal", "米ガロン", "gal", 3.785411784),
            make("volume", "floz", "米液量オンス", "fl oz", 0.0295735295625)
        ]
        return units
    }

    private static func speedUnits() -> [MeasureUnit] {
        let units: [MeasureUnit] = [
            make("speed", "mps", "メートル毎秒", "m/s", 1),
            make("speed", "kmh", "キロメートル毎時", "km/h", 1000.0 / 3600.0),
            make("speed", "mph", "マイル毎時", "mph", 0.44704),
            make("speed", "kn", "ノット", "kn", 1852.0 / 3600.0)
        ]
        return units
    }

    private static func timeUnits() -> [MeasureUnit] {
        let units: [MeasureUnit] = [
            make("time", "ms", "ミリ秒", "ms", 0.001),
            make("time", "s", "秒", "秒", 1),
            make("time", "min", "分", "分", 60),
            make("time", "h", "時間", "時間", 3600),
            make("time", "d", "日", "日", 86_400),
            make("time", "w", "週", "週", 604_800),
            make("time", "y", "年（365 日）", "年", 31_536_000)
        ]
        return units
    }

    private static func dataUnits() -> [MeasureUnit] {
        let units: [MeasureUnit] = [
            make("data", "bit", "ビット", "bit", 0.125),
            make("data", "b", "バイト", "B", 1),
            make("data", "kb", "キロバイト", "KB", 1000),
            make("data", "mb", "メガバイト", "MB", 1_000_000),
            make("data", "gb", "ギガバイト", "GB", 1_000_000_000),
            make("data", "tb", "テラバイト", "TB", 1_000_000_000_000),
            make("data", "kib", "キビバイト", "KiB", 1024),
            make("data", "mib", "メビバイト", "MiB", 1_048_576),
            make("data", "gib", "ギビバイト", "GiB", 1_073_741_824)
        ]
        return units
    }

    private static func make(_ category: String, _ key: String, _ name: String, _ symbol: String, _ factor: Double) -> MeasureUnit {
        MeasureUnit(id: "\(category).\(key)", name: name, symbol: symbol, conversion: .linear(factor))
    }
}
