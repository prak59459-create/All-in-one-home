/// ソフトウェアアップデートの失敗の理由。どの段階で失敗しても、パッケージは書き込む前の状態のまま（書き込み中の失敗は元に戻す）。
enum UpdateError: Error, Hashable, Sendable {
    case network(String)
    case rateLimited
    case notFound
    case badResponse(Int)
    /// GitHub のファイル一覧が大きすぎて途中で切れた（全部を確かめられないので書き込まない）。
    case truncatedTree
    /// リポジトリに MyHome.swiftpm がない、または必要なファイルがない。
    case packageMissing
    /// 取得したファイルのハッシュが一覧と違う（通信の途中で壊れた・途中で変わった）。
    case integrity(String)
    case unsafePath(String)
    case tooLarge(String)
    /// 選んだフォルダがこのアプリのパッケージではない。
    case wrongPackage(String)
    /// 選んだフォルダが、このアプリの中へのコピーだった。
    case copiedPackage
    case folderNotSelected
    case folderUnavailable(String)
    case writeFailed(path: String, reason: String)
    case noBackup
}

extension UpdateError {
    var message: String {
        switch self {
        case .network(let detail):
            return "GitHub に接続できませんでした（\(detail)）。通信状態を確かめてください。"
        case .rateLimited:
            return "GitHub の利用回数の上限（トークンなしでは 1 時間に 60 回）に達しました。しばらく待ってからお試しください。"
        case .notFound:
            return "ブランチまたはファイルが見つかりません。ブランチ一覧を読み込み直してください。"
        case .badResponse(let status):
            return "GitHub から予期しない応答がありました（\(status)）。"
        case .truncatedTree:
            return "ファイル一覧が大きすぎて全部を確かめられないため、書き込みません。"
        case .packageMissing:
            return "選んだブランチに MyHome.swiftpm（Package.swift と Core/PackageIdentity.swift）がありません。"
        case .integrity(let path):
            return "「\(path)」の取得内容が一覧と一致しません。何も書き込んでいません。もう一度お試しください。"
        case .unsafePath(let path):
            return "安全でないファイル名（\(path)）が含まれているため、書き込みません。"
        case .tooLarge(let path):
            return "「\(path)」が大きすぎるため、書き込みません。"
        case .wrongPackage(let reason):
            return "選んだフォルダは MyHome のパッケージではありません（\(reason)）。何も書き込んでいません。"
        case .copiedPackage:
            return "選んだのはアプリの中へのコピーでした。Files の「ブラウズ」から、Swift Playgrounds が開いている元の MyHome.swiftpm を選んでください。"
        case .folderNotSelected:
            return "書き込み先の MyHome.swiftpm がまだ選ばれていません。"
        case .folderUnavailable(let detail):
            return "選んだフォルダを開けませんでした（\(detail)）。もう一度選び直してください。"
        case .writeFailed(let path, let reason):
            return "「\(path)」を書き込めませんでした（\(reason)）。書き込み済みのファイルは元に戻しました。"
        case .noBackup:
            return "元に戻せる退避データがありません。"
        }
    }
}
