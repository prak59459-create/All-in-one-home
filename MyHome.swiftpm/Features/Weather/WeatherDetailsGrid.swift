import SwiftUI

/// 今日の詳細（F0286、F0293、F0295–F0300）。
@MainActor
struct WeatherDetailsGrid: View {
    let snapshot: WeatherSnapshot
    let data: WeatherData
    let now: Date

    var body: some View {
        let current: CurrentWeather = snapshot.current
        let today: DailyWeather? = snapshot.upcomingDays(from: now).first
        let zone: TimeZone = snapshot.timeZone
        WeatherSection(title: "詳細", symbol: "list.bullet.rectangle") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: DesignTokens.Spacing.small)], spacing: DesignTokens.Spacing.small) {
                WeatherDetailTile(title: "体感温度", symbol: "thermometer.medium", value: WeatherFormat.temperatureText(current.apparentTemperature, unit: data.temperatureUnit))
                WeatherDetailTile(title: "湿度", symbol: "humidity", value: WeatherFormat.percentText(current.humidity))
                WeatherDetailTile(title: "風", symbol: "wind", value: WeatherFormat.windText(current.windSpeed, direction: current.windDirection, unit: data.windSpeedUnit))
                WeatherDetailTile(title: "降水量（直前）", symbol: "drop", value: WeatherFormat.precipitationText(current.precipitation))
                WeatherDetailTile(title: "今日の降水量", symbol: "cloud.rain", value: WeatherFormat.precipitationText(today?.precipitationSum))
                WeatherDetailTile(title: "UV 指数（最大）", symbol: "sun.max", value: WeatherFormat.uvIndexText(today?.uvIndexMax))
                WeatherDetailTile(title: "日の出", symbol: "sunrise", value: clock(today?.sunrise, zone))
                WeatherDetailTile(title: "日の入り", symbol: "sunset", value: clock(today?.sunset, zone))
            }
        }
    }

    private func clock(_ time: Int?, _ zone: TimeZone) -> String {
        guard let time else { return WeatherFormat.placeholder }
        return WeatherFormat.clockText(time, timeZone: zone)
    }
}

@MainActor
struct WeatherDetailTile: View {
    let title: String
    let symbol: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.small)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
        .accessibilityElement(children: .combine)
    }
}
