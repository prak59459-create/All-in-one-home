import Foundation

/// Open-Meteo の応答（JSON）を、このアプリの型にする。項目ごとの値の配列は time の配列と同じ長さでなければ読まない。
/// ない項目（その地域のモデルが出さない値）は nil にする。
enum OpenMeteoDecoding {
    /// 予報の応答。保存する時間別の予報は、今を含む1時間から keptHours 時間分だけ。
    static func snapshot(from data: Data, locationID: Int, fetchedAt: Date, keptHours: Int) throws -> WeatherSnapshot {
        let decoded: ForecastJSON = try decode(ForecastJSON.self, from: data)
        guard let current = decoded.current else { throw WeatherError.badResponse("今の天気がありません") }
        let nowSeconds: Int = Int(fetchedAt.timeIntervalSince1970)
        let hours: [HourlyWeather] = try decoded.hourly.map { (hourly: HourlyJSON) -> [HourlyWeather] in try hourlyEntries(hourly) } ?? []
        let upcoming: [HourlyWeather] = hours.filter { (hour: HourlyWeather) -> Bool in hour.time + 3_600 > nowSeconds }
        return WeatherSnapshot(
            locationID: locationID,
            fetchedAt: nowSeconds,
            timeZoneID: decoded.timezone,
            utcOffsetSeconds: decoded.utcOffsetSeconds,
            current: CurrentWeather(
                time: try integer(current.time, "current.time"),
                temperature: current.temperature,
                apparentTemperature: current.apparentTemperature,
                humidity: current.humidity,
                precipitation: current.precipitation,
                weatherCode: code(current.weatherCode),
                windSpeed: current.windSpeed,
                windDirection: current.windDirection,
                isDay: flag(current.isDay)
            ),
            hourly: Array(upcoming.prefix(keptHours)),
            daily: try decoded.daily.map { (daily: DailyJSON) -> [DailyWeather] in try dailyEntries(daily) } ?? []
        )
    }

    /// 都市の検索の応答。当てはまる場所がない時は results がない。ID・名前・緯度・経度がない場所や、値が不正な場所は除く。
    static func locations(from data: Data) throws -> [WeatherLocation] {
        let decoded: SearchJSON = try decode(SearchJSON.self, from: data)
        let places: [PlaceJSON] = decoded.results ?? []
        return places.compactMap { (place: PlaceJSON) -> WeatherLocation? in
            guard let id = place.id, let name = place.name, let latitude = place.latitude, let longitude = place.longitude else {
                return nil
            }
            let location = WeatherLocation(
                id: id,
                name: name,
                region: place.admin1 ?? "",
                country: place.country ?? "",
                latitude: latitude,
                longitude: longitude,
                timeZoneID: place.timezone ?? ""
            )
            return location.problems.isEmpty ? location : nil
        }
    }

    /// HTTP 400 の時の {"error": true, "reason": "..."} の reason。
    static func errorReason(from data: Data) -> String? {
        guard let decoded = try? JSONDecoder().decode(ErrorJSON.self, from: data) else { return nil }
        return String(decoded.reason.prefix(200))
    }

    // MARK: - 変換

    private static func hourlyEntries(_ hourly: HourlyJSON) throws -> [HourlyWeather] {
        let count: Int = hourly.time.count
        let temperature: [Double?] = try column(hourly.temperature, count, "hourly.temperature_2m")
        let probability: [Double?] = try column(hourly.precipitationProbability, count, "hourly.precipitation_probability")
        let precipitation: [Double?] = try column(hourly.precipitation, count, "hourly.precipitation")
        let codes: [Double?] = try column(hourly.weatherCode, count, "hourly.weather_code")
        let isDay: [Double?] = try column(hourly.isDay, count, "hourly.is_day")
        var entries: [HourlyWeather] = []
        entries.reserveCapacity(count)
        for index in 0..<count {
            entries.append(HourlyWeather(
                time: try integer(hourly.time[index], "hourly.time"),
                temperature: temperature[index],
                precipitationProbability: probability[index],
                precipitation: precipitation[index],
                weatherCode: code(codes[index]),
                isDay: flag(isDay[index])
            ))
        }
        return entries
    }

    private static func dailyEntries(_ daily: DailyJSON) throws -> [DailyWeather] {
        let count: Int = daily.time.count
        guard count <= WeatherSnapshot.maximumDailyCount else { throw WeatherError.badResponse("日別の予報が多すぎます") }
        let codes: [Double?] = try column(daily.weatherCode, count, "daily.weather_code")
        let maximum: [Double?] = try column(daily.temperatureMax, count, "daily.temperature_2m_max")
        let minimum: [Double?] = try column(daily.temperatureMin, count, "daily.temperature_2m_min")
        let sum: [Double?] = try column(daily.precipitationSum, count, "daily.precipitation_sum")
        let probability: [Double?] = try column(daily.precipitationProbabilityMax, count, "daily.precipitation_probability_max")
        let sunrise: [Double?] = try column(daily.sunrise, count, "daily.sunrise")
        let sunset: [Double?] = try column(daily.sunset, count, "daily.sunset")
        let uvIndex: [Double?] = try column(daily.uvIndexMax, count, "daily.uv_index_max")
        var entries: [DailyWeather] = []
        for index in 0..<count {
            entries.append(DailyWeather(
                date: try integer(daily.time[index], "daily.time"),
                weatherCode: code(codes[index]),
                temperatureMax: maximum[index],
                temperatureMin: minimum[index],
                precipitationSum: sum[index],
                precipitationProbabilityMax: probability[index],
                sunrise: sunrise[index].flatMap { (value: Double) -> Int? in Int(exactly: value.rounded()) },
                sunset: sunset[index].flatMap { (value: Double) -> Int? in Int(exactly: value.rounded()) },
                uvIndexMax: uvIndex[index]
            ))
        }
        return entries
    }

    /// 値の配列。ない項目は全部 nil、長さが time と違えば読まない（ずれた値を別の時刻に表示しないため）。
    private static func column(_ values: [Double?]?, _ count: Int, _ name: String) throws -> [Double?] {
        guard let values else { return Array(repeating: nil, count: count) }
        guard values.count == count else { throw WeatherError.badResponse("\(name) の数が時刻の数と違います") }
        return values
    }

    private static func integer(_ value: Double, _ name: String) throws -> Int {
        guard let result = Int(exactly: value.rounded()) else { throw WeatherError.badResponse("\(name) が不正です") }
        return result
    }

    /// 天気コードは 0〜99 の整数。
    private static func code(_ value: Double?) -> Int? {
        guard let value, let result = Int(exactly: value.rounded()), (0...99).contains(result) else { return nil }
        return result
    }

    /// is_day は 1（昼）か 0（夜）。
    private static func flag(_ value: Double?) -> Bool? {
        value.map { (number: Double) -> Bool in number >= 0.5 }
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw WeatherError.badResponse("JSON を読めません")
        }
    }

    // MARK: - JSON の形

    private struct ForecastJSON: Decodable {
        let utcOffsetSeconds: Int
        let timezone: String
        let current: CurrentJSON?
        let hourly: HourlyJSON?
        let daily: DailyJSON?

        private enum CodingKeys: String, CodingKey {
            case utcOffsetSeconds = "utc_offset_seconds"
            case timezone
            case current
            case hourly
            case daily
        }
    }

    private struct CurrentJSON: Decodable {
        let time: Double
        let temperature: Double?
        let apparentTemperature: Double?
        let humidity: Double?
        let precipitation: Double?
        let weatherCode: Double?
        let windSpeed: Double?
        let windDirection: Double?
        let isDay: Double?

        private enum CodingKeys: String, CodingKey {
            case time
            case temperature = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case humidity = "relative_humidity_2m"
            case precipitation
            case weatherCode = "weather_code"
            case windSpeed = "wind_speed_10m"
            case windDirection = "wind_direction_10m"
            case isDay = "is_day"
        }
    }

    private struct HourlyJSON: Decodable {
        let time: [Double]
        let temperature: [Double?]?
        let precipitationProbability: [Double?]?
        let precipitation: [Double?]?
        let weatherCode: [Double?]?
        let isDay: [Double?]?

        private enum CodingKeys: String, CodingKey {
            case time
            case temperature = "temperature_2m"
            case precipitationProbability = "precipitation_probability"
            case precipitation
            case weatherCode = "weather_code"
            case isDay = "is_day"
        }
    }

    private struct DailyJSON: Decodable {
        let time: [Double]
        let weatherCode: [Double?]?
        let temperatureMax: [Double?]?
        let temperatureMin: [Double?]?
        let precipitationSum: [Double?]?
        let precipitationProbabilityMax: [Double?]?
        let sunrise: [Double?]?
        let sunset: [Double?]?
        let uvIndexMax: [Double?]?

        private enum CodingKeys: String, CodingKey {
            case time
            case weatherCode = "weather_code"
            case temperatureMax = "temperature_2m_max"
            case temperatureMin = "temperature_2m_min"
            case precipitationSum = "precipitation_sum"
            case precipitationProbabilityMax = "precipitation_probability_max"
            case sunrise
            case sunset
            case uvIndexMax = "uv_index_max"
        }
    }

    private struct SearchJSON: Decodable {
        let results: [PlaceJSON]?
    }

    private struct PlaceJSON: Decodable {
        let id: Int?
        let name: String?
        let latitude: Double?
        let longitude: Double?
        let timezone: String?
        let country: String?
        let admin1: String?
    }

    private struct ErrorJSON: Decodable {
        let reason: String
    }
}
