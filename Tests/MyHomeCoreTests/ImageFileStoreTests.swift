import Foundation
import XCTest
@testable import MyHomeCore

/// T4-1 / T4-2: 画像ファイルの保存と整理（縮小と JPEG 化は画面側なので、ここではファイルの扱いだけ）。
final class ImageFileStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("MyHomeImages-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testSaveUsesNewNamesAndLoadsBack() throws {
        let store = ImageFileStore(directory: directory)
        let first: String = try store.save(Data([1, 2, 3]), prefix: "icon")
        let second: String = try store.save(Data([4]), prefix: "icon")
        XCTAssertNotEqual(first, second, "上書きしないので、取り消しで前の画像に戻せる")
        XCTAssertTrue(first.hasPrefix("icon-") && first.hasSuffix(".jpg"))
        XCTAssertEqual(store.load(first), Data([1, 2, 3]))
        XCTAssertTrue(store.exists(second))
    }

    func testUnsafeNamesAreRejected() {
        let store = ImageFileStore(directory: directory)
        for name in ["", "../home.json", "a/b.jpg", ".hidden", "a\\b"] {
            XCTAssertFalse(ImageFileStore.isSafeName(name), name)
            XCTAssertNil(store.load(name))
        }
    }

    func testTooLargeImageIsRejected() {
        let store = ImageFileStore(directory: directory)
        XCTAssertThrowsError(try store.save(Data(count: ImageFileStore.maximumByteCount + 1), prefix: "big"))
    }

    func testUnreferencedImagesAreRemoved() throws {
        let store = ImageFileStore(directory: directory)
        let kept: String = try store.save(Data([1]), prefix: "icon")
        let orphan: String = try store.save(Data([2]), prefix: "icon")
        XCTAssertEqual(store.removeUnreferenced(keeping: [kept]), 1)
        XCTAssertTrue(store.exists(kept))
        XCTAssertFalse(store.exists(orphan))
    }

    @MainActor
    func testImagesAreKeptWhenSaveFileIsUnreadable() async throws {
        // 読めなかった保存ファイルが参照している画像を消さない
        let base: URL = directory.appendingPathComponent("MyHome", isDirectory: true)
        let storage = FileHomeArchiveStorage(directory: base)
        let images = ImageFileStore(directory: base.appendingPathComponent("Images", isDirectory: true))
        let name: String = try images.save(Data([9]), prefix: "wallpaper")
        try storage.write(Data("{ broken".utf8))
        _ = AppBootstrap.make(storage: storage, images: images)
        XCTAssertTrue(images.exists(name))
    }

    @MainActor
    func testUnreferencedImagesAreRemovedAfterSuccessfulLoad() async throws {
        let base: URL = directory.appendingPathComponent("MyHome", isDirectory: true)
        let storage = FileHomeArchiveStorage(directory: base)
        let images = ImageFileStore(directory: base.appendingPathComponent("Images", isDirectory: true))
        let used: String = try images.save(Data([1]), prefix: "wallpaper")
        let unused: String = try images.save(Data([2]), prefix: "icon")
        let settings = SavedSettings(themeID: "indigo", appearance: .system, wallpaper: .image(WallpaperImage(fileName: used)))
        try storage.write(try HomeArchiveCodec.encode(SavedHome(layout: DefaultLayout.make(), settings: settings)))
        let boot: AppBootstrap = AppBootstrap.make(storage: storage, images: images)
        XCTAssertEqual(boot.settings.wallpaper.imageFileName, used)
        XCTAssertTrue(images.exists(used))
        XCTAssertFalse(images.exists(unused))
    }
}
