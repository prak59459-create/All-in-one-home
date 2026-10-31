import Foundation

/// この先の雨の見通し（F0294）。時間別の降水確率と降水量から求める目安で、予報そのものではない。
enum RainOutlook: Hashable, Sendable {
    /// 今、雨や雪が降っている。
    case precipitatingNow(isSnow: Bool)
    /// この時刻ごろから降りそう（降水確率 50% 以上、または 0.5mm 以上）。
    case startsAround(time: Int, probability: Int?)
    /// この先 hours 時間は、降水確率 50% 以上の時間がない。
    case unlikely(hours: Int)
}

enum WeatherInsights {
    static let outlookHours: Int = 12
    static let likelyProbability: Double = 50
    static let likelyAmount: Double = 0.5

    /// 時間別の予報が足りない（古いデータなど）時は nil。
    static func rainOutlook(for snapshot: WeatherSnapshot, now: Date) -> RainOutlook? {
        let nowSeconds: Int = Int(now.timeIntervalSince1970)
        let isRecent: Bool = abs(nowSeconds - snapshot.current.time) < 3 * 3_600
        if isRecent, let code = snapshot.current.weatherCode {
            let condition = WeatherCondition(code: code)
            if condition.isPrecipitation {
                return .precipitatingNow(isSnow: condition.kind == .snow)
            }
        }
        let hours: [HourlyWeather] = snapshot.upcomingHours(from: now, count: outlookHours + 1).filter { (hour: HourlyWeather) -> Bool in
            hour.time > nowSeconds - 3_600 && hour.time <= nowSeconds + outlookHours * 3_600
        }
        guard hours.count >= outlookHours / 2 else { return nil }
        for hour in hours {
            let probability: Double = hour.precipitationProbability ?? 0
            let amount: Double = hour.precipitation ?? 0
            if probability >= likelyProbability || amount >= likelyAmount {
                return .startsAround(time: hour.time, probability: hour.precipitationProbability.map { (value: Double) -> Int in Int(value.rounded()) })
            }
        }
        return .unlikely(hours: outlookHours)
    }

    static func rainOutlookText(_ outlook: RainOutlook, timeZone: TimeZone) -> String {
        switch outlook {
        case .precipitatingNow(let isSnow):
            return isSnow ? "今、雪が降っています。" : "今、雨が降っています。"
        case .startsAround(let time, let probability):
            let hour: String = WeatherFormat.hourText(time, timeZone: timeZone)
            guard let probability else { return "\(hour)ごろから雨が降りそうです。" }
            return "\(hour)ごろから雨が降りそうです（降水確率 \(probability)%）。"
        case .unlikely(let hours):
            return "この先 \(hours) 時間は、降水確率 50% 以上の時間はありません。"
        }
    }

    /// 日別の予報の、最低気温の最小と最高気温の最大（週間の気温の棒の目盛り。F0316）。
    static func temperatureRange(of days: [DailyWeather]) -> ClosedRange<Double>? {
        let lows: [Double] = days.compactMap { (day: DailyWeather) -> Double? in day.temperatureMin }
        let highs: [Double] = days.compactMap { (day: DailyWeather) -> Double? in day.temperatureMax }
        guard let low = lows.min(), let high = highs.max(), low <= high else { return nil }
        return low...high
    }
}
