import Foundation

/// Open-Meteo（https://open-meteo.com/ ）から天気の予報を取得し、都市を検索する（F0309、F0310）。
/// API キーもアカウントもいらない（無料・非商用の範囲）。送るのは、検索する文字と、選んだ場所の緯度・経度だけ。
/// 別の天気サービスに替える時は、この型と同じ形（search と forecast）のものを作って WeatherController に渡す。
struct OpenMeteoClient: Sendable {
    static let forecastEndpoint: String = "https://api.open-meteo.com/v1/forecast"
    static let searchEndpoint: String = "https://geocoding-api.open-meteo.com/v1/search"
    static let maximumResponseSize: Int = 2_000_000
    static let maximumQueryLength: Int = 60
    /// 保存する時間別の予報の長さ（時間）。
    static let keptHourCount: Int = 48

    let transport: any WeatherTransport

    /// 検索する文字（前後の空白を除き、長すぎる分は切る）。
    static func normalizedQuery(_ text: String) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maximumQueryLength))
    }

    static func searchURL(query: String) -> URL? {
        var components: URLComponents? = URLComponents(string: searchEndpoint)
        components?.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "10"),
            URLQueryItem(name: "language", value: "ja"),
            URLQueryItem(name: "format", value: "json")
        ]
        return components?.url
    }

    /// 時刻は UNIX 時間で受け取り、日の区切りと日の出・日の入りはその土地のタイムゾーン（timezone=auto）で計算させる。
    static func forecastURL(latitude: Double, longitude: Double) -> URL? {
        var components: URLComponents? = URLComponents(string: forecastEndpoint)
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: coordinateText(latitude)),
            URLQueryItem(name: "longitude", value: coordinateText(longitude)),
            URLQueryItem(
                name: "current",
                value: "temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,weather_code,wind_speed_10m,wind_direction_10m,is_day"
            ),
            URLQueryItem(name: "hourly", value: "temperature_2m,precipitation_probability,precipitation,weather_code,is_day"),
            URLQueryItem(
                name: "daily",
                value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,sunrise,sunset,uv_index_max"
            ),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "forecast_days", value: "7")
        ]
        return components?.url
    }

    /// 都市を検索する（2文字以上）。見つからなければ空。
    func search(_ text: String) async throws -> [WeatherLocation] {
        let query: String = OpenMeteoClient.normalizedQuery(text)
        guard query.count >= 2 else { throw WeatherError.queryTooShort }
        guard let url = OpenMeteoClient.searchURL(query: query) else { throw WeatherError.badResponse("検索の URL を作れません") }
        return try OpenMeteoDecoding.locations(from: try await fetch(url))
    }

    /// 場所の天気と予報を取得する。
    func forecast(for location: WeatherLocation, now: Date) async throws -> WeatherSnapshot {
        guard let url = OpenMeteoClient.forecastURL(latitude: location.latitude, longitude: location.longitude) else {
            throw WeatherError.badResponse("予報の URL を作れません")
        }
        return try OpenMeteoDecoding.snapshot(
            from: try await fetch(url),
            locationID: location.id,
            fetchedAt: now,
            keptHours: OpenMeteoClient.keptHourCount
        )
    }

    private func fetch(_ url: URL) async throws -> Data {
        let response: TransportResponse
        do {
            response = try await transport.get(url)
        } catch let failure as TransportFailure {
            switch failure {
            case .offline: throw WeatherError.offline
            case .timedOut: throw WeatherError.timedOut
            case .cancelled: throw CancellationError()
            case .other(let detail): throw WeatherError.network(detail)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw WeatherError.network(error.localizedDescription)
        }
        guard response.data.count <= OpenMeteoClient.maximumResponseSize else {
            throw WeatherError.badResponse("応答が大きすぎます")
        }
        switch response.status {
        case 200:
            return response.data
        case 400:
            throw WeatherError.rejected(OpenMeteoDecoding.errorReason(from: response.data) ?? "400")
        case 429:
            throw WeatherError.rateLimited
        case 500...599:
            throw WeatherError.server(response.status)
        default:
            throw WeatherError.badResponse("HTTP \(response.status)")
        }
    }

    /// 緯度・経度は小数 4 桁（約 10m）。それより細かい位置は送らない。
    private static func coordinateText(_ value: Double) -> String {
        String(format: "%.4f", value)
    }
}
