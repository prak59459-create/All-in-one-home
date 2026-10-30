import SwiftUI

/// 今の天気（F0284–F0289）。背景は天気と昼夜で色を変える（F0317）。
@MainActor
struct CurrentWeatherCard: View {
    let location: WeatherLocation
    let snapshot: WeatherSnapshot
    let data: WeatherData
    let now: Date

    var body: some View {
        let current: CurrentWeather = snapshot.current
        let condition: WeatherCondition? = current.weatherCode.map { (code: Int) -> WeatherCondition in WeatherCondition(code: code) }
        let isDay: Bool = current.isDay ?? true
        let today: DailyWeather? = snapshot.upcomingDays(from: now).first
        HStack(alignment: .center, spacing: DesignTokens.Spacing.medium) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
                Text(location.name)
                    .font(.title2.weight(.semibold))
                Text(WeatherFormat.temperatureText(current.temperature, unit: data.temperatureUnit))
                    .font(.system(size: 64, weight: .thin))
                    .monospacedDigit()
                Text(condition?.title ?? "天気は不明")
                    .font(.headline)
                Text(rangeText(today))
                    .font(.subheadline)
            }
            Spacer()
            Image(systemName: condition?.symbolName(isDay: isDay) ?? "questionmark.circle")
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 72))
                .accessibilityHidden(true)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        .padding(DesignTokens.Spacing.large)
        .background(WeatherPalette.gradient(for: condition?.kind ?? .unknown, isDay: isDay), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
        .accessibilityElement(children: .combine)
    }

    private func rangeText(_ today: DailyWeather?) -> String {
        let unit: TemperatureUnit = data.temperatureUnit
        let feels: String = "体感 " + WeatherFormat.temperatureText(snapshot.current.apparentTemperature, unit: unit)
        guard let today else { return feels }
        let high: String = WeatherFormat.temperatureText(today.temperatureMax, unit: unit)
        let low: String = WeatherFormat.temperatureText(today.temperatureMin, unit: unit)
        return "最高 \(high)  最低 \(low)  \(feels)"
    }
}

/// 天気ごとの背景の色。白い文字を重ねるので、どれも暗めの色にする。
enum WeatherPalette {
    static func gradient(for kind: WeatherCondition.Kind, isDay: Bool) -> LinearGradient {
        let colors: [Color] = isDay ? dayColors(kind) : nightColors(kind)
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private static func dayColors(_ kind: WeatherCondition.Kind) -> [Color] {
        switch kind {
        case .clear: return [Color(red: 0.11, green: 0.42, blue: 0.80), Color(red: 0.20, green: 0.56, blue: 0.86)]
        case .partlyCloudy: return [Color(red: 0.20, green: 0.42, blue: 0.70), Color(red: 0.38, green: 0.54, blue: 0.72)]
        case .cloudy, .fog, .unknown: return [Color(red: 0.36, green: 0.42, blue: 0.50), Color(red: 0.48, green: 0.53, blue: 0.60)]
        case .rain: return [Color(red: 0.22, green: 0.31, blue: 0.45), Color(red: 0.32, green: 0.40, blue: 0.53)]
        case .snow: return [Color(red: 0.36, green: 0.47, blue: 0.62), Color(red: 0.50, green: 0.58, blue: 0.70)]
        case .thunder: return [Color(red: 0.24, green: 0.20, blue: 0.40), Color(red: 0.36, green: 0.32, blue: 0.50)]
        }
    }

    private static func nightColors(_ kind: WeatherCondition.Kind) -> [Color] {
        switch kind {
        case .clear, .partlyCloudy: return [Color(red: 0.07, green: 0.10, blue: 0.27), Color(red: 0.17, green: 0.20, blue: 0.40)]
        case .cloudy, .fog, .unknown: return [Color(red: 0.16, green: 0.18, blue: 0.24), Color(red: 0.26, green: 0.28, blue: 0.34)]
        case .rain, .snow: return [Color(red: 0.12, green: 0.16, blue: 0.26), Color(red: 0.22, green: 0.26, blue: 0.36)]
        case .thunder: return [Color(red: 0.13, green: 0.10, blue: 0.24), Color(red: 0.24, green: 0.20, blue: 0.36)]
        }
    }
}

/// この先の雨の見通し（F0294）。
@MainActor
struct RainOutlookView: View {
    let snapshot: WeatherSnapshot
    let now: Date

    var body: some View {
        if let outlook = WeatherInsights.rainOutlook(for: snapshot, now: now) {
            Label(WeatherInsights.rainOutlookText(outlook, timeZone: snapshot.timeZone), systemImage: symbol(outlook))
                .font(.subheadline)
        }
    }

    private func symbol(_ outlook: RainOutlook) -> String {
        switch outlook {
        case .precipitatingNow(let isSnow): return isSnow ? "snowflake" : "umbrella.fill"
        case .startsAround: return "umbrella"
        case .unlikely: return "sun.max"
        }
    }
}
