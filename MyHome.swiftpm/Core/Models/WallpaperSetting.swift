/// 壁紙（F0646、F0647、F0650、F0651）。画像は Application Support/MyHome/Images に置き、ここにはファイル名だけを持つ。
enum WallpaperSetting: Hashable, Sendable {
    /// テーマのグラデーション（既定）。
    case themeGradient
    case image(WallpaperImage)
}

/// 画像の壁紙。ぼかしと暗さは 0...1（表示の時にぼかしの半径・黒の重ねの濃さに換算する）。
struct WallpaperImage: Hashable, Codable, Sendable {
    var fileName: String
    var blur: Double
    var dim: Double

    init(fileName: String, blur: Double = 0, dim: Double = 0.2) {
        self.fileName = fileName
        self.blur = WallpaperImage.unit(blur)
        self.dim = WallpaperImage.unit(dim)
    }

    private enum CodingKeys: String, CodingKey {
        case fileName
        case blur
        case dim
    }

    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        let name: String = try container.decode(String.self, forKey: .fileName)
        let blur: Double = (try? container.decode(Double.self, forKey: .blur)) ?? 0
        let dim: Double = (try? container.decode(Double.self, forKey: .dim)) ?? 0.2
        self.init(fileName: name, blur: blur, dim: dim)
    }

    private static func unit(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }
}

/// 保存形式: {"style": "gradient"} / {"style": "image", "image": {...}}。
extension WallpaperSetting: Codable {
    private enum CodingKeys: String, CodingKey {
        case style
        case image
    }

    private enum Style: String, Codable {
        case gradient
        case image
    }

    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        let style: Style = try container.decode(Style.self, forKey: .style)
        switch style {
        case .gradient:
            self = .themeGradient
        case .image:
            self = .image(try container.decode(WallpaperImage.self, forKey: .image))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .themeGradient:
            try container.encode(Style.gradient, forKey: .style)
        case .image(let image):
            try container.encode(Style.image, forKey: .style)
            try container.encode(image, forKey: .image)
        }
    }

    /// 参照している画像ファイル名。
    var imageFileName: String? {
        if case .image(let image) = self {
            return image.fileName
        }
        return nil
    }
}
