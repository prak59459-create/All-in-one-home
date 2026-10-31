import Foundation

/// バックアップのファイル（F0812、F0818）。ホーム画面の保存ファイル・ミニアプリのデータ・画像を 1 つの JSON にまとめる。
/// {"format": "myhome-backup", "formatVersion": 1, "createdAt": "2026-10-30T10:15:00Z", "appVersion": "0.1",
///  "files": [{"path": "home.json", "data": "<Base64>"}, {"path": "Apps/notes.json", …}, {"path": "Images/icon-….jpg", …}]}
/// 中のファイルは、アプリの保存先（Application Support/MyHome）と同じ相対パス・同じ中身にする。
struct BackupArchive: Codable, Hashable, Sendable {
    static let formatName: String = "myhome-backup"
    /// 形式の版。中のファイルの並べ方を変える時に上げる（中のファイルの形式の版は、それぞれのファイルが持つ）。
    static let currentFormatVersion: Int = 1
    /// 読み書きするバックアップの上限。画像は縮小してから保存しているので、ふだんは全体で数 MB。
    static let maximumByteCount: Int = 100_000_000

    var format: String
    var formatVersion: Int
    var createdAt: Date
    /// 作ったアプリの版（表示用）。
    var appVersion: String
    var files: [BackupFile]

    init(createdAt: Date, appVersion: String, files: [BackupFile]) {
        format = BackupArchive.formatName
        formatVersion = BackupArchive.currentFormatVersion
        self.createdAt = createdAt
        self.appVersion = appVersion
        self.files = files
    }
}

/// バックアップの中の 1 ファイル。data は JSON では Base64 の文字列になる。
struct BackupFile: Codable, Hashable, Sendable {
    var path: String
    var data: Data
}

/// バックアップの中のパス。保存先と同じ形にする。
enum BackupPaths {
    static let home: String = "home.json"
    static let imagesFolder: String = "Images"

    static func image(_ name: String) -> String {
        "\(imagesFolder)/\(name)"
    }

    /// "Images/<名前>" の名前。画像のパスでない、または安全でない名前なら nil。
    static func imageName(of path: String) -> String? {
        let prefix: String = imagesFolder + "/"
        guard path.hasPrefix(prefix) else { return nil }
        let name: String = String(path.dropFirst(prefix.count))
        return ImageFileStore.isSafeName(name) ? name : nil
    }
}

/// BackupArchive と JSON の変換。読み込みは「大きさ → 種類 → 形式の版 → 中身」の順に確かめる。
enum BackupArchiveCodec {
    private struct Header: Decodable {
        let format: String
        let formatVersion: Int
    }

    static func encode(_ archive: BackupArchive) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data: Data = try encoder.encode(archive)
        guard data.count <= BackupArchive.maximumByteCount else {
            throw BackupError.tooLarge(byteCount: data.count)
        }
        return data
    }

    static func decode(_ data: Data) throws -> BackupArchive {
        guard data.count <= BackupArchive.maximumByteCount else {
            throw BackupError.tooLarge(byteCount: data.count)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let header: Header
        do {
            header = try decoder.decode(Header.self, from: data)
        } catch {
            throw BackupError.notABackup
        }
        guard header.format == BackupArchive.formatName else {
            throw BackupError.notABackup
        }
        guard header.formatVersion >= 1 else {
            throw BackupError.malformed("formatVersion が不正です（\(header.formatVersion)）")
        }
        guard header.formatVersion <= BackupArchive.currentFormatVersion else {
            throw BackupError.newerVersion(header.formatVersion)
        }
        do {
            return try decoder.decode(BackupArchive.self, from: data)
        } catch let error as DecodingError {
            throw BackupError.malformed(DecodingErrorText.describe(error))
        }
    }
}
