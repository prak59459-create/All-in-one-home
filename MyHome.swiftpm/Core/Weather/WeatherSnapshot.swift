import Foundation

/// ある場所の、ある時点の天気と予報（F0284–F0300）。Open-Meteo の値をそのまま（摂氏・km/h・mm）持ち、
/// 表示する時に単位を換算する（単位を変えても取得し直さなくてよいように）。
/// 時刻は UNIX 時間（秒）。値がない時（その地域のモデルが出さない項目など）は nil。
struct WeatherSnapshot: Codable, Hashable, Sendable {
    static let maximumHourlyCount: Int = 400
    static let maximumDailyCount: Int = 20

    let locationID: Int
    /// 取得した時刻（端末の時計）。
    let fetchedAt: Int
    /// 予報の土地のタイムゾーン（Open-Meteo の timezone）。
    let timeZoneID: String
    let utcOffsetSeconds: Int
    let current: CurrentWeather
    let hourly: [HourlyWeather]
    let daily: [DailyWeather]

    var fetchedDate: Date {
        Date(timeIntervalSince1970: TimeInterval(fetchedAt))
    }

    /// 予報の時刻は、その土地の時刻で表示する。
    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneID) ?? TimeZone(secondsFromGMT: utcOffsetSeconds) ?? TimeZone.current
    }

    /// 今を含む1時間から先の、時間別の予報（最大 count 件）。古いデータなら空のことがある。
    func upcomingHours(from now: Date, count: Int) -> [HourlyWeather] {
        let nowSeconds: Int = Int(now.timeIntervalSince1970)
        let upcoming: [HourlyWeather] = hourly.filter { (hour: HourlyWeather) -> Bool in hour.time + 3_600 > nowSeconds }
        return Array(upcoming.prefix(count))
    }

    /// 今日から先の、日別の予報。
    func upcomingDays(from now: Date) -> [DailyWeather] {
        let nowSeconds: Int = Int(now.timeIntervalSince1970)
        // 日の長さは夏時間の切り替えで 23〜25 時間になるので、次の日の始まりで区切る
        return daily.enumerated().filter { (entry: (offset: Int, element: DailyWeather)) -> Bool in
            let end: Int = entry.offset + 1 < daily.count ? daily[entry.offset + 1].date : entry.element.date + 86_400
            return end > nowSeconds
        }.map { (entry: (offset: Int, element: DailyWeather)) -> DailyWeather in entry.element }
    }

    var problems: [String] {
        if hourly.count > WeatherSnapshot.maximumHourlyCount || daily.count > WeatherSnapshot.maximumDailyCount {
            return ["天気の予報（場所 ID \(locationID)）が多すぎます。"]
        }
        return []
    }
}

/// 今の天気（F0284–F0286、F0295–F0297）。
struct CurrentWeather: Codable, Hashable, Sendable {
    let time: Int
    /// 気温（℃）。
    let temperature: Double?
    /// 体感温度（℃）。
    let apparentTemperature: Double?
    /// 湿度（%）。
    let humidity: Double?
    /// 直前の降水量（mm）。
    let precipitation: Double?
    let weatherCode: Int?
    /// 風速（km/h）。
    let windSpeed: Double?
    /// 風が吹いてくる方角（度。0 が北、90 が東）。
    let windDirection: Double?
    let isDay: Bool?
}

/// 1時間ごとの予報（F0290、F0292、F0293）。
struct HourlyWeather: Codable, Hashable, Sendable, Identifiable {
    /// その1時間の始まり。
    let time: Int
    let temperature: Double?
    /// 降水確率（%）。
    let precipitationProbability: Double?
    /// 降水量（mm）。
    let precipitation: Double?
    let weatherCode: Int?
    let isDay: Bool?

    var id: Int { time }
}

/// 1日ごとの予報（F0287、F0288、F0291、F0298–F0300）。
struct DailyWeather: Codable, Hashable, Sendable, Identifiable {
    /// その日の始まり（その土地の 0 時）。
    let date: Int
    let weatherCode: Int?
    let temperatureMax: Double?
    let temperatureMin: Double?
    let precipitationSum: Double?
    let precipitationProbabilityMax: Double?
    let sunrise: Int?
    let sunset: Int?
    let uvIndexMax: Double?

    var id: Int { date }
}
