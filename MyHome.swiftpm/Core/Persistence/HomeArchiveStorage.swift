import Foundation

/// 保存ファイルの読み書き。テストではメモリ上の実装や、失敗する実装に差し替える。
protocol HomeArchiveStorage: Sendable {
    /// 保存ファイルを読む。ファイルがなければ nil。limit を超える分は読まない（大きすぎることは長さで分かる）。
    func read(limit: Int) throws -> Data?
    /// 一時ファイルに書いてから置き換える（F0836）。途中で失敗しても前のファイルが残る。
    func write(_ data: Data) throws
    /// 読めなかったファイルを消さずに別名で残し、その名前を返す。
    func setAside(label: String) throws -> String
}

/// アプリ専用の領域（Application Support/MyHome/home.json）に保存する。
struct FileHomeArchiveStorage: HomeArchiveStorage {
    static let fileName: String = "home.json"
    let directory: URL

    var fileURL: URL {
        directory.appendingPathComponent(FileHomeArchiveStorage.fileName, isDirectory: false)
    }

    static func standard() throws -> FileHomeArchiveStorage {
        let base: URL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return FileHomeArchiveStorage(directory: base.appendingPathComponent("MyHome", isDirectory: true))
    }

    func read(limit: Int) throws -> Data? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let handle: FileHandle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        let data: Data? = try handle.read(upToCount: limit + 1)
        return data ?? Data()
    }

    func write(_ data: Data) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }

    func setAside(label: String) throws -> String {
        let name: String = unusedName(label: label)
        try FileManager.default.moveItem(at: fileURL, to: directory.appendingPathComponent(name, isDirectory: false))
        return name
    }

    /// 例: home.unreadable-1761750000.json（同じ名前があれば -2、-3 … を付ける）。
    private func unusedName(label: String) -> String {
        let stamp: Int = Int(Date().timeIntervalSince1970)
        let base: String = "home.\(label)-\(stamp)"
        var name: String = base + ".json"
        var counter: Int = 2
        while FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path) {
            name = "\(base)-\(counter).json"
            counter += 1
        }
        return name
    }
}
