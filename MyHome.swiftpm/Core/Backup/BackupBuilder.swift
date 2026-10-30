import Foundation

/// バックアップを作る（F0812）。ホーム画面と設定は画面の今の状態から、ミニアプリと画像は保存先のファイルから集める
/// （ミニアプリの保存待ちの変更は、呼ぶ前に保存しておく）。
enum BackupBuilder {
    struct Result: Sendable {
        let data: Data
        let createdAt: Date
        /// 含めなかったもの（読めなかったミニアプリのデータ、見つからなかった画像）の説明。
        let notes: [String]
    }

    /// files は保存先（Application Support/MyHome）を根にしたもの。
    static func make(saved: SavedHome, files: any PackageFileSystem, createdAt: Date, appVersion: String) throws -> Result {
        var entries: [BackupFile] = [BackupFile(path: BackupPaths.home, data: try HomeArchiveCodec.encode(saved))]
        var notes: [String] = []
        for kind in MiniAppDataCatalog.all where files.exists(kind.path) {
            do {
                let data: Data = try files.read(kind.path)
                try kind.validate(data)
                entries.append(BackupFile(path: kind.path, data: data))
            } catch {
                notes.append("「\(kind.title)」のデータは読めなかったため、含めていません。")
            }
        }
        let images: ImageCollection = collectImages(named: saved.referencedImageNames, from: files)
        entries.append(contentsOf: images.files)
        if images.missingCount > 0 {
            notes.append("見つからなかった画像 \(images.missingCount) 枚は含めていません（記号で表示されます）。")
        }
        let archive = BackupArchive(createdAt: createdAt, appVersion: appVersion, files: entries)
        return Result(data: try BackupArchiveCodec.encode(archive), createdAt: createdAt, notes: notes)
    }

    private struct ImageCollection {
        var files: [BackupFile] = []
        var missingCount: Int = 0
    }

    private static func collectImages(named names: Set<String>, from files: any PackageFileSystem) -> ImageCollection {
        var collection = ImageCollection()
        for name in names.sorted() {
            let path: String = BackupPaths.image(name)
            guard ImageFileStore.isSafeName(name), files.exists(path),
                  let data = try? files.read(path), data.count <= ImageFileStore.maximumByteCount else {
                collection.missingCount += 1
                continue
            }
            collection.files.append(BackupFile(path: path, data: data))
        }
        return collection
    }
}
