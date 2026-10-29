import Foundation

/// パッケージ（MyHome.swiftpm）や退避先のファイルの読み書き。パスはルートからの相対パス（"Core/AppInfo.swift"）。
/// iPad では、利用者が選んだフォルダに NSFileCoordinator で書き込む実装（Features/Update）を使う。
protocol PackageFileSystem: Sendable {
    /// 管理するファイルの一覧（隠しファイルと隠しフォルダの中は含めない）。
    func listFiles() throws -> [String]
    func read(_ path: String) throws -> Data
    func write(_ data: Data, to path: String) throws
    func delete(_ path: String) throws
    func exists(_ path: String) -> Bool
}

/// 相対パスの安全確認。ルートの外を指すもの、隠しファイル、異常に長いものを拒否する。
enum PackagePath {
    static let maximumLength: Int = 300

    static func isSafe(_ path: String) -> Bool {
        guard !path.isEmpty, path.count <= maximumLength, !path.hasPrefix("/"), !path.contains("\\") else { return false }
        let components: [Substring] = path.split(separator: "/", omittingEmptySubsequences: false)
        for component in components {
            if component.isEmpty || component == "." || component == ".." || component.hasPrefix(".") {
                return false
            }
        }
        return true
    }
}

/// 普通のフォルダに読み書きする実装（退避先と、テストで使う）。
struct DirectoryFileSystem: PackageFileSystem {
    let root: URL

    func url(for path: String) throws -> URL {
        guard PackagePath.isSafe(path) else { throw UpdateError.unsafePath(path) }
        return root.appendingPathComponent(path, isDirectory: false)
    }

    func listFiles() throws -> [String] {
        try DirectoryFileSystem.listFiles(in: root)
    }

    func read(_ path: String) throws -> Data {
        try Data(contentsOf: try url(for: path))
    }

    func write(_ data: Data, to path: String) throws {
        let target: URL = try url(for: path)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: target, options: .atomic)
    }

    func delete(_ path: String) throws {
        let target: URL = try url(for: path)
        guard FileManager.default.fileExists(atPath: target.path) else { return }
        try FileManager.default.removeItem(at: target)
    }

    func exists(_ path: String) -> Bool {
        guard let target = try? url(for: path) else { return false }
        return FileManager.default.fileExists(atPath: target.path)
    }

    /// サブフォルダをルートにした実装（退避先の UpdateBackups/<id> など）。
    func subdirectory(_ name: String) -> DirectoryFileSystem {
        DirectoryFileSystem(root: root.appendingPathComponent(name, isDirectory: true))
    }

    /// root の中の普通のファイル（隠しファイルと隠しフォルダの中を除く）を、root からの相対パスで返す。
    static func listFiles(in root: URL) throws -> [String] {
        let base: String = root.standardizedFileURL.path
        guard let enumerator = FileManager.default.enumerator(atPath: base) else { return [] }
        var result: [String] = []
        while let element = enumerator.nextObject() as? String {
            guard PackagePath.isSafe(element) else {
                // 隠しフォルダ（.swiftpm など）の中には入らない
                if element.split(separator: "/").last?.hasPrefix(".") ?? false {
                    enumerator.skipDescendants()
                }
                continue
            }
            var isDirectory: ObjCBool = false
            let full: String = base + "/" + element
            if FileManager.default.fileExists(atPath: full, isDirectory: &isDirectory), !isDirectory.boolValue {
                result.append(element)
            }
        }
        return result.sorted()
    }
}
