import Foundation

/// 保存データを読めなかった理由。
enum HomeArchiveError: Error, Hashable, Sendable {
    case tooLarge(byteCount: Int)
    /// JSON として読めない、または必要な値がない・型が違う（F0821）。
    case malformed(String)
    /// 新しい版のアプリで保存された形式。上書きしないよう、読み込みを止める。
    case newerVersion(Int)
    /// 構造の問題（ID の重複など。F0824）。
    case invalid([LayoutProblem])
}

/// SavedHome と JSON の変換。読み込み時は「大きさ → 形式の版 → 移行 → 構造の検証 → 整形」の順に確かめる。
enum HomeArchiveCodec {
    /// 読み込む保存ファイルの上限。項目 2,000 件でも 1MB 未満なので、十分に余裕がある。
    static let maximumByteCount: Int = 5_000_000

    static func encode(_ saved: SavedHome) throws -> Data {
        let encoder = JSONEncoder()
        // キーの順を固定し、差分を見やすく、テストで比べやすくする
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(saved)
    }

    static func decode(_ data: Data) throws -> SavedHome {
        guard data.count <= maximumByteCount else {
            throw HomeArchiveError.tooLarge(byteCount: data.count)
        }
        let version: Int = try schemaVersion(of: data)
        guard version >= 1 else {
            throw HomeArchiveError.malformed("schemaVersion が不正です（\(version)）")
        }
        guard version <= SavedHome.currentSchemaVersion else {
            throw HomeArchiveError.newerVersion(version)
        }
        var saved: SavedHome = try migrate(data, from: version)
        let problems: [LayoutProblem] = LayoutValidator.problems(in: saved.layout)
        guard problems.isEmpty else {
            throw HomeArchiveError.invalid(problems)
        }
        saved.layout = saved.layout.normalized()
        return saved
    }

    /// 古い版の形式を今の形式に変換する（F0823）。
    /// 版 1 → 2: 版 2 は項目の種類（フォルダ）を足しただけなので、版 1 のデータはそのまま版 2 として読める。
    /// 構造を変える版を作る時は、古い版の型で読んでから変換する処理を、その版の場合としてここに足す。
    static func migrate(_ data: Data, from version: Int) throws -> SavedHome {
        let saved: SavedHome = try decodeJSON(SavedHome.self, from: data)
        // 書き戻す時は今の版になる
        return SavedHome(layout: saved.layout, settings: saved.settings)
    }

    private struct VersionProbe: Decodable {
        let schemaVersion: Int
    }

    private static func schemaVersion(of data: Data) throws -> Int {
        let probe: VersionProbe = try decodeJSON(VersionProbe.self, from: data)
        return probe.schemaVersion
    }

    private static func decodeJSON<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch let error as DecodingError {
            throw HomeArchiveError.malformed(describe(error))
        }
    }

    /// 開発者向けの短い説明（どのキーで失敗したか）。
    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            return "\(path(context.codingPath + [key])) がありません"
        case .typeMismatch(_, let context):
            return "\(path(context.codingPath)) の型が違います"
        case .dataCorrupted(let context):
            return context.codingPath.isEmpty ? "JSON として読めません" : "\(path(context.codingPath)) の値が不正です"
        default:
            return "値がありません"
        }
    }

    private static func path(_ keys: [CodingKey]) -> String {
        let names: [String] = keys.map { (key: CodingKey) -> String in
            if let index = key.intValue {
                return "[\(index)]"
            }
            return key.stringValue
        }
        return names.isEmpty ? "全体" : names.joined(separator: ".")
    }
}
