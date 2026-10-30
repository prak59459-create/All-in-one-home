import Foundation
import Observation

/// ミニアプリのデータの置き場（F0498）。データは、そのミニアプリを初めて開いた時に読み込む（ホーム画面の起動を軽くするため）。
/// ファイルは Application Support/MyHome/Apps/<fileID>.json。
@MainActor
@Observable
final class MiniAppLibrary {
    @ObservationIgnored private let makeStorage: (String) -> (any HomeArchiveStorage)?
    @ObservationIgnored private let disabledReason: String
    @ObservationIgnored private let delay: Duration
    @ObservationIgnored private var documents: [String: any MiniAppFlushing] = [:]

    /// directory が nil なら保存しない（検証用の起動など）。
    convenience init(directory: URL?, disabledReason: String = "") {
        self.init(
            makeStorage: { (fileID: String) -> (any HomeArchiveStorage)? in
                directory.map { (folder: URL) -> any HomeArchiveStorage in
                    FileHomeArchiveStorage(directory: folder, baseName: fileID)
                }
            },
            disabledReason: disabledReason
        )
    }

    /// 保存先の作り方を指定する（テストでメモリ上の保存先を使う）。
    init(
        makeStorage: @escaping (String) -> (any HomeArchiveStorage)?,
        disabledReason: String = "",
        delay: Duration = .milliseconds(500)
    ) {
        self.makeStorage = makeStorage
        self.disabledReason = disabledReason
        self.delay = delay
    }

    /// そのミニアプリのデータ。初めて呼んだ時に作る（読み込みは MiniAppDocument.load で行う）。
    func document<Content: MiniAppContent>(_ type: Content.Type) -> MiniAppDocument<Content> {
        if let existing = documents[Content.fileID] as? MiniAppDocument<Content> {
            return existing
        }
        let created = MiniAppDocument<Content>(storage: makeStorage(Content.fileID), disabledReason: disabledReason, delay: delay)
        documents[Content.fileID] = created
        return created
    }

    /// 開いたことのあるミニアプリの、保存待ちの変更をすぐ保存する。
    func flushAll() async {
        let pending: [any MiniAppFlushing] = Array(documents.values)
        for document in pending {
            await document.flush()
        }
    }

    /// 開いたことのあるミニアプリの保存をやめる（復元・消去でファイルを書き換える前に、flushAll の後で呼ぶ）。
    func suspendAll(reason: String) {
        for document in documents.values {
            document.suspend(reason: reason)
        }
    }
}
