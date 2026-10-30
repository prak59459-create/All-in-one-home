import Foundation
import XCTest
@testable import MyHomeCore

/// Phase 7: Open-Meteo の応答の読み取り、URL、失敗の説明、単位と表示、雨の見通し、保存するデータ。
final class WeatherTests: XCTestCase {
    private let tokyoZone: TimeZone = TimeZone(identifier: "Asia/Tokyo") ?? TimeZone.current

    // MARK: - 送る内容

    func testForecastURLSendsOnlyCoordinatesAndVariables() throws {
        let url: URL = try XCTUnwrap(OpenMeteoClient.forecastURL(latitude: 35.68951234, longitude: 139.69171))
        let components: URLComponents = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "api.open-meteo.com")
        XCTAssertEqual(components.path, "/v1/forecast")
        let items: [String: String] = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { (item: URLQueryItem) -> (String, String) in
            (item.name, item.value ?? "")
        })
        XCTAssertEqual(items["latitude"], "35.6895", "緯度・経度は小数 4 桁まで")
        XCTAssertEqual(items["longitude"], "139.6917")
        XCTAssertEqual(items["timezone"], "auto")
        XCTAssertEqual(items["timeformat"], "unixtime")
        XCTAssertEqual(items["forecast_days"], "7")
        XCTAssertTrue(items["current"]?.contains("temperature_2m") == true)
        XCTAssertTrue(items["daily"]?.contains("uv_index_max") == true)
        XCTAssertEqual(
            Set(items.keys),
            ["latitude", "longitude", "current", "hourly", "daily", "timezone", "timeformat", "forecast_days"],
            "場所の名前や端末の情報は送らない"
        )
    }

    func testSearchURLEncodesTheQuery() throws {
        let url: URL = try XCTUnwrap(OpenMeteoClient.searchURL(query: "東京"))
        XCTAssertEqual(url.host, "geocoding-api.open-meteo.com")
        XCTAssertTrue(url.absoluteString.contains("name=%E6%9D%B1%E4%BA%AC"), url.absoluteString)
        XCTAssertTrue(url.absoluteString.contains("language=ja"))
        XCTAssertTrue(url.absoluteString.contains("count=10"))
        XCTAssertEqual(OpenMeteoClient.normalizedQuery("  大阪\n"), "大阪")
        XCTAssertEqual(OpenMeteoClient.normalizedQuery(String(repeating: "あ", count: 100)).count, OpenMeteoClient.maximumQueryLength)
    }

    // MARK: - 応答の読み取り

    func testForecastIsDecodedFromTheCurrentHour() throws {
        let now = Date(timeIntervalSince1970: TimeInterval(WeatherFixtures.dayStart + 14 * 3_600 + 1_800))
        let snapshot: WeatherSnapshot = try OpenMeteoDecoding.snapshot(
            from: WeatherFixtures.forecastJSON(),
            locationID: 42,
            fetchedAt: now,
            keptHours: 48
        )
        XCTAssertEqual(snapshot.locationID, 42)
        XCTAssertEqual(snapshot.timeZoneID, "Asia/Tokyo")
        XCTAssertEqual(snapshot.utcOffsetSeconds, 32_400)
        XCTAssertEqual(snapshot.fetchedAt, Int(now.timeIntervalSince1970))
        XCTAssertEqual(snapshot.current.temperature, 15.3)
        XCTAssertEqual(snapshot.current.humidity, 62)
        XCTAssertEqual(snapshot.current.weatherCode, 2)
        XCTAssertEqual(snapshot.current.windDirection, 23)
        XCTAssertEqual(snapshot.current.isDay, true)
        XCTAssertEqual(snapshot.hourly.count, 48, "今を含む1時間から 48 時間分だけ保存する")
        XCTAssertEqual(snapshot.hourly.first?.time, WeatherFixtures.dayStart + 14 * 3_600, "14:30 なら 14 時の予報から")
        XCTAssertNil(snapshot.hourly[1].temperature, "null は nil（15 時の気温）")
        XCTAssertEqual(snapshot.hourly[0].isDay, true)
        XCTAssertEqual(snapshot.hourly[4].isDay, false, "18 時は夜")
        XCTAssertEqual(snapshot.daily.count, 7)
        XCTAssertEqual(snapshot.daily[1].weatherCode, 61)
        XCTAssertEqual(snapshot.daily[1].precipitationProbabilityMax, 90)
        XCTAssertNil(snapshot.daily[2].uvIndexMax)
        XCTAssertEqual(snapshot.daily[0].sunrise, WeatherFixtures.dayStart + 6 * 3_600 + 300)
        XCTAssertTrue(snapshot.problems.isEmpty)
    }

    func testForecastWithMismatchedColumnsIsRejected() {
        let data: Data = WeatherFixtures.forecastJSON(temperatureCount: 100)
        XCTAssertThrowsError(try OpenMeteoDecoding.snapshot(from: data, locationID: 1, fetchedAt: Date(), keptHours: 48)) { (error: Error) in
            guard case .badResponse(let detail) = error as? WeatherError else { return XCTFail("\(error)") }
            XCTAssertTrue(detail.contains("temperature_2m"), "ずれた値を別の時刻に表示しない")
        }
    }

    func testForecastWithoutCurrentWeatherOrJSONIsRejected() {
        XCTAssertThrowsError(try OpenMeteoDecoding.snapshot(
            from: WeatherFixtures.forecastJSON(includeCurrent: false), locationID: 1, fetchedAt: Date(), keptHours: 48
        ))
        XCTAssertThrowsError(try OpenMeteoDecoding.snapshot(from: Data("<html>".utf8), locationID: 1, fetchedAt: Date(), keptHours: 48)) { (error: Error) in
            XCTAssertEqual(error as? WeatherError, .badResponse("JSON を読めません"))
        }
    }

    func testSearchResultsSkipBrokenPlaces() throws {
        let locations: [WeatherLocation] = try OpenMeteoDecoding.locations(from: WeatherFixtures.searchJSON)
        XCTAssertEqual(locations.map { (location: WeatherLocation) -> Int in location.id }, [1_850_147, 2_128_295])
        XCTAssertEqual(locations[0].detail, "東京都・日本")
        XCTAssertEqual(locations[0].timeZoneID, "Asia/Tokyo")
        XCTAssertEqual(locations[1].detail, "日本")
        XCTAssertEqual(try OpenMeteoDecoding.locations(from: Data(#"{"generationtime_ms": 1.0}"#.utf8)), [], "見つからない時は results がない")
    }

    // MARK: - 失敗の説明

    func testHTTPAndConnectionFailuresAreExplained() async {
        let cases: [(TransportResponse?, TransportFailure?, WeatherError)] = [
            (TransportResponse(status: 429, data: Data()), nil, .rateLimited),
            (TransportResponse(status: 503, data: Data()), nil, .server(503)),
            (TransportResponse(status: 400, data: Data(#"{"error": true, "reason": "Latitude must be in range of -90 to 90°."}"#.utf8)), nil,
             .rejected("Latitude must be in range of -90 to 90°.")),
            (TransportResponse(status: 302, data: Data()), nil, .badResponse("HTTP 302")),
            (nil, .offline, .offline),
            (nil, .timedOut, .timedOut),
            (nil, .other("TLS"), .network("TLS"))
        ]
        for (response, failure, expected) in cases {
            let transport = FakeWeatherTransport { (_: URL) throws -> TransportResponse in
                if let failure {
                    throw failure
                }
                return response ?? TransportResponse(status: 200, data: Data())
            }
            let client = OpenMeteoClient(transport: transport)
            do {
                _ = try await client.forecast(for: WeatherFixtures.tokyo, now: Date())
                XCTFail("失敗するはず: \(expected)")
            } catch {
                XCTAssertEqual(error as? WeatherError, expected)
                XCTAssertFalse((error as? WeatherError)?.message.isEmpty ?? true)
            }
        }
        XCTAssertTrue(WeatherError.rateLimited.message.contains("上限"), "利用回数の上限を伝える（F0308）")
    }

    func testShortQueryIsRejectedWithoutSending() async {
        let transport = FakeWeatherTransport { (_: URL) throws -> TransportResponse in WeatherFixtures.ok(WeatherFixtures.searchJSON) }
        let client = OpenMeteoClient(transport: transport)
        do {
            _ = try await client.search(" 東 ")
            XCTFail("1文字では検索しない")
        } catch {
            XCTAssertEqual(error as? WeatherError, .queryTooShort)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    // MARK: - 天気の名前と記号

    func testWeatherCodesHaveJapaneseNamesAndSymbols() {
        XCTAssertEqual(WeatherCondition(code: 0).title, "快晴")
        XCTAssertEqual(WeatherCondition(code: 0).symbolName(isDay: true), "sun.max.fill")
        XCTAssertEqual(WeatherCondition(code: 0).symbolName(isDay: false), "moon.stars.fill")
        XCTAssertEqual(WeatherCondition(code: 3).title, "くもり")
        XCTAssertEqual(WeatherCondition(code: 63).title, "雨")
        XCTAssertEqual(WeatherCondition(code: 75).kind, .snow)
        XCTAssertEqual(WeatherCondition(code: 99).symbolName(isDay: true), "cloud.hail.fill")
        XCTAssertTrue(WeatherCondition(code: 81).isPrecipitation)
        XCTAssertFalse(WeatherCondition(code: 45).isPrecipitation)
        XCTAssertEqual(WeatherCondition(code: 42).title, "不明（コード 42）")
        XCTAssertEqual(WeatherCondition(code: 42).kind, .unknown)
    }

    // MARK: - 単位と表示

    func testUnitsAreConvertedForDisplay() {
        XCTAssertEqual(WeatherFormat.temperature(100, in: .fahrenheit), 212, accuracy: 0.0001)
        XCTAssertEqual(WeatherFormat.temperatureText(0, unit: .fahrenheit), "32°")
        XCTAssertEqual(WeatherFormat.temperatureText(15.5, unit: .celsius), "16°")
        XCTAssertEqual(WeatherFormat.temperatureText(-0.4, unit: .celsius), "0°", "-0° と表示しない")
        XCTAssertEqual(WeatherFormat.temperatureText(nil, unit: .celsius), "--")
        XCTAssertEqual(WeatherFormat.windSpeedText(36, unit: .metersPerSecond), "10.0 m/s")
        XCTAssertEqual(WeatherFormat.windSpeedText(36, unit: .kilometersPerHour), "36 km/h")
        XCTAssertEqual(WeatherFormat.windSpeedText(16.09344, unit: .milesPerHour), "10 mph")
        XCTAssertEqual(WeatherFormat.windText(10.8, direction: 23, unit: .metersPerSecond), "北北東の風 3.0 m/s")
        XCTAssertEqual(WeatherFormat.percentText(62.4), "62%")
        XCTAssertEqual(WeatherFormat.precipitationText(12.44), "12.4 mm")
    }

    func testWindDirectionUsesSixteenPoints() {
        XCTAssertEqual(WeatherFormat.directionText(0), "北")
        XCTAssertEqual(WeatherFormat.directionText(22.5), "北北東")
        XCTAssertEqual(WeatherFormat.directionText(180), "南")
        XCTAssertEqual(WeatherFormat.directionText(270), "西")
        XCTAssertEqual(WeatherFormat.directionText(355), "北")
        XCTAssertEqual(WeatherFormat.directionText(-90), "西")
        XCTAssertEqual(WeatherFormat.directionText(720), "北")
        XCTAssertNil(WeatherFormat.directionText(nil))
        XCTAssertNil(WeatherFormat.directionText(.nan))
    }

    func testUVIndexUsesJMACategories() {
        XCTAssertEqual(WeatherFormat.uvIndexText(2.4), "2（弱い）")
        XCTAssertEqual(WeatherFormat.uvIndexText(5), "5（中程度）")
        XCTAssertEqual(WeatherFormat.uvIndexText(6.6), "7（強い）")
        XCTAssertEqual(WeatherFormat.uvIndexText(7.6), "8（非常に強い）")
        XCTAssertEqual(WeatherFormat.uvIndexText(11), "11（極端に強い）")
    }

    func testTimesAreShownInTheLocationsTimeZone() throws {
        let day: Int = WeatherFixtures.dayStart
        XCTAssertEqual(WeatherFormat.hourText(day + 14 * 3_600, timeZone: tokyoZone), "14時")
        XCTAssertEqual(WeatherFormat.hourText(day + 14 * 3_600, timeZone: try XCTUnwrap(TimeZone(identifier: "UTC"))), "5時")
        XCTAssertEqual(WeatherFormat.clockText(day + 6 * 3_600 + 300, timeZone: tokyoZone), "6:05")
        let now = Date(timeIntervalSince1970: TimeInterval(day + 10 * 3_600))
        XCTAssertEqual(WeatherFormat.dayText(day, timeZone: tokyoZone, now: now), "今日")
        XCTAssertEqual(WeatherFormat.dayText(day + 86_400, timeZone: tokyoZone, now: now), "明日")
        XCTAssertEqual(WeatherFormat.dayText(day + 2 * 86_400, timeZone: tokyoZone, now: now), "11月1日（日）")
    }

    func testAgeOfTheData() {
        let fetched = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(WeatherFormat.ageText(since: fetched, now: fetched.addingTimeInterval(30)), "たった今")
        XCTAssertEqual(WeatherFormat.ageText(since: fetched, now: fetched.addingTimeInterval(5 * 60)), "5分前")
        XCTAssertEqual(WeatherFormat.ageText(since: fetched, now: fetched.addingTimeInterval(3 * 3_600 + 59)), "3時間前")
        XCTAssertEqual(WeatherFormat.ageText(since: fetched, now: fetched.addingTimeInterval(2 * 86_400)), "2日前")
        XCTAssertEqual(WeatherFormat.ageText(since: fetched, now: fetched.addingTimeInterval(-600)), "たった今", "時計が戻っても負の時間を出さない")
    }

    // MARK: - 雨の見通し

    func testRainOutlookFindsTheFirstLikelyHour() throws {
        let now = Date(timeIntervalSince1970: TimeInterval(WeatherFixtures.dayStart + 14 * 3_600 + 1_800))
        let rainy: WeatherSnapshot = try snapshot(probabilities: Array(repeating: 10, count: 17) + [60], now: now)
        let outlook: RainOutlook? = WeatherInsights.rainOutlook(for: rainy, now: now)
        XCTAssertEqual(outlook, .startsAround(time: WeatherFixtures.dayStart + 17 * 3_600, probability: 60))
        XCTAssertEqual(WeatherInsights.rainOutlookText(try XCTUnwrap(outlook), timeZone: tokyoZone), "17時ごろから雨が降りそうです（降水確率 60%）。")

        let dry: WeatherSnapshot = try snapshot(probabilities: [], now: now)
        XCTAssertEqual(WeatherInsights.rainOutlook(for: dry, now: now), .unlikely(hours: 12))

        let raining: WeatherSnapshot = try snapshot(probabilities: [], currentCode: 63, now: now)
        XCTAssertEqual(WeatherInsights.rainOutlook(for: raining, now: now), .precipitatingNow(isSnow: false))
        let snowing: WeatherSnapshot = try snapshot(probabilities: [], currentCode: 73, now: now)
        XCTAssertEqual(WeatherInsights.rainOutlook(for: snowing, now: now), .precipitatingNow(isSnow: true))

        let later: Date = now.addingTimeInterval(3 * 86_400)
        XCTAssertNil(WeatherInsights.rainOutlook(for: dry, now: later), "古いデータからは見通しを出さない")
    }

    func testWeeklyTemperatureRange() throws {
        let now = Date(timeIntervalSince1970: TimeInterval(WeatherFixtures.dayStart))
        let days: [DailyWeather] = try snapshot(probabilities: [], now: now).upcomingDays(from: now)
        XCTAssertEqual(days.count, 7)
        let range: ClosedRange<Double> = try XCTUnwrap(WeatherInsights.temperatureRange(of: days))
        XCTAssertEqual(range.lowerBound, 1.5)
        XCTAssertEqual(range.upperBound, 20.1)
        XCTAssertNil(WeatherInsights.temperatureRange(of: []))
        let twoDaysLater: Date = now.addingTimeInterval(2 * 86_400 + 3_600)
        XCTAssertEqual(try snapshot(probabilities: [], now: now).upcomingDays(from: twoDaysLater).count, 5, "過ぎた日は出さない")
    }

    // MARK: - 保存するデータ

    func testLocationsCanBeAddedSelectedMovedAndRemoved() throws {
        var data: WeatherData = WeatherData.initial
        XCTAssertFalse(data.isNetworkEnabled, "通信は既定でオフ")
        try data.add(WeatherFixtures.tokyo)
        try data.add(WeatherFixtures.osaka)
        XCTAssertEqual(data.selectedLocation?.id, WeatherFixtures.osaka.id)
        try data.add(WeatherFixtures.tokyo)
        XCTAssertEqual(data.locations.count, 2, "同じ場所は二重に登録しない")
        XCTAssertEqual(data.selectedLocation?.id, WeatherFixtures.tokyo.id)

        data.moveLocations(fromOffsets: IndexSet(integer: 1), toOffset: 0)
        XCTAssertEqual(data.locations.map { (location: WeatherLocation) -> String in location.name }, ["大阪市", "東京"])
        data.moveLocations(fromOffsets: IndexSet(integer: 0), toOffset: 2)
        XCTAssertEqual(data.locations.map { (location: WeatherLocation) -> String in location.name }, ["東京", "大阪市"])

        let now = Date(timeIntervalSince1970: TimeInterval(WeatherFixtures.dayStart))
        let saved: WeatherSnapshot = try OpenMeteoDecoding.snapshot(
            from: WeatherFixtures.forecastJSON(), locationID: WeatherFixtures.tokyo.id, fetchedAt: now, keptHours: 48
        )
        data.store(saved)
        data.store(saved)
        XCTAssertEqual(data.snapshots.count, 1, "1か所に1つ")
        let stranger: WeatherSnapshot = try OpenMeteoDecoding.snapshot(
            from: WeatherFixtures.forecastJSON(), locationID: 99, fetchedAt: now, keptHours: 48
        )
        data.store(stranger)
        XCTAssertNil(data.snapshot(for: 99), "登録していない場所の天気は保存しない")

        data.removeLocation(id: WeatherFixtures.tokyo.id)
        XCTAssertEqual(data.selectedLocation?.id, WeatherFixtures.osaka.id, "選んでいた場所を消したら隣を選ぶ")
        XCTAssertTrue(data.snapshots.isEmpty, "消した場所の天気も消す")
    }

    func testLocationLimit() throws {
        var data: WeatherData = WeatherData.initial
        for index in 0..<WeatherData.maximumLocations {
            try data.add(location(id: index))
        }
        XCTAssertThrowsError(try data.add(location(id: 100))) { (error: Error) in
            XCTAssertEqual(error as? WeatherError, .tooManyLocations)
        }
        XCTAssertNoThrow(try data.add(location(id: 3)), "登録済みの場所は選び直せる")
        XCTAssertEqual(data.selectedLocation?.id, 3)
    }

    func testSavedDataRoundTripsAndBrokenDataIsRejected() throws {
        var data: WeatherData = WeatherData.initial
        data.isNetworkEnabled = true
        data.temperatureUnit = .fahrenheit
        try data.add(WeatherFixtures.tokyo)
        let now = Date(timeIntervalSince1970: TimeInterval(WeatherFixtures.dayStart))
        data.store(try OpenMeteoDecoding.snapshot(
            from: WeatherFixtures.forecastJSON(), locationID: WeatherFixtures.tokyo.id, fetchedAt: now, keptHours: 48
        ))
        let encoded: Data = try MiniAppArchiveCodec.encode(data)
        XCTAssertEqual(try MiniAppArchiveCodec.decode(WeatherData.self, from: encoded), data)

        var duplicated: WeatherData = data
        duplicated.locations.append(WeatherFixtures.tokyo)
        XCTAssertFalse(duplicated.problems.isEmpty)
        var invalid: WeatherData = WeatherData.initial
        invalid.locations = [WeatherLocation(id: 1, name: "北極の先", region: "", country: "", latitude: 91, longitude: 0, timeZoneID: "")]
        XCTAssertFalse(invalid.problems.isEmpty)
    }

    // MARK: - 補助

    private func snapshot(probabilities: [Int?], currentCode: Int = 2, now: Date) throws -> WeatherSnapshot {
        try OpenMeteoDecoding.snapshot(
            from: WeatherFixtures.forecastJSON(currentCode: currentCode, probabilities: probabilities),
            locationID: WeatherFixtures.tokyo.id,
            fetchedAt: Date(timeIntervalSince1970: TimeInterval(WeatherFixtures.dayStart)),
            keptHours: 48
        )
    }

    private func location(id: Int) -> WeatherLocation {
        WeatherLocation(id: id, name: "場所\(id)", region: "", country: "日本", latitude: 35, longitude: 135, timeZoneID: "Asia/Tokyo")
    }
}
