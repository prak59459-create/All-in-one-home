import Foundation

/// 天気を表示する場所（F0281、F0302、F0303）。都市名で検索して選ぶ（Open-Meteo の Geocoding API。元のデータは GeoNames）。
/// 端末の位置情報は使わない（F0283。位置情報の許可も求めない）。
struct WeatherLocation: Codable, Hashable, Sendable, Identifiable {
    static let maximumTextLength: Int = 100

    /// GeoNames の ID。同じ場所を二重に登録しないために使う。
    let id: Int
    let name: String
    /// 都道府県・州など。なければ空。
    let region: String
    let country: String
    let latitude: Double
    let longitude: Double
    /// IANA のタイムゾーン名（例: Asia/Tokyo）。分からなければ空。
    let timeZoneID: String

    /// 一覧の2行目（「東京都・日本」など）。名前と同じ地域名は繰り返さない。
    var detail: String {
        var parts: [String] = []
        if !region.isEmpty && region != name {
            parts.append(region)
        }
        if !country.isEmpty {
            parts.append(country)
        }
        return parts.joined(separator: "・")
    }

    var problems: [String] {
        var found: [String] = []
        if name.isEmpty || name.count > WeatherLocation.maximumTextLength
            || region.count > WeatherLocation.maximumTextLength || country.count > WeatherLocation.maximumTextLength
            || timeZoneID.count > WeatherLocation.maximumTextLength {
            found.append("場所（ID \(id)）の名前が空か、長すぎます。")
        }
        if !(-90.0...90.0).contains(latitude) || !(-180.0...180.0).contains(longitude) {
            found.append("場所（ID \(id)）の緯度・経度が範囲外です。")
        }
        return found
    }
}
