import Foundation
import XCTest
@testable import MyHomeCore

/// Phase 7: 天気の画面の動き。通信がオフの間は一度も通信しないこと、取得の間隔、失敗しても前の天気を残すこと。
/// 時計は TimerTests の TestClock を使う。
final class WeatherControllerTests: XCTestCase {
    @MainActor
    private func makeController(
        clock: TestClock,
        transport: FakeWeatherTransport
    ) async -> WeatherController {
        let library = MiniAppLibrary(makeStorage: { (_: String) -> (any HomeArchiveStorage)? in nil })
        let document: MiniAppDocument<WeatherData> = library.document(WeatherData.self)
        await document.load()
        return WeatherController(document: document, client: OpenMeteoClient(transport: transport), now: { clock.now })
    }

    private func forecastTransport() -> FakeWeatherTransport {
        FakeWeatherTransport { (url: URL) throws -> TransportResponse in
            if url.host == "geocoding-api.open-meteo.com" {
                return WeatherFixtures.ok(WeatherFixtures.searchJSON)
            }
            return WeatherFixtures.ok(WeatherFixtures.forecastJSON())
        }
    }

    private var startTime: Date {
        Date(timeIntervalSince1970: TimeInterval(WeatherFixtures.dayStart + 14 * 3_600 + 1_800))
    }

    @MainActor
    func testNothingIsSentUntilTheNetworkIsEnabled() async {
        let transport: FakeWeatherTransport = forecastTransport()
        let controller: WeatherController = await makeController(clock: TestClock(startTime), transport: transport)
        XCTAssertFalse(controller.data.isNetworkEnabled, "通信は既定でオフ")

        await controller.search("東京")
        XCTAssertEqual(controller.searchMessage, WeatherError.networkDisabled.message)
        XCTAssertTrue(controller.searchResults.isEmpty)

        // 前に登録した場所があっても、オフの間は取得しない
        controller.document.update { (data: inout WeatherData) in
            _ = try? data.add(WeatherFixtures.tokyo)
        }
        await controller.refresh(force: true)
        await controller.refresh(force: false)
        await controller.select(WeatherFixtures.tokyo.id)
        XCTAssertTrue(transport.requests.isEmpty, "通信がオフの間は一度も通信しない")
        XCTAssertNil(controller.lastError)

        controller.enableNetwork()
        await controller.refresh(force: false)
        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertEqual(transport.requests.first?.host, "api.open-meteo.com")
    }

    @MainActor
    func testSearchAddAndFetch() async throws {
        let transport: FakeWeatherTransport = forecastTransport()
        let controller: WeatherController = await makeController(clock: TestClock(startTime), transport: transport)
        controller.enableNetwork()

        await controller.search("東")
        XCTAssertEqual(controller.searchMessage, WeatherError.queryTooShort.message)
        XCTAssertTrue(transport.requests.isEmpty, "1文字では検索しない")

        await controller.search("東京")
        XCTAssertEqual(controller.searchResults.count, 2)
        XCTAssertNil(controller.searchMessage)
        XCTAssertFalse(controller.isSearching)

        let failure: String? = await controller.add(controller.searchResults[0])
        XCTAssertNil(failure)
        XCTAssertTrue(controller.searchResults.isEmpty, "登録したら検索の結果を閉じる")
        XCTAssertEqual(controller.data.selectedLocation?.id, WeatherFixtures.tokyo.id)
        let saved: WeatherSnapshot = try XCTUnwrap(controller.data.snapshot(for: WeatherFixtures.tokyo.id), "登録したらすぐ取得する")
        XCTAssertEqual(saved.current.temperature, 15.3)
        XCTAssertEqual(transport.requests.count, 2)
    }

    @MainActor
    func testEmptySearchResultsAreExplained() async {
        let transport = FakeWeatherTransport { (_: URL) throws -> TransportResponse in
            WeatherFixtures.ok(Data(#"{"generationtime_ms": 0.5}"#.utf8))
        }
        let controller: WeatherController = await makeController(clock: TestClock(startTime), transport: transport)
        controller.enableNetwork()
        await controller.search("ありえない地名")
        XCTAssertTrue(controller.searchResults.isEmpty)
        XCTAssertEqual(controller.searchMessage, "「ありえない地名」に当てはまる場所が見つかりませんでした。")
    }

    @MainActor
    func testFreshWeatherIsNotFetchedAgainAndRefreshIsThrottled() async {
        let clock = TestClock(startTime)
        let transport: FakeWeatherTransport = forecastTransport()
        let controller: WeatherController = await makeController(clock: clock, transport: transport)
        controller.enableNetwork()
        await controller.add(WeatherFixtures.tokyo)
        XCTAssertEqual(transport.requests.count, 1)

        clock.advance(by: 5 * 60)
        await controller.refresh(force: false)
        XCTAssertEqual(transport.requests.count, 1, "30 分以内の天気があれば、開き直しても取得しない")

        clock.advance(by: 1)
        await controller.refresh(force: true)
        XCTAssertEqual(transport.requests.count, 2, "更新ボタンなら取得する")
        clock.advance(by: 3)
        await controller.refresh(force: true)
        XCTAssertEqual(transport.requests.count, 2, "続けて押しても 10 秒は待つ")

        clock.advance(by: 31 * 60)
        await controller.refresh(force: false)
        XCTAssertEqual(transport.requests.count, 3, "30 分より古ければ取得し直す")
    }

    @MainActor
    func testSwitchingLocationsFetchesWithoutWaiting() async {
        let clock = TestClock(startTime)
        let transport: FakeWeatherTransport = forecastTransport()
        let controller: WeatherController = await makeController(clock: clock, transport: transport)
        controller.enableNetwork()
        await controller.add(WeatherFixtures.tokyo)
        await controller.add(WeatherFixtures.osaka)
        XCTAssertEqual(transport.requests.count, 2, "別の場所は 10 秒待たずに取得する")
        XCTAssertNotNil(controller.data.snapshot(for: WeatherFixtures.osaka.id))

        clock.advance(by: 60)
        await controller.select(WeatherFixtures.tokyo.id)
        XCTAssertEqual(transport.requests.count, 2, "前に取得した新しい天気があれば取得しない")
        XCTAssertEqual(controller.data.selectedLocation?.id, WeatherFixtures.tokyo.id)
    }

    @MainActor
    func testFailureKeepsThePreviousWeather() async throws {
        let clock = TestClock(startTime)
        let transport: FakeWeatherTransport = forecastTransport()
        let controller: WeatherController = await makeController(clock: clock, transport: transport)
        controller.enableNetwork()
        await controller.add(WeatherFixtures.tokyo)
        let before: WeatherSnapshot = try XCTUnwrap(controller.data.snapshot(for: WeatherFixtures.tokyo.id))

        transport.respond { (_: URL) throws -> TransportResponse in TransportResponse(status: 503, data: Data()) }
        clock.advance(by: 60)
        await controller.refresh(force: true)
        XCTAssertEqual(controller.lastError, .server(503))
        XCTAssertEqual(controller.data.snapshot(for: WeatherFixtures.tokyo.id), before, "失敗しても前の天気は消さない")

        transport.respond { (_: URL) throws -> TransportResponse in throw TransportFailure.offline }
        clock.advance(by: 60)
        await controller.refresh(force: true)
        XCTAssertEqual(controller.lastError, .offline)
        XCTAssertFalse(controller.isRefreshing)

        transport.respond { (_: URL) throws -> TransportResponse in WeatherFixtures.ok(WeatherFixtures.forecastJSON()) }
        clock.advance(by: 60)
        await controller.refresh(force: true)
        XCTAssertNil(controller.lastError, "取得できたら失敗の表示を消す")
        XCTAssertEqual(controller.data.snapshot(for: WeatherFixtures.tokyo.id)?.fetchedAt, Int(clock.now.timeIntervalSince1970))
    }

    @MainActor
    func testTurningTheNetworkOffCanDeleteSavedWeather() async {
        let transport: FakeWeatherTransport = forecastTransport()
        let controller: WeatherController = await makeController(clock: TestClock(startTime), transport: transport)
        controller.enableNetwork()
        await controller.add(WeatherFixtures.tokyo)
        XCTAssertEqual(controller.data.snapshots.count, 1)

        controller.disableNetwork(deleteSavedWeather: false)
        XCTAssertFalse(controller.data.isNetworkEnabled)
        XCTAssertEqual(controller.data.snapshots.count, 1, "残すを選んだら前の天気は表示し続ける")

        controller.enableNetwork()
        controller.disableNetwork(deleteSavedWeather: true)
        XCTAssertTrue(controller.data.snapshots.isEmpty)
        XCTAssertEqual(controller.data.locations, [WeatherFixtures.tokyo], "登録した場所は残す")
    }

    @MainActor
    func testRemovingTheSelectedLocation() async {
        let transport: FakeWeatherTransport = forecastTransport()
        let controller: WeatherController = await makeController(clock: TestClock(startTime), transport: transport)
        controller.enableNetwork()
        await controller.add(WeatherFixtures.tokyo)
        await controller.add(WeatherFixtures.osaka)
        controller.removeLocation(id: WeatherFixtures.osaka.id)
        XCTAssertEqual(controller.data.selectedLocation?.id, WeatherFixtures.tokyo.id)
        XCTAssertNil(controller.data.snapshot(for: WeatherFixtures.osaka.id))
        controller.moveLocations(fromOffsets: IndexSet(integer: 0), toOffset: 1)
        XCTAssertEqual(controller.data.locations.count, 1)
    }
}
