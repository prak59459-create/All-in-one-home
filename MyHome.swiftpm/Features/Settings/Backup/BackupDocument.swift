import SwiftUI
import UniformTypeIdentifiers

/// 書き出すバックアップのファイル（ファイルに保存する画面に渡す。F0814）。中身は BackupController が作った JSON。
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.json]
    }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// ファイルを選ぶ画面で選んだバックアップを読む（F0815）。iCloud Drive のファイルは、読む前に端末に取り込まれる。
enum BackupFileReader {
    static func read(_ url: URL) -> Result<Data, Error> {
        let scoped: Bool = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        var coordinationError: NSError?
        var result: Result<Data, Error> = .failure(CocoaError(.fileReadUnknown))
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordinationError) { (readable: URL) in
            result = readLimited(readable)
        }
        if let coordinationError {
            return .failure(coordinationError)
        }
        return result
    }

    private static func readLimited(_ url: URL) -> Result<Data, Error> {
        do {
            let handle: FileHandle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let data: Data = try handle.read(upToCount: BackupArchive.maximumByteCount + 1) ?? Data()
            guard data.count <= BackupArchive.maximumByteCount else {
                return .failure(BackupError.tooLarge(byteCount: data.count))
            }
            return .success(data)
        } catch {
            return .failure(error)
        }
    }
}
