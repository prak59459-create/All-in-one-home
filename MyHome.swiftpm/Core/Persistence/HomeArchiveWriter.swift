import Foundation

/// 保存を1つずつ順番に実行する（F0835）。エンコードと書き込みはメインスレッドの外で行う（F0902）。
actor HomeArchiveWriter {
    private let storage: any HomeArchiveStorage
    private var lastWrittenRevision: Int = 0

    init(storage: any HomeArchiveStorage) {
        self.storage = storage
    }

    /// revision が前回書いたものより古い要求は書かずに戻る（新しい内容を古い内容で上書きしないため）。
    func write(_ saved: SavedHome, revision: Int) throws {
        guard revision > lastWrittenRevision else { return }
        let data: Data = try HomeArchiveCodec.encode(saved)
        try storage.write(data)
        lastWrittenRevision = revision
    }
}
