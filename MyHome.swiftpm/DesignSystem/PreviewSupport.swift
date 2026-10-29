import Foundation

/// プレビュー用の保存先（何も読まず、何も保存しない）。
struct PreviewArchiveStorage: HomeArchiveStorage {
    func read(limit: Int) throws -> Data? { nil }
    func write(_ data: Data) throws {}
    func setAside(label: String) throws -> String { "" }
}
