/// 保存形式: {"type": "clock", "clock": {...}} / {"type": "calendar"} / {"type": "note", "text": "…"} / {"type": "timer"}。
extension WidgetKind: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case clock
        case text
    }

    private enum KindType: String, Codable {
        case clock
        case calendar
        case note
        case timer
    }

    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        let type: KindType = try container.decode(KindType.self, forKey: .type)
        switch type {
        case .clock:
            self = .clock(try container.decode(ClockWidgetStyle.self, forKey: .clock))
        case .calendar:
            self = .calendar
        case .note:
            self = .note(try container.decode(String.self, forKey: .text))
        case .timer:
            self = .timer
        }
    }

    func encode(to encoder: Encoder) throws {
        var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .clock(let style):
            try container.encode(KindType.clock, forKey: .type)
            try container.encode(style, forKey: .clock)
        case .calendar:
            try container.encode(KindType.calendar, forKey: .type)
        case .note(let text):
            try container.encode(KindType.note, forKey: .type)
            try container.encode(text, forKey: .text)
        case .timer:
            try container.encode(KindType.timer, forKey: .type)
        }
    }
}
