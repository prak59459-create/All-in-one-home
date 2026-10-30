import Foundation

/// ミニアプリ 1 つ分のデータ（検証済み）。
struct MiniAppBackupEntry: Identifiable, Hashable, Sendable {
    let fileID: String
    let title: String
    let data: Data

    var id: String {
        fileID
    }

    var path: String {
        "Apps/\(fileID).json"
    }
}

/// 読み込んだバックアップの中身。どれも検証済みで、このまま復元できる。復元の前に、プレビューとして見せる（F0819）。
struct BackupContents: Hashable, Sendable {
    let createdAt: Date
    let appVersion: String
    let byteCount: Int
    let home: SavedHome
    let miniApps: [MiniAppBackupEntry]
    /// 配置・壁紙が使っている画像（名前 → 中身）。
    let images: [String: Data]
    /// 配置・壁紙が使っているのに、バックアップに入っていない画像（F0827）。記号で表示される。
    let missingImageNames: [String]
    /// この版のアプリでは使わないファイル（新しい版のミニアプリのデータなど）。復元しない。
    let skippedPaths: [String]
}

/// バックアップを読んで、中のファイルを 1 つずつ確かめる（F0813、F0821、F0824、F0827）。
/// 1 つでも読めないファイルがあれば、何も復元しない（一部だけ戻って、残りが今のままになるのを防ぐ）。
enum BackupReader {
    static func read(_ data: Data) throws -> BackupContents {
        let archive: BackupArchive = try BackupArchiveCodec.decode(data)
        let sorted: SortedFiles = try sort(archive.files)
        guard let homeData = sorted.home else {
            throw BackupError.missingHome
        }
        let home: SavedHome
        do {
            home = try HomeArchiveCodec.decode(homeData)
        } catch {
            throw BackupError.invalidHome(BackupError.message(for: error))
        }
        let miniApps: [MiniAppBackupEntry] = try validatedMiniApps(sorted.miniApps)
        var images: [String: Data] = [:]
        var missing: [String] = []
        for name in home.referencedImageNames.sorted() {
            guard let image = sorted.images[name] else {
                missing.append(name)
                continue
            }
            guard image.count <= ImageFileStore.maximumByteCount else {
                throw BackupError.invalidImage(name)
            }
            images[name] = image
        }
        return BackupContents(
            createdAt: archive.createdAt,
            appVersion: archive.appVersion,
            byteCount: data.count,
            home: home,
            miniApps: miniApps,
            images: images,
            missingImageNames: missing,
            skippedPaths: sorted.skipped
        )
    }

    private struct SortedFiles {
        var home: Data?
        var miniApps: [String: Data] = [:]
        var images: [String: Data] = [:]
        var skipped: [String] = []
    }

    private static func sort(_ files: [BackupFile]) throws -> SortedFiles {
        var sorted = SortedFiles()
        var seen: Set<String> = []
        for file in files {
            guard seen.insert(file.path).inserted else {
                throw BackupError.duplicatePath(file.path)
            }
            if file.path == BackupPaths.home {
                sorted.home = file.data
            } else if let kind = MiniAppDataCatalog.kind(path: file.path) {
                sorted.miniApps[kind.fileID] = file.data
            } else if let name = BackupPaths.imageName(of: file.path) {
                sorted.images[name] = file.data
            } else {
                sorted.skipped.append(file.path)
            }
        }
        return sorted
    }

    private static func validatedMiniApps(_ files: [String: Data]) throws -> [MiniAppBackupEntry] {
        var entries: [MiniAppBackupEntry] = []
        for kind in MiniAppDataCatalog.all {
            guard let data = files[kind.fileID] else { continue }
            do {
                try kind.validate(data)
            } catch {
                throw BackupError.invalidMiniApp(title: kind.title, reason: BackupError.message(for: error))
            }
            entries.append(MiniAppBackupEntry(fileID: kind.fileID, title: kind.title, data: data))
        }
        return entries
    }
}
