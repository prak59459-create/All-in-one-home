import SwiftUI

/// 通信の同意（F0841）。何を・どこへ送るかを示し、利用者が「オンにする」を押すまで通信しない。
@MainActor
struct WeatherConsentView: View {
    let onEnable: @MainActor () -> Void

    var body: some View {
        Form {
            Section {
                Label {
                    Text("天気を表示するには、Open-Meteo（open-meteo.com）と通信します。オンにするまで、通信は一切しません。")
                } icon: {
                    Image(systemName: "cloud.sun.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            Section("送るもの") {
                Text("都市を探す時に入力した文字")
                Text("選んだ場所の緯度・経度（小数 4 桁まで）")
            }
            Section {
                Text("端末の位置情報（位置情報の許可は求めません）")
                Text("名前・メールアドレスなどの個人情報（アカウントも API キーも不要です）")
            } header: {
                Text("送らないもの")
            } footer: {
                Text("通信の仕組み上、通信の相手には IP アドレスが伝わります。")
            }
            Section {
                Button("通信をオンにする") {
                    onEnable()
                }
                .frame(maxWidth: .infinity)
            } footer: {
                Text("天気の画面の右上の設定から、いつでもオフにできます。")
            }
            Section {
                WeatherAttributionView()
            }
        }
    }
}

/// Open-Meteo のデータの出典（CC BY 4.0 の条件。データを表示する場所の近くにリンクを置く）。
@MainActor
struct WeatherAttributionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            ExternalLinkButton(title: "Weather data by Open-Meteo.com", address: "https://open-meteo.com/")
            ExternalLinkButton(title: "ライセンス: CC BY 4.0", address: "https://creativecommons.org/licenses/by/4.0/")
            Text("天気の名前・単位の換算・雨の見通しは、このアプリで付けています。場所の検索のデータは GeoNames（Open-Meteo 経由）。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .font(.footnote)
    }
}

/// 外部のページを開くボタン。開く前に確認する（ホーム画面のリンクと同じ方針）。
@MainActor
struct ExternalLinkButton: View {
    let title: String
    let address: String
    @State private var isConfirming: Bool = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button(title) {
            isConfirming = true
        }
        .buttonStyle(.borderless)
        .confirmationDialog("Safari で開きますか？", isPresented: $isConfirming, titleVisibility: .visible) {
            Button("開く") {
                if let url = URL(string: address) {
                    openURL(url)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text(address)
        }
    }
}
