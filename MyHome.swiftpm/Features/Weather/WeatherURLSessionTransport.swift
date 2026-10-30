import Foundation

/// 天気の通信（Open-Meteo）。キャッシュは使わず（取得した時刻を正しく出すため）、15 秒で打ち切る。
/// URLSession の失敗は、Core で扱える TransportFailure に置き換える。
struct WeatherURLSessionTransport: WeatherTransport {
    /// URLSession は使い回す（画面を開くたびに作らない）。
    static let shared: WeatherURLSessionTransport = WeatherURLSessionTransport()

    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 15
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
    }

    func get(_ url: URL) async throws -> TransportResponse {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("MyHome-Weather", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response): (Data, URLResponse) = try await session.data(for: request)
            let status: Int = (response as? HTTPURLResponse)?.statusCode ?? 0
            return TransportResponse(status: status, data: data)
        } catch let error as URLError {
            throw WeatherURLSessionTransport.failure(for: error)
        }
    }

    private static func failure(for error: URLError) -> TransportFailure {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            return .offline
        case .timedOut:
            return .timedOut
        case .cancelled:
            return .cancelled
        default:
            return .other(error.localizedDescription)
        }
    }
}
