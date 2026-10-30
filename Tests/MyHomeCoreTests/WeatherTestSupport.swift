import Foundation
@testable import MyHomeCore

/// 天気のテスト用の固定の応答（F0320）。通信した URL を記録する。
final class FakeWeatherTransport: WeatherTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var handler: (URL) throws -> TransportResponse
    private var recorded: [URL] = []

    init(handler: @escaping (URL) throws -> TransportResponse) {
        self.handler = handler
    }

    var requests: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func respond(with newHandler: @escaping (URL) throws -> TransportResponse) {
        lock.lock()
        handler = newHandler
        lock.unlock()
    }

    func get(_ url: URL) async throws -> TransportResponse {
        try record(url)(url)
    }

    /// 錠は同期の関数の中だけで使う（async の中で NSLock を直接使うと、Swift 6 では使えない）。
    private func record(_ url: URL) -> (URL) throws -> TransportResponse {
        lock.lock()
        defer { lock.unlock() }
        recorded.append(url)
        return handler
    }
}

enum WeatherFixtures {
    /// 2026-10-30 00:00（日本時間）。
    static let dayStart: Int = 1_793_286_000
    static let tokyo = WeatherLocation(
        id: 1_850_147,
        name: "東京",
        region: "東京都",
        country: "日本",
        latitude: 35.6895,
        longitude: 139.69171,
        timeZoneID: "Asia/Tokyo"
    )
    static let osaka = WeatherLocation(
        id: 1_853_909,
        name: "大阪市",
        region: "大阪府",
        country: "日本",
        latitude: 34.69374,
        longitude: 135.50218,
        timeZoneID: "Asia/Tokyo"
    )

    /// Open-Meteo の予報の応答（timeformat=unixtime、timezone=Asia/Tokyo）。時間別は dayStart から 168 時間、日別は 7 日。
    /// probabilities を渡すと、時間別の降水確率の先頭をその値にする（nil は JSON の null）。
    static func forecastJSON(
        currentTime: Int = dayStart + 14 * 3_600 + 1_800,
        currentCode: Int = 2,
        probabilities: [Int?] = [],
        hourlyCount: Int = 168,
        temperatureCount: Int? = nil,
        includeCurrent: Bool = true
    ) -> Data {
        let hours: [Int] = (0..<hourlyCount).map { (index: Int) -> Int in dayStart + index * 3_600 }
        let temperatures: [Any] = (0..<(temperatureCount ?? hourlyCount)).map { (index: Int) -> Any in
            index == 15 ? NSNull() : 10.0 + Double(index % 24) / 2
        }
        let probabilityColumn: [Any] = (0..<hourlyCount).map { (index: Int) -> Any in
            if index < probabilities.count {
                return probabilities[index].map { (value: Int) -> Any in value } ?? NSNull()
            }
            return 10
        }
        let days: [Int] = (0..<7).map { (index: Int) -> Int in dayStart + index * 86_400 }
        var root: [String: Any] = [
            "latitude": 35.7,
            "longitude": 139.6875,
            "generationtime_ms": 0.12,
            "utc_offset_seconds": 32_400,
            "timezone": "Asia/Tokyo",
            "timezone_abbreviation": "GMT+9",
            "elevation": 40.0,
            "hourly": [
                "time": hours,
                "temperature_2m": temperatures,
                "precipitation_probability": probabilityColumn,
                "precipitation": hours.map { (_: Int) -> Double in 0.0 },
                "weather_code": hours.map { (_: Int) -> Int in 3 },
                "is_day": hours.map { (time: Int) -> Int in ((time - dayStart) / 3_600) % 24 >= 6 && ((time - dayStart) / 3_600) % 24 < 17 ? 1 : 0 }
            ] as [String: Any],
            "daily": [
                "time": days,
                "weather_code": [2, 61, 3, 0, 1, 80, 71],
                "temperature_2m_max": [18.2, 16.0, 17.4, 19.9, 20.1, 15.5, 9.0],
                "temperature_2m_min": [9.8, 11.2, 10.0, 8.5, 9.1, 7.0, 1.5],
                "precipitation_sum": [0.0, 12.4, 0.2, 0.0, 0.0, 3.1, 4.0],
                "precipitation_probability_max": [20, 90, 30, 0, 10, 60, 70],
                "sunrise": days.map { (day: Int) -> Int in day + 6 * 3_600 + 300 },
                "sunset": days.map { (day: Int) -> Int in day + 16 * 3_600 + 50 * 60 },
                "uv_index_max": [3.4, 1.1, NSNull(), 4.0, 4.2, 2.0, 1.0] as [Any]
            ] as [String: Any]
        ]
        if includeCurrent {
            root["current"] = [
                "time": currentTime,
                "interval": 900,
                "temperature_2m": 15.3,
                "apparent_temperature": 13.9,
                "relative_humidity_2m": 62,
                "precipitation": 0.0,
                "weather_code": currentCode,
                "wind_speed_10m": 11.5,
                "wind_direction_10m": 23,
                "is_day": 1
            ] as [String: Any]
        }
        // テストの入力なので、作れなければテストが失敗する（空のデータを返す）
        return (try? JSONSerialization.data(withJSONObject: root)) ?? Data()
    }

    /// Open-Meteo の都市の検索の応答。2 件目は緯度がないので除かれる。
    static let searchJSON: Data = Data("""
    {
      "results": [
        {"id": 1850147, "name": "東京", "latitude": 35.6895, "longitude": 139.69171, "elevation": 44.0,
         "feature_code": "PPLC", "country_code": "JP", "admin1_id": 1850144, "timezone": "Asia/Tokyo",
         "population": 8336599, "country_id": 1861060, "country": "日本", "admin1": "東京都"},
        {"id": 1, "name": "緯度がない場所", "longitude": 1.0},
        {"id": 7, "name": "範囲外", "latitude": 95.0, "longitude": 1.0},
        {"id": 2128295, "name": "東京", "latitude": 43.0, "longitude": 141.3, "country": "日本"}
      ],
      "generationtime_ms": 0.9
    }
    """.utf8)

    static func ok(_ data: Data) -> TransportResponse {
        TransportResponse(status: 200, data: data)
    }
}
