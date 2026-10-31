import Foundation

/// 天気の取得・検索・登録の失敗の理由（F0306、F0308）。取得に失敗しても、前に取得した天気は消さずに表示を続ける。
enum WeatherError: Error, Hashable, Sendable {
    /// 通信がオフ（利用者がオンにしていない）。
    case networkDisabled
    case offline
    case timedOut
    case network(String)
    /// HTTP 429（利用回数の上限）。
    case rateLimited
    /// HTTP 5xx。
    case server(Int)
    /// HTTP 400（Open-Meteo が理由を返す）。
    case rejected(String)
    case badResponse(String)
    case queryTooShort
    case tooManyLocations

    var message: String {
        switch self {
        case .networkDisabled:
            return "天気の通信はオフです。オンにするまで、検索も更新もしません。"
        case .offline:
            return "インターネットに接続されていません。"
        case .timedOut:
            return "Open-Meteo から応答がありませんでした（時間切れ）。"
        case .network(let detail):
            return "Open-Meteo に接続できませんでした（\(detail)）。"
        case .rateLimited:
            return "Open-Meteo の利用回数の上限に達しました（無料の範囲は 1 分に 600 回、1 日に 1 万回まで）。しばらく待ってから更新してください。"
        case .server(let status):
            return "Open-Meteo が一時的に使えません（\(status)）。しばらく待ってから更新してください。"
        case .rejected(let reason):
            return "Open-Meteo が要求を受け付けませんでした（\(reason)）。"
        case .badResponse(let detail):
            return "Open-Meteo から読めない応答が返りました（\(detail)）。"
        case .queryTooShort:
            return "都市名を2文字以上入力してください。"
        case .tooManyLocations:
            return "登録できる場所は \(WeatherData.maximumLocations) か所までです。使わない場所を削除してください。"
        }
    }
}

/// 天気の通信（iPad では URLSession。テストでは固定の応答）。
protocol WeatherTransport: Sendable {
    func get(_ url: URL) async throws -> TransportResponse
}

/// 通信の失敗の種類。URLSession の URLError を、Core で扱える形にしたもの（Core は URLSession に依存しない）。
enum TransportFailure: Error, Hashable, Sendable {
    case offline
    case timedOut
    case cancelled
    case other(String)
}
