import Foundation

/// 開いてよいと判断した URL。
struct CheckedURL: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        /// https の Web ページ。
        case secureWeb
        /// http の Web ページ（暗号化されていない）。
        case insecureWeb
        /// その他の URL スキーム。対応するアプリがある場合だけ開ける。
        case appScheme
    }

    let url: URL
    let kind: Kind
    /// 確認画面に表示する行き先（Web はホスト名、それ以外はスキーム名）。
    let destination: String
}

/// URL を開かない理由。
enum URLRejection: Hashable, Sendable {
    case empty
    case tooLong
    case malformed
    case blockedScheme(String)
    case missingHost
}

enum URLCheckResult: Hashable, Sendable {
    case allowed(CheckedURL)
    case rejected(URLRejection)
}

/// 外部 URL を開く前の検証。危険なスキームを拒否し、形式の誤りを検出する。
enum URLPolicy {
    static let maximumLength: Int = 2048

    /// スクリプト実行や端末内データの読み取りにつながるため、開かないスキーム。
    static let blockedSchemes: Set<String> = ["javascript", "vbscript", "data", "file", "blob", "about"]

    /// Foundation の URL 解析は OS・バージョンによって不正な文字の扱いが異なるため、
    /// 危険なスキームと空白・制御文字は解析の前に判定し、どの環境でも同じ結果にする。
    static func check(_ raw: String) -> URLCheckResult {
        let text: String = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return .rejected(.empty)
        }
        if text.count > maximumLength {
            return .rejected(.tooLong)
        }
        if let scheme = leadingScheme(of: text), blockedSchemes.contains(scheme) {
            return .rejected(.blockedScheme(scheme))
        }
        if containsWhitespaceOrControl(text) {
            return .rejected(.malformed)
        }
        guard let components = URLComponents(string: text),
              let scheme = components.scheme?.lowercased(),
              let url = components.url else {
            return .rejected(.malformed)
        }
        if blockedSchemes.contains(scheme) {
            return .rejected(.blockedScheme(scheme))
        }
        guard scheme == "https" || scheme == "http" else {
            return .allowed(CheckedURL(url: url, kind: .appScheme, destination: scheme))
        }
        guard let host = components.host, !host.isEmpty else {
            return .rejected(.missingHost)
        }
        let kind: CheckedURL.Kind = scheme == "https" ? .secureWeb : .insecureWeb
        return .allowed(CheckedURL(url: url, kind: kind, destination: host.lowercased()))
    }

    /// 先頭の「スキーム:」部分（RFC 3986 の形式: 英字で始まり、英数字と + - . が続く）を小文字で返す。
    static func leadingScheme(of text: String) -> String? {
        guard let colon = text.firstIndex(of: ":") else { return nil }
        let candidate: Substring = text[..<colon]
        guard let first = candidate.first, first.isASCII, first.isLetter else { return nil }
        let isValid: Bool = candidate.allSatisfy(isSchemeCharacter)
        return isValid ? candidate.lowercased() : nil
    }

    private static func isSchemeCharacter(_ character: Character) -> Bool {
        guard character.isASCII else { return false }
        return character.isLetter || character.isNumber || character == "+" || character == "-" || character == "."
    }

    private static func containsWhitespaceOrControl(_ text: String) -> Bool {
        let forbidden: CharacterSet = CharacterSet.whitespacesAndNewlines.union(.controlCharacters)
        return text.unicodeScalars.contains { forbidden.contains($0) }
    }
}
