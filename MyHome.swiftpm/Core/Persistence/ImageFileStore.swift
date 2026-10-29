import Foundation

/// 壁紙・アイコンの画像ファイル（Application Support/MyHome/Images）。画像の縮小と JPEG 化は画面側（UIKit）で行い、
/// ここではファイルの読み書きと、使われなくなったファイルの整理だけを行う（Linux でテストできるように Foundation だけを使う）。
struct ImageFileStore: Sendable {
    /// 1枚の上限。縮小してから保存するので、通常は 1MB 未満。
    static let maximumByteCount: Int = 8_000_000
    let directory: URL

    func url(for name: String) -> URL {
        directory.appendingPathComponent(name, isDirectory: false)
    }

    /// 新しい名前で保存し、その名前を返す（同じ名前を上書きしないので、取り消しで古い画像に戻せる）。
    func save(_ data: Data, prefix: String) throws -> String {
        guard data.count <= ImageFileStore.maximumByteCount else { throw ImageFileError.tooLarge }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name: String = "\(prefix)-\(UUID().uuidString.lowercased()).jpg"
        try data.write(to: url(for: name), options: .atomic)
        return name
    }

    func load(_ name: String) -> Data? {
        guard ImageFileStore.isSafeName(name) else { return nil }
        return try? Data(contentsOf: url(for: name))
    }

    func exists(_ name: String) -> Bool {
        ImageFileStore.isSafeName(name) && FileManager.default.fileExists(atPath: url(for: name).path)
    }

    /// keeping に含まれない画像を消す（起動時に、読み込みに成功した時だけ呼ぶ）。消した数を返す。
    @discardableResult
    func removeUnreferenced(keeping names: Set<String>) -> Int {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return 0 }
        var removed: Int = 0
        for file in files where !names.contains(file) {
            if (try? FileManager.default.removeItem(at: url(for: file))) != nil {
                removed += 1
            }
        }
        return removed
    }

    /// 保存データの名前でフォルダの外を指せないようにする（"../" などを拒否）。
    static func isSafeName(_ name: String) -> Bool {
        !name.isEmpty && !name.contains("/") && !name.contains("\\") && !name.hasPrefix(".") && name.count <= LayoutLimits.maximumIDLength
    }
}

enum ImageFileError: Error, Hashable, Sendable {
    case tooLarge
    case unreadable

    var message: String {
        switch self {
        case .tooLarge: return "画像が大きすぎます。"
        case .unreadable: return "画像を読み込めませんでした。別の画像を選んでください。"
        }
    }
}
