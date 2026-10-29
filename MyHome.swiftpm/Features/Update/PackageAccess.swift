import Foundation

/// 選んだ MyHome.swiftpm へのアクセス（セキュリティスコープの開始・終了と、ブックマークの保存・復元）。
/// コピー（アプリの中に取り込んだもの）を選んだ時は使わない。コピーに書き込んでも Swift Playgrounds のアプリは変わらないため。
@MainActor
final class PackageAccess {
    let url: URL
    private var isAccessing: Bool

    private init(url: URL) {
        self.url = url
        isAccessing = url.startAccessingSecurityScopedResource()
    }

    var fileSystem: CoordinatedPackageFileSystem {
        CoordinatedPackageFileSystem(root: url)
    }

    var folderName: String {
        url.lastPathComponent
    }

    /// 表示用の場所（最後の3つのフォルダ名）。
    var location: String {
        url.pathComponents.suffix(3).joined(separator: " › ")
    }

    func stop() {
        if isAccessing {
            url.stopAccessingSecurityScopedResource()
            isAccessing = false
        }
    }

    /// Files で選んだフォルダを開く。コピーなら断る。
    static func open(picked url: URL) throws -> PackageAccess {
        if isInsideAppContainer(url) {
            throw UpdateError.copiedPackage
        }
        return PackageAccess(url: url)
    }

    /// 覚えておいたブックマークから開く。古くなっていれば新しいブックマークも返す。
    static func open(bookmark: Data) throws -> (access: PackageAccess, refreshedBookmark: Data?) {
        var isStale: Bool = false
        let url: URL
        do {
            url = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
        } catch {
            throw UpdateError.folderUnavailable(error.localizedDescription)
        }
        let access: PackageAccess = try open(picked: url)
        let refreshed: Data? = isStale ? try? access.makeBookmark() : nil
        return (access, refreshed)
    }

    func makeBookmark() throws -> Data {
        do {
            return try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            throw UpdateError.folderUnavailable(error.localizedDescription)
        }
    }

    private static func isInsideAppContainer(_ url: URL) -> Bool {
        let home: String = URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL.resolvingSymlinksInPath().path
        let picked: String = url.standardizedFileURL.resolvingSymlinksInPath().path
        return picked == home || picked.hasPrefix(home + "/")
    }
}
