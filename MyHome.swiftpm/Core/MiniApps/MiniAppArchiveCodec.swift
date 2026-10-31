import Foundation

/// ミニアプリのデータを読めなかった・書けなかった理由。
enum MiniAppArchiveError: Error, Hashable, Sendable {
    case tooLarge(byteCount: Int)
    /// JSON として読めない、または必要な値がない・型が違う。
    case malformed(String)
    /// 新しい版のアプリで保存された形式。上書きしないよう、読み込みを止める。
    case newerVersion(Int)
    /// 別のミニアプリのファイル。
    case wrongApp(String)
    /// 内容の問題（ID の重複、上限を超えた値など）。
    case invalid([String])

    var message: String {
        switch self {
        case .tooLarge(let byteCount):
            return "データが大きすぎます（\(byteCount / 1_000_000)MB）。"
        case .malformed(let detail):
            return "データの形式が正しくありません（\(detail)）。"
        case .newerVersion(let version):
            return "新しい版のアプリで保存されたデータです（形式の版 \(version)）。"
        case .wrongApp(let app):
            return "別のミニアプリ（\(app)）のデータです。"
        case .invalid(let problems):
            return "データに問題があります。" + problems.joined(separator: " ")
        }
    }
}

/// 保存形式: {"schemaVersion": 1, "app": "notes", "content": {...}}。
/// 読み込みは「大きさ → どのミニアプリか → 形式の版 → 内容の検証」の順に確かめる。
enum MiniAppArchiveCodec {
    private struct Header: Decodable {
        let schemaVersion: Int
        let app: String
    }

    private struct Envelope<Content: MiniAppContent>: Codable {
        let schemaVersion: Int
        let app: String
        let content: Content
    }

    static func encode<Content: MiniAppContent>(_ content: Content) throws -> Data {
        let envelope = Envelope<Content>(schemaVersion: Content.formatVersion, app: Content.fileID, content: content)
        let encoder = JSONEncoder()
        // キーの順を固定し、テストで比べやすくする（ホーム画面の保存ファイルと同じ）
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data: Data = try encoder.encode(envelope)
        guard data.count <= Content.maximumByteCount else {
            throw MiniAppArchiveError.tooLarge(byteCount: data.count)
        }
        return data
    }

    /// 古い版のデータは、今の型でそのまま読む（版を上げる時に値を足すだけなら初期値で読める）。
    /// 構造を変える版を作る時は、古い版の型で読んでから変換する処理をここに足す。
    static func decode<Content: MiniAppContent>(_ type: Content.Type, from data: Data) throws -> Content {
        guard data.count <= Content.maximumByteCount else {
            throw MiniAppArchiveError.tooLarge(byteCount: data.count)
        }
        let header: Header = try decodeJSON(Header.self, from: data)
        guard header.app == Content.fileID else {
            throw MiniAppArchiveError.wrongApp(header.app)
        }
        guard header.schemaVersion >= 1 else {
            throw MiniAppArchiveError.malformed("schemaVersion が不正です（\(header.schemaVersion)）")
        }
        guard header.schemaVersion <= Content.formatVersion else {
            throw MiniAppArchiveError.newerVersion(header.schemaVersion)
        }
        let envelope: Envelope<Content> = try decodeJSON(Envelope<Content>.self, from: data)
        let problems: [String] = envelope.content.problems
        guard problems.isEmpty else {
            throw MiniAppArchiveError.invalid(problems)
        }
        return envelope.content
    }

    private static func decodeJSON<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch let error as DecodingError {
            throw MiniAppArchiveError.malformed(DecodingErrorText.describe(error))
        }
    }
}
