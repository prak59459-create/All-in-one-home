import Foundation
import XCTest
@testable import MyHomeCore

/// Phase 9: バックアップの画面の状態（BackupController）、このアプリについて、設定の中のページを開く起動引数。
final class BackupControllerTests: XCTestCase {
    private var directory: URL!
    private let fixed = Date(timeIntervalSince1970: 1_793_275_200)

    override func setUpWithError() throws {
        directory = try MigrationFixtureTests.makeDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    @MainActor
    func testExportSaveInspectAndRestoreFlow() async throws {
        let session: AppSession = makeSession()
        let controller = BackupController(session: session)
        XCTAssertNil(controller.unavailableReason)

        await controller.prepareExport()
        let export: BackupExportFile = try XCTUnwrap(controller.exportFile)
        XCTAssertTrue(export.fileName.hasPrefix("MyHome-backup-"))
        XCTAssertTrue(export.fileName.hasSuffix(".json"))
        XCTAssertNil(controller.message, "含めなかったものがなければ、知らせは出さない")

        await controller.saveOnDevice()
        XCTAssertEqual(controller.message?.title, "保存しました")
        XCTAssertEqual(controller.backups.map { (backup: LocalBackup) -> LocalBackup.Kind in backup.kind }, [.manual])

        // 書き出したものを読み込んで、テーマを変えた後に復元する
        session.boot.settings.themeID = "sunset"
        await controller.inspect(export.data, source: export.fileName)
        let pending: PendingRestore = try XCTUnwrap(controller.pending)
        XCTAssertEqual(pending.source, export.fileName)
        XCTAssertEqual(pending.contents.home.settings.themeID, ThemeCatalog.defaultID)

        let restored: Bool = await controller.restore(pending, parts: pending.contents.allParts)
        XCTAssertTrue(restored)
        XCTAssertNil(controller.pending)
        XCTAssertEqual(controller.message?.title, "復元しました")
        XCTAssertEqual(session.boot.settings.themeID, ThemeCatalog.defaultID)
        let kinds: [LocalBackup.Kind] = controller.backups.map { (backup: LocalBackup) -> LocalBackup.Kind in backup.kind }
        XCTAssertEqual(kinds.sorted { (lhs: LocalBackup.Kind, rhs: LocalBackup.Kind) -> Bool in lhs.rawValue < rhs.rawValue }, [.beforeRestore, .manual])
        XCTAssertEqual(controller.activity, .idle)
    }

    @MainActor
    func testUnusableFilesShowAReasonAndChangeNothing() async throws {
        let session: AppSession = makeSession()
        let controller = BackupController(session: session)
        await controller.inspect(Data("ただの文章".utf8), source: "memo.txt")
        XCTAssertNil(controller.pending)
        XCTAssertEqual(controller.message?.title, "このバックアップは使えません")
        XCTAssertEqual(controller.message?.text, BackupError.notABackup.message)
        XCTAssertEqual(session.generation, 0)
    }

    @MainActor
    func testLocalBackupsCanBeInspectedExportedAndDeleted() async throws {
        let session: AppSession = makeSession()
        let controller = BackupController(session: session)
        await controller.saveOnDevice()
        let backup: LocalBackup = try XCTUnwrap(controller.backups.first)

        await controller.inspect(backup)
        XCTAssertEqual(controller.pending?.source.contains(LocalBackup.Kind.manual.title), true)

        await controller.export(backup)
        XCTAssertEqual(controller.exportFile?.data, try session.localBackups?.read(backup))

        controller.delete(backup)
        XCTAssertTrue(controller.backups.isEmpty)
    }

    @MainActor
    func testEraseAllFromTheController() async throws {
        let session: AppSession = makeSession()
        session.boot.settings.themeID = "forest"
        let controller = BackupController(session: session)
        let erased: Bool = await controller.eraseAll()
        XCTAssertTrue(erased)
        XCTAssertEqual(controller.message?.title, "すべてのデータを消しました")
        XCTAssertEqual(session.boot.settings.themeID, ThemeCatalog.defaultID)
        XCTAssertEqual(controller.backups.first?.kind, .beforeErase)
    }

    @MainActor
    func testNothingWorksWithoutAPlaceToSave() async {
        let boot: AppBootstrap = AppBootstrap.make(options: LaunchOptions(arguments: [LaunchOptions.sampleItemsFlag, "5"]))
        let controller = BackupController(session: AppSession(boot: boot))
        XCTAssertNotNil(controller.unavailableReason)
        await controller.prepareExport()
        XCTAssertNil(controller.exportFile)
        XCTAssertEqual(controller.message?.title, "バックアップを作れませんでした")
        controller.refresh()
        XCTAssertTrue(controller.backups.isEmpty)
    }

    // MARK: - このアプリについて

    func testAboutListsEveryHostTheAppTalksTo() {
        XCTAssertEqual(AboutCatalog.networkHosts, ["geocoding-api.open-meteo.com", "api.open-meteo.com", "api.github.com", "raw.githubusercontent.com"])
        let sections: [AboutSection] = AboutCatalog.sections()
        let network: AboutSection? = sections.first { (section: AboutSection) -> Bool in section.id == "network" }
        let text: String = network?.items.map { (item: AboutItem) -> String in item.detail }.joined() ?? ""
        for host in AboutCatalog.networkHosts {
            XCTAssertTrue(text.contains(host), host)
        }
        XCTAssertEqual(sections.map { (section: AboutSection) -> String in section.id }, ["permissions", "network", "storage", "licenses"])
    }

    func testAboutItemsAreUniqueAndLinksAreSafe() {
        let items: [AboutItem] = AboutCatalog.sections().flatMap { (section: AboutSection) -> [AboutItem] in section.items }
        let ids: [String] = items.map { (item: AboutItem) -> String in item.id }
        XCTAssertEqual(Set(ids).count, ids.count)
        for item in items {
            XCTAssertFalse(item.detail.isEmpty, item.id)
            guard let link = item.link else { continue }
            guard case .allowed(let checked) = URLPolicy.check(link) else {
                return XCTFail("\(item.id): \(link)")
            }
            XCTAssertEqual(checked.url.scheme, "https", item.id)
        }
        let licenses: String = items.map { (item: AboutItem) -> String in item.detail }.joined()
        XCTAssertTrue(licenses.contains("Weather data by Open-Meteo.com"), "Open-Meteo の出典（CC BY 4.0 の条件）")
        XCTAssertTrue(licenses.contains("GeoNames"))
    }

    // MARK: - 設定の中のページ

    @MainActor
    func testLaunchOptionsCanOpenASettingsPage() async {
        let router = AppRouter()
        LaunchOptions(arguments: ["MyHome", "-MyHomeSettingsPage", "backup"]).apply(to: router)
        XCTAssertEqual(router.sheet, .feature(.settings))
        XCTAssertEqual(router.settingsPath, [.backup])
        XCTAssertNil(LaunchOptions(arguments: ["MyHome", "-MyHomeSettingsPage", "unknown"]).settingsPage)
        XCTAssertEqual(LaunchOptions(arguments: ["MyHome", "-MyHomeSettingsPage", "about"]).settingsPage, .about)
    }

    // MARK: - 補助

    @MainActor
    private func makeSession() -> AppSession {
        let boot: AppBootstrap = AppBootstrap.make(directory: directory, delay: .milliseconds(1))
        let clock: Date = fixed
        return AppSession(
            boot: boot,
            load: { (folder: URL) -> AppBootstrap in AppBootstrap.make(directory: folder, delay: .milliseconds(1)) },
            clock: { clock }
        )
    }
}
