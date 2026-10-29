/// 追加する項目に選べる記号（SF Symbols）と色。
/// 記号の色は RGBAColor.readableForeground（白か黒のコントラストが高い方）で決めるので、どの色でも読める（テストで確認）。
enum IconChoices {
    static let symbols: [String] = [
        "link", "globe", "star.fill", "heart.fill",
        "bookmark.fill", "book.fill", "newspaper.fill", "music.note",
        "play.rectangle.fill", "cart.fill", "map.fill", "camera.fill",
        "gamecontroller.fill", "envelope.fill", "phone.fill", "house.fill"
    ]

    static let colors: [RGBAColor] = [
        RGBAColor(hex: 0x2563EB),
        RGBAColor(hex: 0x16A34A),
        RGBAColor(hex: 0xDC2626),
        RGBAColor(hex: 0x9333EA),
        RGBAColor(hex: 0xEA580C),
        RGBAColor(hex: 0x0891B2),
        RGBAColor(hex: 0xDB2777),
        RGBAColor(hex: 0x4B5563)
    ]

    /// 色の名前（VoiceOver で読み上げる。色だけで区別させない）。
    static let colorNames: [String] = ["青", "緑", "赤", "紫", "オレンジ", "水色", "ピンク", "グレー"]
}
