import Foundation

/// 起動時の読み込み結果。
struct LoadOutcome: Hashable, Sendable {
    let saved: SavedHome
    /// 読めなかった時に利用者へ見せる説明。問題がなければ nil。
    let notice: String?
    /// 保存してよいか。読めなかったファイルを退避できなかった時は、上書きしないよう保存を止める。
    let canSave: Bool
}

/// 起動時に保存ファイルを読む。読めない時は初期の配置で始め、元のファイルは消さずに別名で残す（F0821）。
enum HomeArchiveLoader {
    static func load(from storage: any HomeArchiveStorage) -> LoadOutcome {
        let data: Data?
        do {
            data = try storage.read(limit: HomeArchiveCodec.maximumByteCount)
        } catch {
            return recover(reason: "保存ファイルを開けませんでした。", storage: storage)
        }
        guard let data else {
            return LoadOutcome(saved: .initial(), notice: nil, canSave: true)
        }
        do {
            let saved: SavedHome = try HomeArchiveCodec.decode(data)
            return LoadOutcome(saved: saved, notice: nil, canSave: true)
        } catch let error as HomeArchiveError {
            return recover(reason: error.message, storage: storage)
        } catch {
            return recover(reason: "保存データを読み込めませんでした。", storage: storage)
        }
    }

    private static func recover(reason: String, storage: any HomeArchiveStorage) -> LoadOutcome {
        let lead: String = "保存データを読み込めなかったため、初期の配置で起動しました。\n" + reason
        do {
            let name: String = try storage.setAside(label: "unreadable")
            let note: String = "\n読めなかったファイルは消さずに「\(name)」として残しています。"
            return LoadOutcome(saved: .initial(), notice: lead + note, canSave: true)
        } catch {
            let note: String = "\n元のファイルを別名で残せなかったため、上書きしないよう、この起動中は変更を保存しません。"
            return LoadOutcome(saved: .initial(), notice: lead + note, canSave: false)
        }
    }
}
