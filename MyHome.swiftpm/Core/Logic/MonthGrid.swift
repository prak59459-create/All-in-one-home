import Foundation

/// 月のカレンダーの並び（F0241、F0243、F0260）。週の始まりは Calendar.firstWeekday（端末の設定）に従う。
struct MonthGrid: Hashable, Sendable {
    let year: Int
    let month: Int
    /// 曜日の見出し（週の始まりから7つ）。
    let weekdaySymbols: [String]
    /// 週ごとの日付（その月でないマスは nil）。
    let weeks: [[Int?]]
    /// 今日がこの月なら、その日。
    let today: Int?

    static func make(for date: Date, calendar: Calendar) -> MonthGrid {
        let parts: DateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let year: Int = parts.year ?? 1970
        let month: Int = parts.month ?? 1
        let first: Date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? date
        let dayCount: Int = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        let weekday: Int = calendar.component(.weekday, from: first)
        let offset: Int = (weekday - calendar.firstWeekday + 7) % 7
        return MonthGrid(
            year: year,
            month: month,
            weekdaySymbols: rotatedSymbols(calendar),
            weeks: weeks(offset: offset, dayCount: dayCount),
            today: parts.day
        )
    }

    private static func weeks(offset: Int, dayCount: Int) -> [[Int?]] {
        var cells: [Int?] = Array(repeating: nil, count: offset)
        for day in 1...dayCount {
            cells.append(day)
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        var result: [[Int?]] = []
        var index: Int = 0
        while index < cells.count {
            result.append(Array(cells[index..<(index + 7)]))
            index += 7
        }
        return result
    }

    private static func rotatedSymbols(_ calendar: Calendar) -> [String] {
        let symbols: [String] = calendar.veryShortStandaloneWeekdaySymbols
        guard symbols.count == 7 else { return symbols }
        let start: Int = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }
}
