/// 保存形式: {"kind": "url", "url": "https://…"} / {"kind": "feature", "feature": "notes"}。
/// 列挙型の自動生成の形式（"_0" というキー）は読みにくく変わりやすいので使わない。
extension HomeItemAction: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case url
        case feature
    }

    private enum Kind: String, Codable {
        case url
        case feature
    }

    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        let kind: Kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .url:
            let url: String = try container.decode(String.self, forKey: .url)
            self = .openURL(url)
        case .feature:
            let feature: AppFeature = try container.decode(AppFeature.self, forKey: .feature)
            self = .feature(feature)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .openURL(let url):
            try container.encode(Kind.url, forKey: .kind)
            try container.encode(url, forKey: .url)
        case .feature(let feature):
            try container.encode(Kind.feature, forKey: .kind)
            try container.encode(feature, forKey: .feature)
        }
    }
}
