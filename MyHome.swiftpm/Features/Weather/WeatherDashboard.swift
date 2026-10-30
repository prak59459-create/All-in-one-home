import SwiftUI

/// 天気の本体（F0284–F0307）。場所の切り替え、取得の状態、今の天気、雨の見通し、時間別・日別の予報、詳細、出典。
@MainActor
struct WeatherDashboard: View {
    let controller: WeatherController
    let location: WeatherLocation
    let snapshot: WeatherSnapshot
    let onAddLocation: @MainActor () -> Void

    var body: some View {
        let data: WeatherData = controller.data
        let now: Date = Date()
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                WeatherLocationBar(controller: controller, onAdd: onAddLocation)
                WeatherStatusView(controller: controller, snapshot: snapshot, now: now)
                CurrentWeatherCard(location: location, snapshot: snapshot, data: data, now: now)
                RainOutlookView(snapshot: snapshot, now: now)
                HourlyForecastStrip(hours: snapshot.upcomingHours(from: now, count: 24), timeZone: snapshot.timeZone, unit: data.temperatureUnit, now: now)
                DailyForecastList(days: snapshot.upcomingDays(from: now), timeZone: snapshot.timeZone, unit: data.temperatureUnit, now: now)
                WeatherDetailsGrid(snapshot: snapshot, data: data, now: now)
                WeatherAttributionView()
                    .padding(.top, DesignTokens.Spacing.small)
            }
            .padding(DesignTokens.Spacing.medium)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .refreshable {
            await controller.refresh(force: true)
        }
    }
}

/// 登録した場所の切り替え（F0303）と、場所の追加。
@MainActor
struct WeatherLocationBar: View {
    let controller: WeatherController
    let onAdd: @MainActor () -> Void

    var body: some View {
        let data: WeatherData = controller.data
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.small) {
                ForEach(data.locations) { (location: WeatherLocation) in
                    LocationChip(name: location.name, isSelected: location.id == data.selectedLocation?.id) {
                        Task {
                            await controller.select(location.id)
                        }
                    }
                }
                Button {
                    onAdd()
                } label: {
                    Label("場所を追加", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .disabled(!data.isNetworkEnabled || data.locations.count >= WeatherData.maximumLocations)
            }
        }
    }
}

@MainActor
struct LocationChip: View {
    let name: String
    let isSelected: Bool
    let action: @MainActor () -> Void

    var body: some View {
        Button(name) {
            action()
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? Color.accentColor : Color.secondary)
        .fontWeight(isSelected ? .semibold : .regular)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// いつの天気か・更新の操作・失敗や通信オフの説明（F0304–F0307）。
@MainActor
struct WeatherStatusView: View {
    let controller: WeatherController
    let snapshot: WeatherSnapshot
    let now: Date

    var body: some View {
        let isNetworkEnabled: Bool = controller.data.isNetworkEnabled
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            HStack {
                Text(updatedText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                if controller.isRefreshing {
                    ProgressView()
                } else {
                    Button {
                        Task {
                            await controller.refresh(force: true)
                        }
                    } label: {
                        Label("更新", systemImage: "arrow.clockwise")
                    }
                    .disabled(!isNetworkEnabled)
                }
            }
            if !isNetworkEnabled {
                WeatherNotice(
                    text: "通信はオフです。表示しているのは前回取得した天気です。",
                    symbol: "wifi.slash",
                    actionTitle: "オンにする"
                ) {
                    controller.enableNetwork()
                }
            } else if let error = controller.lastError {
                WeatherNotice(text: "更新できませんでした。" + error.message + " 表示しているのは前回取得した天気です。", symbol: "exclamationmark.triangle.fill")
            }
        }
    }

    private var updatedText: String {
        let age: String = WeatherFormat.ageText(since: snapshot.fetchedDate, now: now)
        let isOld: Bool = now.timeIntervalSince(snapshot.fetchedDate) > 3 * 3_600
        return "\(age)に取得" + (isOld ? "（古いデータです）" : "")
    }
}

@MainActor
struct WeatherNotice: View {
    let text: String
    let symbol: String
    var actionTitle: String? = nil
    var action: (@MainActor () -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.small) {
            Image(systemName: symbol)
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let actionTitle, let action {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.bordered)
            }
        }
        .font(.footnote)
        .padding(DesignTokens.Spacing.small)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
    }
}
