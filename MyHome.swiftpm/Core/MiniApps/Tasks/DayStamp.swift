import Foundation

/// 時刻を持たない日付（タスクの期限。F0267）。タイムゾーンが変わっても同じ日のまま。保存形式は "2026-10-29"。
struct DayStamp: Hashable, Comparable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    /// 存在しない日付（2月30日など）は nil。
    init?(year: Int, month: Int, day: Int) {
        guard (1...9999).contains(year), (1...12).contains(month) else { return nil }
        guard (1...DayStamp.daysIn(month: month, year: year)).contains(day) else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    /// その時刻が、calendar で何日か。
    init(_ date: Date, calendar: Calendar) {
        let parts: DateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = parts.year ?? 1970
        self.month = parts.month ?? 1
        self.day = parts.day ?? 1
    }

    /// その日の 0 時（calendar のタイムゾーン）。
    func date(in calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    /// 何日後か（過去なら負）。
    func adding(days: Int, calendar: Calendar) -> DayStamp? {
        guard let start = date(in: calendar), let moved = calendar.date(byAdding: .day, value: days, to: start) else { return nil }
        return DayStamp(moved, calendar: calendar)
    }

    /// 今日・明日・昨日なら、その呼び方。それ以外は nil（画面側で日付として表示する）。
    func relativeName(today: DayStamp, calendar: Calendar) -> String? {
        if self == today {
            return "今日"
        }
        if today.adding(days: 1, calendar: calendar) == self {
            return "明日"
        }
        if today.adding(days: -1, calendar: calendar) == self {
            return "昨日"
        }
        return nil
    }

    var text: String {
        let monthText: String = month < 10 ? "0\(month)" : "\(month)"
        let dayText: String = day < 10 ? "0\(day)" : "\(day)"
        return "\(year)-\(monthText)-\(dayText)"
    }

    init?(text: String) {
        let parts: [Substring] = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else { return nil }
        self.init(year: year, month: month, day: day)
    }

    static func < (left: DayStamp, right: DayStamp) -> Bool {
        (left.year, left.month, left.day) < (right.year, right.month, right.day)
    }

    /// グレゴリオ暦の月の日数。
    static func daysIn(month: Int, year: Int) -> Int {
        switch month {
        case 2:
            let isLeap: Bool = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
            return isLeap ? 29 : 28
        case 4, 6, 9, 11:
            return 30
        default:
            return 31
        }
    }
}

extension DayStamp: Codable {
    init(from decoder: Decoder) throws {
        let container: SingleValueDecodingContainer = try decoder.singleValueContainer()
        let text: String = try container.decode(String.self)
        guard let stamp = DayStamp(text: text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "日付の形式が不正です: \(text)")
        }
        self = stamp
    }

    func encode(to encoder: Encoder) throws {
        var container: SingleValueEncodingContainer = encoder.singleValueContainer()
        try container.encode(text)
    }
}
