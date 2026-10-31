import SwiftUI

/// 今月のカレンダー（F0241、F0243）。週の始まりは端末の設定に従う（F0260）。日付が変わると描き直す。
@MainActor
struct CalendarWidgetView: View {
    let size: WidgetSize
    @Environment(\.homePalette) private var palette

    var body: some View {
        TimelineView(.everyMinute) { context in
            MonthGridView(grid: MonthGrid.make(for: context.date, calendar: .current), date: context.date, isWide: size == .medium)
        }
    }
}

@MainActor
struct MonthGridView: View {
    let grid: MonthGrid
    let date: Date
    let isWide: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(date, format: .dateTime.year().month(.wide))
                .font(.caption.weight(.semibold))
            Grid(horizontalSpacing: isWide ? 10 : 2, verticalSpacing: 1) {
                GridRow {
                    ForEach(grid.weekdaySymbols.indices, id: \.self) { index in
                        Text(grid.weekdaySymbols[index])
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(grid.weeks.indices, id: \.self) { week in
                    GridRow {
                        ForEach(0..<7, id: \.self) { column in
                            DayCell(day: grid.weeks[week][column], isToday: grid.weeks[week][column] == grid.today)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        "\(grid.year)年\(grid.month)月のカレンダー。今日は\(grid.today ?? 0)日"
    }
}

@MainActor
struct DayCell: View {
    let day: Int?
    let isToday: Bool

    var body: some View {
        Text(day.map { (value: Int) -> String in String(value) } ?? "")
            .font(.system(size: 10, weight: isToday ? .bold : .regular))
            .monospacedDigit()
            .foregroundStyle(isToday ? Color.white : Color.primary)
            .frame(width: 18, height: 15)
            .background {
                if isToday {
                    Capsule().fill(Color.accentColor)
                }
            }
    }
}
