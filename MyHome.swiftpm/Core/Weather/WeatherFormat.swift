import Foundation

/// 天気の値を表示用の文字にする。単位の換算もここで行う（保存する値は摂氏・km/h・mm のまま）。
/// 端末の言語設定によって形が変わらないよう、日付や数字は自分で組み立てる。
enum WeatherFormat {
    static let placeholder: String = "--"
    private static let weekdayNames: [String] = ["日", "月", "火", "水", "木", "金", "土"]
    private static let directionNames: [String] = [
        "北", "北北東", "北東", "東北東", "東", "東南東", "南東", "南南東",
        "南", "南南西", "南西", "西南西", "西", "西北西", "北西", "北北西"
    ]

    // MARK: - 単位の換算

    static func temperature(_ celsius: Double, in unit: TemperatureUnit) -> Double {
        switch unit {
        case .celsius: return celsius
        case .fahrenheit: return celsius * 9 / 5 + 32
        }
    }

    static func windSpeed(_ kilometersPerHour: Double, in unit: WindSpeedUnit) -> Double {
        switch unit {
        case .metersPerSecond: return kilometersPerHour / 3.6
        case .kilometersPerHour: return kilometersPerHour
        case .milesPerHour: return kilometersPerHour / 1.609344
        }
    }

    // MARK: - 文字

    /// 「12°」（整数に丸める）。
    static func temperatureText(_ celsius: Double?, unit: TemperatureUnit) -> String {
        guard let celsius else { return placeholder }
        return "\(Int(temperature(celsius, in: unit).rounded()))°"
    }

    /// 「3.2 m/s」（m/s は小数 1 桁、km/h と mph は整数）。
    static func windSpeedText(_ kilometersPerHour: Double?, unit: WindSpeedUnit) -> String {
        guard let kilometersPerHour else { return placeholder }
        let value: Double = windSpeed(kilometersPerHour, in: unit)
        switch unit {
        case .metersPerSecond: return String(format: "%.1f", value) + " " + unit.symbol
        case .kilometersPerHour, .milesPerHour: return "\(Int(value.rounded())) " + unit.symbol
        }
    }

    /// 風が吹いてくる方角を16方位で（0 度が北）。
    static func directionText(_ degrees: Double?) -> String? {
        guard let degrees, degrees.isFinite else { return nil }
        let normalized: Double = (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let index: Int = Int((normalized / 22.5).rounded()) % directionNames.count
        return directionNames[index]
    }

    /// 「北北東の風 3.2 m/s」。
    static func windText(_ kilometersPerHour: Double?, direction: Double?, unit: WindSpeedUnit) -> String {
        let speed: String = windSpeedText(kilometersPerHour, unit: unit)
        guard let name = directionText(direction) else { return speed }
        return "\(name)の風 \(speed)"
    }

    static func percentText(_ value: Double?) -> String {
        guard let value else { return placeholder }
        return "\(Int(value.rounded()))%"
    }

    static func precipitationText(_ millimeters: Double?) -> String {
        guard let millimeters else { return placeholder }
        return String(format: "%.1f", millimeters) + " mm"
    }

    /// UV 指数と、その強さ（気象庁の区分: 弱い・中程度・強い・非常に強い・極端に強い）。
    static func uvIndexText(_ index: Double?) -> String {
        guard let index else { return placeholder }
        let rounded: Int = Int(index.rounded())
        let level: String
        switch rounded {
        case ..<3: level = "弱い"
        case 3...5: level = "中程度"
        case 6...7: level = "強い"
        case 8...10: level = "非常に強い"
        default: level = "極端に強い"
        }
        return "\(rounded)（\(level)）"
    }

    // MARK: - 時刻（その土地の時刻で表示する）

    /// 「14時」。
    static func hourText(_ unixTime: Int, timeZone: TimeZone) -> String {
        let parts: DateComponents = components(unixTime, timeZone: timeZone)
        return "\(parts.hour ?? 0)時"
    }

    /// 「6:05」。
    static func clockText(_ unixTime: Int, timeZone: TimeZone) -> String {
        let parts: DateComponents = components(unixTime, timeZone: timeZone)
        return String(format: "%d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    /// 「今日」「明日」、それ以外は「11月2日（日）」。
    static func dayText(_ unixTime: Int, timeZone: TimeZone, now: Date) -> String {
        let calendar: Calendar = gregorian(timeZone)
        let date: Date = Date(timeIntervalSince1970: TimeInterval(unixTime))
        let today: Date = calendar.startOfDay(for: now)
        let day: Date = calendar.startOfDay(for: date)
        let difference: Int = calendar.dateComponents([.day], from: today, to: day).day ?? 0
        if difference == 0 {
            return "今日"
        }
        if difference == 1 {
            return "明日"
        }
        let parts: DateComponents = calendar.dateComponents([.month, .day, .weekday], from: date)
        let weekday: String = weekdayNames[((parts.weekday ?? 1) - 1 + 7) % 7]
        return "\(parts.month ?? 0)月\(parts.day ?? 0)日（\(weekday)）"
    }

    /// 取得してからの時間（「たった今」「5分前」「3時間前」「2日前」）。時計が戻った時は「たった今」。
    static func ageText(since fetched: Date, now: Date) -> String {
        let seconds: Int = max(0, Int(now.timeIntervalSince(fetched)))
        if seconds < 60 {
            return "たった今"
        }
        if seconds < 3_600 {
            return "\(seconds / 60)分前"
        }
        if seconds < 86_400 {
            return "\(seconds / 3_600)時間前"
        }
        return "\(seconds / 86_400)日前"
    }

    private static func gregorian(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private static func components(_ unixTime: Int, timeZone: TimeZone) -> DateComponents {
        gregorian(timeZone).dateComponents([.hour, .minute], from: Date(timeIntervalSince1970: TimeInterval(unixTime)))
    }
}
