/// JSON の読み込みエラーの、開発者向けの短い説明（どのキーで失敗したか）。ホーム画面とミニアプリの保存ファイルで共通。
enum DecodingErrorText {
    static func describe(_ error: DecodingError) -> String {
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
