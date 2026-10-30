import SwiftUI

/// 時間別の予報（F0290、F0292）。降水確率は数字と棒で示す（F0315）。
@MainActor
struct HourlyForecastStrip: View {
    let hours: [HourlyWeather]
    let timeZone: TimeZone
    let unit: TemperatureUnit
    let now: Date

    var body: some View {
        WeatherSection(title: "時間別の予報", symbol: "clock") {
            if hours.isEmpty {
                Text("この先の時間別の予報がありません（データが古い可能性があります）。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: DesignTokens.Spacing.medium) {
                        ForEach(Array(hours.enumerated()), id: \.element.id) { (entry: (offset: Int, element: HourlyWeather)) in
                            HourlyForecastColumn(
                                hour: entry.element,
                                title: entry.offset == 0 ? "今" : WeatherFormat.hourText(entry.element.time, timeZone: timeZone),
                                unit: unit
                            )
                        }
                    }
                    .padding(.vertical, DesignTokens.Spacing.xSmall)
                }
            }
        }
    }
}

@MainActor
struct HourlyForecastColumn: View {
    let hour: HourlyWeather
    let title: String
    let unit: TemperatureUnit

    var body: some View {
        let condition: WeatherCondition? = hour.weatherCode.map { (code: Int) -> WeatherCondition in WeatherCondition(code: code) }
        let barHeight: CGFloat = HourlyForecastColumn.barHeight(for: hour.precipitationProbability)
        VStack(spacing: DesignTokens.Spacing.xSmall) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Image(systemName: condition?.symbolName(isDay: hour.isDay ?? true) ?? "questionmark.circle")
                .symbolRenderingMode(.multicolor)
                .font(.title3)
                .frame(height: 28)
            Text(WeatherFormat.temperatureText(hour.temperature, unit: unit))
                .font(.callout.monospacedDigit())
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
                Capsule()
                    .fill(Color.blue.opacity(0.7))
                    .frame(height: barHeight)
            }
            .frame(width: 6, height: HourlyForecastColumn.barMaximum)
            Text(WeatherFormat.percentText(hour.precipitationProbability))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(condition))
    }

    static let barMaximum: CGFloat = 32

    /// 降水確率の棒の高さ（0% でも細い線は見せる）。
    static func barHeight(for probability: Double?) -> CGFloat {
        let clamped: Double = min(max(probability ?? 0, 0), 100)
        return max(2, barMaximum * CGFloat(clamped / 100))
    }

    private func accessibilityText(_ condition: WeatherCondition?) -> String {
        let temperature: String = WeatherFormat.temperatureText(hour.temperature, unit: unit)
        let probability: String = WeatherFormat.percentText(hour.precipitationProbability)
        return "\(title)、\(condition?.title ?? "天気は不明")、\(temperature)、降水確率 \(probability)"
    }
}

/// 日別の予報（F0287、F0288、F0291）。最低・最高気温を、週の気温の幅の中の棒で示す（F0316）。
@MainActor
struct DailyForecastList: View {
    let days: [DailyWeather]
    let timeZone: TimeZone
    let unit: TemperatureUnit
    let now: Date

    var body: some View {
        let range: ClosedRange<Double>? = WeatherInsights.temperatureRange(of: days)
        WeatherSection(title: "\(days.count)日間の予報", symbol: "calendar") {
            VStack(spacing: DesignTokens.Spacing.small) {
                ForEach(days) { (day: DailyWeather) in
                    DailyForecastRow(day: day, title: WeatherFormat.dayText(day.date, timeZone: timeZone, now: now), unit: unit, range: range)
                }
            }
        }
    }
}

@MainActor
struct DailyForecastRow: View {
    let day: DailyWeather
    let title: String
    let unit: TemperatureUnit
    let range: ClosedRange<Double>?

    var body: some View {
        let condition: WeatherCondition? = day.weatherCode.map { (code: Int) -> WeatherCondition in WeatherCondition(code: code) }
        HStack(spacing: DesignTokens.Spacing.small) {
            Text(title)
                .frame(width: 110, alignment: .leading)
            Image(systemName: condition?.symbolName(isDay: true) ?? "questionmark.circle")
                .symbolRenderingMode(.multicolor)
                .frame(width: 28)
            Text(WeatherFormat.percentText(day.precipitationProbabilityMax))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.blue)
                .frame(width: 40, alignment: .trailing)
            Text(WeatherFormat.temperatureText(day.temperatureMin, unit: unit))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
            TemperatureRangeBar(low: day.temperatureMin, high: day.temperatureMax, range: range)
                .frame(height: 6)
            Text(WeatherFormat.temperatureText(day.temperatureMax, unit: unit))
                .monospacedDigit()
                .frame(width: 40, alignment: .leading)
        }
        .font(.callout)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(condition))
    }

    private func accessibilityText(_ condition: WeatherCondition?) -> String {
        let high: String = WeatherFormat.temperatureText(day.temperatureMax, unit: unit)
        let low: String = WeatherFormat.temperatureText(day.temperatureMin, unit: unit)
        let probability: String = WeatherFormat.percentText(day.precipitationProbabilityMax)
        return "\(title)、\(condition?.title ?? "天気は不明")、最高 \(high)、最低 \(low)、降水確率 \(probability)"
    }
}

/// 週の気温の幅の中で、その日の最低〜最高の位置を示す棒。
@MainActor
struct TemperatureRangeBar: View {
    let low: Double?
    let high: Double?
    let range: ClosedRange<Double>?

    var body: some View {
        GeometryReader { (proxy: GeometryProxy) in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
                if let span = barSpan(width: proxy.size.width) {
                    Capsule()
                        .fill(LinearGradient(colors: [.teal, .orange], startPoint: .leading, endPoint: .trailing))
                        .frame(width: span.width)
                        .offset(x: span.start)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func barSpan(width: CGFloat) -> (start: CGFloat, width: CGFloat)? {
        guard let low, let high, let range, range.upperBound > range.lowerBound, low <= high else { return nil }
        let total: Double = range.upperBound - range.lowerBound
        let start: CGFloat = width * CGFloat((low - range.lowerBound) / total)
        let end: CGFloat = width * CGFloat((high - range.lowerBound) / total)
        return (start, max(6, end - start))
    }
}

/// 見出し付きのまとまり。
@MainActor
struct WeatherSection<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Label(title, systemImage: symbol)
                .font(.headline)
            content()
        }
        .padding(DesignTokens.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
    }
}
