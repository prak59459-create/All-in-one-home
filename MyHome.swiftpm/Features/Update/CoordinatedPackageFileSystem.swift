import Foundation

/// 利用者が選んだ MyHome.swiftpm への読み書き。Swift Playgrounds や iCloud Drive が同じファイルを使っていても
/// 壊さないよう、すべて NSFileCoordinator を通す（Swift Playgrounds には変更が知らされる）。
/// 呼び出す側が、フォルダのセキュリティスコープを開始してから使う（PackageAccess）。
struct CoordinatedPackageFileSystem: PackageFileSystem {
    let root: URL

    private func url(for path: String) throws -> URL {
        guard PackagePath.isSafe(path) else { throw UpdateError.unsafePath(path) }
        return root.appendingPathComponent(path, isDirectory: false)
    }

    func listFiles() throws -> [String] {
        var result: [String] = []
        try coordinate(reading: root) { (url: URL) in
            result = try DirectoryFileSystem.listFiles(in: url)
        }
        return result
    }

    func read(_ path: String) throws -> Data {
        var data = Data()
        try coordinate(reading: try url(for: path)) { (url: URL) in
            data = try Data(contentsOf: url)
        }
        return data
    }

    func write(_ data: Data, to path: String) throws {
        let target: URL = try url(for: path)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try coordinate(writing: target, options: .forReplacing) { (url: URL) in
            try data.write(to: url, options: .atomic)
        }
    }

    func delete(_ path: String) throws {
        let target: URL = try url(for: path)
        guard FileManager.default.fileExists(atPath: target.path) else { return }
        try coordinate(writing: target, options: .forDeleting) { (url: URL) in
            try FileManager.default.removeItem(at: url)
        }
    }

    func exists(_ path: String) -> Bool {
        guard let target = try? url(for: path) else { return false }
        return FileManager.default.fileExists(atPath: target.path)
    }

    private func coordinate(reading url: URL, _ body: (URL) throws -> Void) throws {
        var coordinationError: NSError?
        var bodyError: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordinationError) { (actual: URL) in
            do {
                try body(actual)
            } catch {
                bodyError = error
            }
        }
        if let error = coordinationError ?? bodyError {
            throw error
        }
    }

    private func coordinate(writing url: URL, options: NSFileCoordinator.WritingOptions, _ body: (URL) throws -> Void) throws {
        var coordinationError: NSError?
        var bodyError: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: options, error: &coordinationError) { (actual: URL) in
            do {
                try body(actual)
            } catch {
                bodyError = error
            }
        }
        if let error = coordinationError ?? bodyError {
            throw error
        }
    }
}
