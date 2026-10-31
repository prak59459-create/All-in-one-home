import Foundation

/// ミニアプリのデータを1つずつ順番に書く（HomeArchiveWriter と同じ規則。F0835）。エンコードと書き込みはメインスレッドの外で行う。
actor MiniAppArchiveWriter<Content: MiniAppContent> {
    private let storage: any HomeArchiveStorage
    private var lastWrittenRevision: Int = 0

    init(storage: any HomeArchiveStorage) {
        self.storage = storage
    }

    /// revision が前回書いたものより古い要求は書かずに戻る（新しい内容を古い内容で上書きしないため）。
    func write(_ content: Content, revision: Int) throws {
        guard revision > lastWrittenRevision else { return }
        let data: Data = try MiniAppArchiveCodec.encode(content)
        try storage.write(data)
        lastWrittenRevision = revision
    }
}
