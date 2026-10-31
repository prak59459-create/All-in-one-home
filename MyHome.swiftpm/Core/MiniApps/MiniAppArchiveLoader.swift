import Foundation

/// ミニアプリのデータの読み込み結果。
struct MiniAppLoadOutcome<Content: MiniAppContent>: Sendable {
    let content: Content
    /// 読めなかった時に利用者へ見せる説明。問題がなければ nil。
    let notice: String?
    /// 保存してよいか。読めなかったファイルを退避できなかった時は、上書きしないよう保存を止める。
    let canSave: Bool
}

/// ミニアプリのデータを読む。読めない時は初期の内容で始め、元のファイルは消さずに別名で残す（ホーム画面と同じ規則。F0821）。
enum MiniAppArchiveLoader {
    static func load<Content: MiniAppContent>(_ type: Content.Type, from storage: any HomeArchiveStorage) -> MiniAppLoadOutcome<Content> {
        let data: Data?
        do {
            data = try storage.read(limit: Content.maximumByteCount)
        } catch {
            return recover(Content.self, reason: "データのファイルを開けませんでした。", storage: storage)
        }
        guard let data else {
            return MiniAppLoadOutcome(content: Content.initial, notice: nil, canSave: true)
        }
        do {
            let content: Content = try MiniAppArchiveCodec.decode(Content.self, from: data)
            return MiniAppLoadOutcome(content: content, notice: nil, canSave: true)
        } catch let error as MiniAppArchiveError {
            return recover(Content.self, reason: error.message, storage: storage)
        } catch {
            return recover(Content.self, reason: "データを読み込めませんでした。", storage: storage)
        }
    }

    private static func recover<Content: MiniAppContent>(
        _ type: Content.Type,
        reason: String,
        storage: any HomeArchiveStorage
    ) -> MiniAppLoadOutcome<Content> {
        let lead: String = "保存されていたデータを読み込めなかったため、空の状態で開きました。\n" + reason
        do {
            let name: String = try storage.setAside(label: "unreadable")
            let note: String = "\n読めなかったファイルは消さずに「Apps/\(name)」として残しています。"
            return MiniAppLoadOutcome(content: Content.initial, notice: lead + note, canSave: true)
        } catch {
            let note: String = "\n元のファイルを別名で残せなかったため、上書きしないよう、変更は保存しません。"
            return MiniAppLoadOutcome(content: Content.initial, notice: lead + note, canSave: false)
        }
    }
}
