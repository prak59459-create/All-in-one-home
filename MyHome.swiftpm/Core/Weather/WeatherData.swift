import Foundation

/// 天気のデータ（Apps/weather.json）。通信の同意、単位、登録した場所、場所ごとの最後に取得した天気（F0307、F0319）。
/// 通信は既定でオフ（F0841）。オンにするまで、都市の検索も天気の取得もしない。
struct WeatherData: MiniAppContent {
    static let fileID: String = "weather"
    static let formatVersion: Int = 1
    static let maximumByteCount: Int = 2_000_000
    static let maximumLocations: Int = 10
    static let initial: WeatherData = WeatherData(
        isNetworkEnabled: false,
        temperatureUnit: .celsius,
        windSpeedUnit: .metersPerSecond,
        locations: [],
        selectedLocationID: nil,
        snapshots: []
    )

    /// Open-Meteo と通信してよいか。利用者がオンにするまで false。
    var isNetworkEnabled: Bool
    var temperatureUnit: TemperatureUnit
    var windSpeedUnit: WindSpeedUnit
    /// 登録した場所（並べた順）。
    var locations: [WeatherLocation]
    var selectedLocationID: Int?
    /// 場所ごとに、最後に取得できた天気（1か所に1つ）。
    var snapshots: [WeatherSnapshot]

    /// 表示する場所。選んだ場所が消えていたら先頭。
    var selectedLocation: WeatherLocation? {
        locations.first { (location: WeatherLocation) -> Bool in location.id == selectedLocationID } ?? locations.first
    }

    func snapshot(for locationID: Int) -> WeatherSnapshot? {
        snapshots.first { (snapshot: WeatherSnapshot) -> Bool in snapshot.locationID == locationID }
    }

    var problems: [String] {
        var found: [String] = []
        if locations.count > WeatherData.maximumLocations {
            found.append("登録された場所が多すぎます（\(locations.count) か所）。")
        }
        let ids: [Int] = locations.map { (location: WeatherLocation) -> Int in location.id }
        if Set(ids).count != ids.count {
            found.append("同じ場所が二重に登録されています。")
        }
        let snapshotIDs: [Int] = snapshots.map { (snapshot: WeatherSnapshot) -> Int in snapshot.locationID }
        if Set(snapshotIDs).count != snapshotIDs.count || snapshots.count > WeatherData.maximumLocations {
            found.append("保存された天気が重複しています。")
        }
        for location in locations {
            found.append(contentsOf: location.problems)
        }
        for snapshot in snapshots {
            found.append(contentsOf: snapshot.problems)
        }
        return found
    }

    /// 場所を登録して選ぶ。登録済みなら選ぶだけ。
    mutating func add(_ location: WeatherLocation) throws {
        if !locations.contains(where: { (existing: WeatherLocation) -> Bool in existing.id == location.id }) {
            guard locations.count < WeatherData.maximumLocations else { throw WeatherError.tooManyLocations }
            locations.append(location)
        }
        selectedLocationID = location.id
    }

    /// 場所を消す。その場所の天気も消し、選んでいた場所なら隣の場所を選ぶ。
    mutating func removeLocation(id: Int) {
        guard let index = locations.firstIndex(where: { (location: WeatherLocation) -> Bool in location.id == id }) else { return }
        locations.remove(at: index)
        snapshots.removeAll { (snapshot: WeatherSnapshot) -> Bool in snapshot.locationID == id }
        if selectedLocationID == id {
            selectedLocationID = locations.isEmpty ? nil : locations[min(index, locations.count - 1)].id
        }
    }

    /// 一覧での並べ替え（SwiftUI の onMove と同じ意味の位置）。
    mutating func moveLocations(fromOffsets source: IndexSet, toOffset destination: Int) {
        let valid: [Int] = source.filter { (offset: Int) -> Bool in offset >= 0 && offset < locations.count }
        guard !valid.isEmpty, destination >= 0, destination <= locations.count else { return }
        let moving: [WeatherLocation] = valid.map { (offset: Int) -> WeatherLocation in locations[offset] }
        var remaining: [WeatherLocation] = locations.enumerated().filter { (entry: (offset: Int, element: WeatherLocation)) -> Bool in
            !valid.contains(entry.offset)
        }.map { (entry: (offset: Int, element: WeatherLocation)) -> WeatherLocation in entry.element }
        let shift: Int = valid.filter { (offset: Int) -> Bool in offset < destination }.count
        remaining.insert(contentsOf: moving, at: destination - shift)
        locations = remaining
    }

    /// 取得した天気を保存する（その場所の古い天気と置き換える）。登録していない場所の天気は保存しない。
    mutating func store(_ snapshot: WeatherSnapshot) {
        guard locations.contains(where: { (location: WeatherLocation) -> Bool in location.id == snapshot.locationID }) else { return }
        snapshots.removeAll { (existing: WeatherSnapshot) -> Bool in existing.locationID == snapshot.locationID }
        snapshots.append(snapshot)
    }
}

/// 気温の単位（F0311）。
enum TemperatureUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case celsius
    case fahrenheit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .celsius: return "摂氏（°C）"
        case .fahrenheit: return "華氏（°F）"
        }
    }

    var symbol: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }
}

/// 風速の単位（F0312）。日本の天気予報と同じ m/s が既定。
enum WindSpeedUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case metersPerSecond
    case kilometersPerHour
    case milesPerHour

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .metersPerSecond: return "m/s"
        case .kilometersPerHour: return "km/h"
        case .milesPerHour: return "mph"
        }
    }
}
