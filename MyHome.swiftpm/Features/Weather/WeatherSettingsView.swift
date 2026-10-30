import SwiftUI

/// 天気の設定: 単位（F0311、F0312）、登録した場所の並べ替え・削除、通信のオン・オフ。
@MainActor
struct WeatherSettingsView: View {
    let controller: WeatherController
    @State private var isConfirmingOff: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                unitsSection
                locationsSection
                networkSection
                Section("データについて") {
                    WeatherAttributionView()
                    Text("取得した天気は、場所ごとに最後の1回分だけをこの iPad に保存します（通信できない時に表示するため）。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("天気の設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("天気の通信をオフにしますか？", isPresented: $isConfirmingOff, titleVisibility: .visible) {
                Button("オフにする（前回の天気は残す）") {
                    controller.disableNetwork(deleteSavedWeather: false)
                }
                Button("オフにして、保存した天気も消す", role: .destructive) {
                    controller.disableNetwork(deleteSavedWeather: true)
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("オフの間は、検索も更新もしません。登録した場所は残ります。")
            }
        }
    }

    private var unitsSection: some View {
        Section("単位") {
            Picker("気温", selection: temperatureUnit) {
                ForEach(TemperatureUnit.allCases) { (unit: TemperatureUnit) in
                    Text(unit.title).tag(unit)
                }
            }
            Picker("風速", selection: windSpeedUnit) {
                ForEach(WindSpeedUnit.allCases) { (unit: WindSpeedUnit) in
                    Text(unit.symbol).tag(unit)
                }
            }
        }
    }

    private var locationsSection: some View {
        Section {
            ForEach(controller.data.locations) { (location: WeatherLocation) in
                VStack(alignment: .leading, spacing: 2) {
                    Text(location.name)
                    Text(location.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { (offsets: IndexSet) in
                let ids: [Int] = offsets.map { (offset: Int) -> Int in controller.data.locations[offset].id }
                for id in ids {
                    controller.removeLocation(id: id)
                }
            }
            .onMove { (source: IndexSet, destination: Int) in
                controller.moveLocations(fromOffsets: source, toOffset: destination)
            }
        } header: {
            Text("場所（\(controller.data.locations.count) / \(WeatherData.maximumLocations)）")
        } footer: {
            Text("左へスワイプで削除できます。並べ替えは左上の「編集」から。")
        }
    }

    private var networkSection: some View {
        Section {
            if controller.data.isNetworkEnabled {
                Button("天気の通信をオフにする", role: .destructive) {
                    isConfirmingOff = true
                }
            } else {
                Button("天気の通信をオンにする") {
                    controller.enableNetwork()
                }
            }
        } header: {
            Text("通信")
        } footer: {
            Text(controller.data.isNetworkEnabled ? "Open-Meteo と通信して、天気を取得しています。" : "通信はオフです。Open-Meteo とは通信しません。")
        }
    }

    private var temperatureUnit: Binding<TemperatureUnit> {
        Binding<TemperatureUnit>(
            get: { controller.data.temperatureUnit },
            set: { (unit: TemperatureUnit) in
                controller.document.update { (data: inout WeatherData) in
                    data.temperatureUnit = unit
                }
            }
        )
    }

    private var windSpeedUnit: Binding<WindSpeedUnit> {
        Binding<WindSpeedUnit>(
            get: { controller.data.windSpeedUnit },
            set: { (unit: WindSpeedUnit) in
                controller.document.update { (data: inout WeatherData) in
                    data.windSpeedUnit = unit
                }
            }
        )
    }
}
