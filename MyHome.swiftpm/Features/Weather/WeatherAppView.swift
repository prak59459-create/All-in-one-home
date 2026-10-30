import SwiftUI

/// 天気（F0281–F0320）。データ（設定・場所・前回の天気）は Apps/weather.json。通信は、この画面でオンにするまで行わない。
@MainActor
struct WeatherAppView: View {
    @Environment(MiniAppLibrary.self) private var library
    @State private var controller: WeatherController?

    var body: some View {
        let document: MiniAppDocument<WeatherData> = library.document(WeatherData.self)
        MiniAppScaffold(title: "天気") {
            MiniAppHost(document: document) {
                if let controller {
                    WeatherScreen(controller: controller)
                } else {
                    ProgressView()
                }
            }
        }
        .task {
            if controller == nil {
                controller = WeatherController(document: document, client: OpenMeteoClient(transport: WeatherURLSessionTransport.shared))
            }
        }
    }
}

/// 状態に合わせて、同意の説明・場所の追加・天気のどれかを出す。
@MainActor
struct WeatherScreen: View {
    let controller: WeatherController
    @State private var isShowingSettings: Bool = false
    @State private var isShowingSearch: Bool = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        content
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Label("天気の設定", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                WeatherSettingsView(controller: controller)
            }
            .sheet(isPresented: $isShowingSearch) {
                WeatherSearchView(controller: controller)
            }
            .task {
                await controller.refresh(force: false)
            }
            .onChange(of: scenePhase) { (_: ScenePhase, phase: ScenePhase) in
                if phase == .active {
                    Task {
                        await controller.refresh(force: false)
                    }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        let data: WeatherData = controller.data
        if let location = data.selectedLocation, let snapshot = data.snapshot(for: location.id) {
            WeatherDashboard(controller: controller, location: location, snapshot: snapshot) {
                isShowingSearch = true
            }
        } else if !data.isNetworkEnabled {
            WeatherConsentView {
                controller.enableNetwork()
                if controller.data.locations.isEmpty {
                    isShowingSearch = true
                }
            }
        } else if let location = data.selectedLocation {
            WeatherWaitingView(controller: controller, location: location)
        } else {
            ContentUnavailableView {
                Label("場所がありません", systemImage: "mappin.and.ellipse")
            } description: {
                Text("都市名で探して、天気を表示する場所を追加してください。")
            } actions: {
                Button("場所を追加") {
                    isShowingSearch = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

/// 場所はあるが、まだ天気がない時（取得中・失敗）。
@MainActor
struct WeatherWaitingView: View {
    let controller: WeatherController
    let location: WeatherLocation

    var body: some View {
        if let error = controller.lastError {
            ContentUnavailableView {
                Label("\(location.name)の天気を取得できませんでした", systemImage: "exclamationmark.icloud")
            } description: {
                Text(error.message)
            } actions: {
                Button("もう一度") {
                    Task {
                        await controller.refresh(force: true)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            ProgressView("\(location.name)の天気を取得しています…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
