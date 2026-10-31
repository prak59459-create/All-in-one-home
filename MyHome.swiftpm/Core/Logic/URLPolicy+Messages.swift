extension URLRejection {
    var message: String {
        switch self {
        case .empty:
            return "URL が入力されていません。"
        case .tooLong:
            return "URL が長すぎます（\(URLPolicy.maximumLength) 文字まで）。"
        case .malformed:
            return "URL の形式が正しくありません。https:// から始まる形で入力してください。"
        case .blockedScheme(let scheme):
            return "安全のため「\(scheme):」で始まる URL は開けません。"
        case .missingHost:
            return "URL にサイト名（ホスト名）がありません。"
        }
    }
}

extension CheckedURL {
    /// 開く前の確認ダイアログに表示する説明。
    var confirmationMessage: String {
        switch kind {
        case .secureWeb:
            return "\(destination) をブラウザで開きます。"
        case .insecureWeb:
            return "\(destination) をブラウザで開きます。暗号化されていない http の接続です。"
        case .appScheme:
            return "「\(destination)」に対応するアプリを開きます。対応するアプリがない場合は開けません。"
        }
    }
}
