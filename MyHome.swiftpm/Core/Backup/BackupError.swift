import Foundation

/// バックアップを作れなかった・読めなかった・復元できなかった理由（F0821）。
enum BackupError: Error, Hashable, Sendable {
    case tooLarge(byteCount: Int)
    /// JSON でない、または MyHome のバックアップではない。
    case notABackup
    /// 新しい版のアプリで作られたバックアップ。
    case newerVersion(Int)
    /// 必要な値がない・型が違う。
    case malformed(String)
    /// 同じパスのファイルが 2 つある（手で書き換えられたなど）。
    case duplicatePath(String)
    /// ホーム画面のデータ（home.json）が入っていない。
    case missingHome
    /// ホーム画面のデータを読めない。
    case invalidHome(String)
    /// ミニアプリのデータを読めない。
    case invalidMiniApp(title: String, reason: String)
    /// 画像が大きすぎる。
    case invalidImage(String)
    /// この起動では保存しない（検証用の起動、保存ファイルを読めなかった時など）。
    case unavailable(String)
    /// 復元・消去の前に、今のデータを端末内に残せなかった（この時は何も変えない）。
    case couldNotSaveCurrent(String)
    /// ファイルを書き換えられなかった。rolledBack は、書き換えたファイルを元に戻せたか。
    case writeFailed(String, rolledBack: Bool)

    var message: String {
        switch self {
        case .tooLarge(let byteCount):
            return "バックアップが大きすぎます（\(byteCount / 1_000_000)MB。\(BackupArchive.maximumByteCount / 1_000_000)MB まで）。"
        case .notABackup:
            return "MyHome のバックアップのファイルではありません。"
        case .newerVersion(let version):
            return "新しい版のアプリで作られたバックアップです（形式の版 \(version)）。アプリをアップデートしてから読み込んでください。"
        case .malformed(let detail):
            return "バックアップの形式が正しくありません（\(detail)）。"
        case .duplicatePath(let path):
            return "バックアップの中に同じファイル（\(path)）が 2 つあります。"
        case .missingHome:
            return "バックアップにホーム画面のデータがありません。"
        case .invalidHome(let reason):
            return "バックアップの中のホーム画面のデータを読めません。" + reason
        case .invalidMiniApp(let title, let reason):
            return "バックアップの中の「\(title)」のデータを読めません。" + reason
        case .invalidImage(let name):
            return "バックアップの中の画像（\(name)）が大きすぎます。"
        case .unavailable(let reason):
            return reason
        case .couldNotSaveCurrent(let detail):
            return "今のデータを端末内のバックアップに残せなかったため、中止しました（何も変えていません）。端末の空き容量を確認してください。（\(detail)）"
        case .writeFailed(let detail, let rolledBack):
            if rolledBack {
                return "ファイルを書き換えられなかったため、元のデータに戻しました。端末の空き容量を確認してください。（\(detail)）"
            }
            return "ファイルを書き換えられず、元にも戻せなかったものがあります。「端末内のバックアップ」の一番新しいものから復元してください。（\(detail)）"
        }
    }

    /// どんなエラーでも、利用者向けの説明にする。
    static func message(for error: Error) -> String {
        if let backup = error as? BackupError {
            return backup.message
        }
        if let archive = error as? MiniAppArchiveError {
            return archive.message
        }
        if let home = error as? HomeArchiveError {
            return home.message
        }
        return error.localizedDescription
    }
}
