/// 保存形式では色を "#RRGGBB" / "#RRGGBBAA" の文字列で表す。形式が違えば読み込み全体を失敗にする。
extension RGBAColor: Codable {
    init(from decoder: Decoder) throws {
        let container: SingleValueDecodingContainer = try decoder.singleValueContainer()
        let text: String = try container.decode(String.self)
        guard let color = RGBAColor(hexString: text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "色の形式が不正です: \(text)")
        }
        self = color
    }

    func encode(to encoder: Encoder) throws {
        var container: SingleValueEncodingContainer = encoder.singleValueContainer()
        try container.encode(hexString)
    }
}
