import Foundation

/// GitHub との通信。キャッシュを使わず（古い一覧で比べないため）、30 秒で打ち切る。
struct URLSessionTransport: UpdateTransport {
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
    }

    func get(_ url: URL) async throws -> TransportResponse {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("MyHome-SoftwareUpdate", forHTTPHeaderField: "User-Agent")
        let (data, response): (Data, URLResponse) = try await session.data(for: request)
        let status: Int = (response as? HTTPURLResponse)?.statusCode ?? 0
        return TransportResponse(status: status, data: data)
    }
}
