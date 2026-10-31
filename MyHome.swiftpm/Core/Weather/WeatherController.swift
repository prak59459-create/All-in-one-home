import Foundation
import Observation

/// 天気の画面の動き（F0304–F0308）。通信がオフの間は、検索も取得もしない（通信の入口をここに集め、テストで確かめる）。
/// 取得に失敗しても、前に取得した天気は消さずに表示を続け、失敗の理由を出す。
@MainActor
@Observable
final class WeatherController {
    /// 画面を開いた時・裏から戻った時に、これより古ければ取得し直す。
    static let staleInterval: TimeInterval = 30 * 60
    /// 更新ボタンを続けて押した時の最短の間隔（Open-Meteo に余計な負担をかけない）。
    static let minimumRefreshInterval: TimeInterval = 10

    private(set) var isRefreshing: Bool = false
    private(set) var isSearching: Bool = false
    /// 最後の取得の失敗。成功・場所の切り替え・通信のオフで消す。
    private(set) var lastError: WeatherError?
    private(set) var searchResults: [WeatherLocation] = []
    /// 検索の結果についての説明（見つからない・失敗など）。
    private(set) var searchMessage: String?

    @ObservationIgnored let document: MiniAppDocument<WeatherData>
    @ObservationIgnored private let client: OpenMeteoClient
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var lastAttempt: Date?
    @ObservationIgnored private var lastAttemptLocationID: Int?
    @ObservationIgnored private var searchGeneration: Int = 0

    init(document: MiniAppDocument<WeatherData>, client: OpenMeteoClient, now: @escaping () -> Date = Date.init) {
        self.document = document
        self.client = client
        self.now = now
    }

    var data: WeatherData {
        document.content
    }

    // MARK: - 通信の同意

    func enableNetwork() {
        document.update { (data: inout WeatherData) in
            data.isNetworkEnabled = true
        }
        lastError = nil
    }

    /// 通信をオフにする。deleteSavedWeather なら、保存した天気も消す（登録した場所は残す）。
    func disableNetwork(deleteSavedWeather: Bool) {
        document.update { (data: inout WeatherData) in
            data.isNetworkEnabled = false
            if deleteSavedWeather {
                data.snapshots = []
            }
        }
        searchGeneration += 1
        isSearching = false
        searchResults = []
        searchMessage = nil
        lastError = nil
    }

    // MARK: - 場所

    func search(_ text: String) async {
        searchGeneration += 1
        let generation: Int = searchGeneration
        guard document.isLoaded, data.isNetworkEnabled else {
            searchResults = []
            searchMessage = WeatherError.networkDisabled.message
            return
        }
        let query: String = OpenMeteoClient.normalizedQuery(text)
        guard query.count >= 2 else {
            searchResults = []
            searchMessage = WeatherError.queryTooShort.message
            return
        }
        isSearching = true
        let outcome: Result<[WeatherLocation], Error>
        do {
            outcome = .success(try await client.search(query))
        } catch {
            outcome = .failure(error)
        }
        // 後から始めた検索や、通信のオフがあれば、この結果は捨てる
        guard generation == searchGeneration else { return }
        isSearching = false
        switch outcome {
        case .success(let results):
            searchResults = results
            searchMessage = results.isEmpty ? "「\(query)」に当てはまる場所が見つかりませんでした。" : nil
        case .failure(let error):
            searchResults = []
            searchMessage = WeatherController.message(for: error)
        }
    }

    func clearSearch() {
        searchGeneration += 1
        isSearching = false
        searchResults = []
        searchMessage = nil
    }

    /// 場所を登録して選び、天気を取得する。登録できなければ理由を返す。
    @discardableResult
    func add(_ location: WeatherLocation) async -> String? {
        guard document.isLoaded else { return nil }
        do {
            try document.perform { (data: inout WeatherData) in
                try data.add(location)
            }
        } catch {
            return WeatherController.message(for: error)
        }
        clearSearch()
        lastError = nil
        await refresh(force: false)
        return nil
    }

    func select(_ id: Int) async {
        guard document.isLoaded, data.selectedLocation?.id != id else { return }
        document.update { (data: inout WeatherData) in
            data.selectedLocationID = id
        }
        lastError = nil
        await refresh(force: false)
    }

    func removeLocation(id: Int) {
        document.update { (data: inout WeatherData) in
            data.removeLocation(id: id)
        }
        lastError = nil
    }

    func moveLocations(fromOffsets source: IndexSet, toOffset destination: Int) {
        document.update { (data: inout WeatherData) in
            data.moveLocations(fromOffsets: source, toOffset: destination)
        }
    }

    // MARK: - 取得

    /// 表示中の場所の天気を取得する。force でなければ、新しい天気（30 分以内）がある時は取得しない。
    /// 通信がオフの時・場所がない時・取得中は何もしない。
    func refresh(force: Bool) async {
        guard document.isLoaded, data.isNetworkEnabled, !isRefreshing, let location = data.selectedLocation else { return }
        let current: Date = now()
        if !force, let saved = data.snapshot(for: location.id) {
            let age: TimeInterval = current.timeIntervalSince(saved.fetchedDate)
            if age >= 0 && age < WeatherController.staleInterval {
                return
            }
        }
        // 同じ場所を続けて取得しない（別の場所に切り替えた時は待たない）
        if let lastAttempt, lastAttemptLocationID == location.id {
            let interval: TimeInterval = current.timeIntervalSince(lastAttempt)
            if interval >= 0 && interval < WeatherController.minimumRefreshInterval {
                return
            }
        }
        lastAttempt = current
        lastAttemptLocationID = location.id
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let snapshot: WeatherSnapshot = try await client.forecast(for: location, now: current)
            // 取得している間に、通信がオフにされた・場所が消された時は保存しない
            guard data.isNetworkEnabled else { return }
            document.update { (data: inout WeatherData) in
                data.store(snapshot)
            }
            if data.selectedLocation?.id == location.id {
                lastError = nil
            }
        } catch is CancellationError {
            return
        } catch {
            if data.isNetworkEnabled && data.selectedLocation?.id == location.id {
                lastError = (error as? WeatherError) ?? .network(error.localizedDescription)
            }
        }
    }

    private static func message(for error: Error) -> String {
        if let weatherError = error as? WeatherError {
            return weatherError.message
        }
        return WeatherError.network(error.localizedDescription).message
    }
}
