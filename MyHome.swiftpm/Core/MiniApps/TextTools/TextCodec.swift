import Foundation

/// 文字列の変換（F0513）。文字は UTF-8 として扱う。
enum TextCodec: String, CaseIterable, Identifiable, Sendable {
    case base64Encode
    case base64Decode
    case urlEncode
    case urlDecode

    var id: String { rawValue }

    var title: String {
        switch self {
        case .base64Encode: return "Base64 に変換"
        case .base64Decode: return "Base64 から戻す"
        case .urlEncode: return "URL エンコード"
        case .urlDecode: return "URL デコード"
        }
    }

    func apply(_ text: String) -> Result<String, TextToolError> {
        switch self {
        case .base64Encode:
            return .success(Data(text.utf8).base64EncodedString())
        case .base64Decode:
            return TextCodec.decodeBase64(text)
        case .urlEncode:
            guard let encoded = text.addingPercentEncoding(withAllowedCharacters: TextCodec.unreserved) else {
                return .failure(TextToolError(message: "変換できない文字があります。"))
            }
            return .success(encoded)
        case .urlDecode:
            guard let decoded = text.removingPercentEncoding else {
                return .failure(TextToolError(message: "「%」の後が正しくありません（%E3%81%82 のように、% と 16 進数 2 桁）。"))
            }
            return .success(decoded)
        }
    }

    /// URL の中でそのまま使える文字（RFC 3986 の unreserved）。それ以外は % で表す。
    private static var unreserved: CharacterSet {
        CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    }

    /// 空白・改行は無視し、URL 用の「-」「_」と、末尾の「=」の省略も受け付ける。
    private static func decodeBase64(_ text: String) -> Result<String, TextToolError> {
        var cleaned: String = text.filter { (character: Character) -> Bool in !character.isWhitespace }
        cleaned = cleaned.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let remainder: Int = cleaned.count % 4
        if remainder > 0 {
            cleaned += String(repeating: "=", count: 4 - remainder)
        }
        guard let data = Data(base64Encoded: cleaned) else {
            return .failure(TextToolError(message: "Base64 として読めません。"))
        }
        guard let decoded = String(data: data, encoding: .utf8) else {
            return .failure(TextToolError(message: "戻した内容が文字ではありません（画像などのデータの可能性があります）。"))
        }
        return .success(decoded)
    }
}

struct TextToolError: Error, Hashable, Sendable {
    let message: String
}
