/// 全角・半角の変換（英数字・記号・空白だけ。カタカナは変えない）。
/// 全角の「！」〜「～」（U+FF01–U+FF5E）と半角の「!」〜「~」（U+0021–U+007E）は、コードの差が一定（0xFEE0）。
enum TextWidth {
    private static let offset: UInt32 = 0xFEE0
    private static let ideographicSpace: UInt32 = 0x3000

    static func toHalfWidth(_ text: String) -> String {
        map(text) { (value: UInt32) -> UInt32 in
            if (0xFF01...0xFF5E).contains(value) {
                return value - offset
            }
            return value == ideographicSpace ? 0x20 : value
        }
    }

    static func toFullWidth(_ text: String) -> String {
        map(text) { (value: UInt32) -> UInt32 in
            if (0x21...0x7E).contains(value) {
                return value + offset
            }
            return value == 0x20 ? ideographicSpace : value
        }
    }

    private static func map(_ text: String, _ transform: (UInt32) -> UInt32) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            let converted: Unicode.Scalar = Unicode.Scalar(transform(scalar.value)) ?? scalar
            scalars.append(converted)
        }
        return String(scalars)
    }
}
