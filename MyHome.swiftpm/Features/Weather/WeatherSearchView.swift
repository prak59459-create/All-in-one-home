import SwiftUI

/// 都市名で場所を探して登録する（F0281、F0302）。位置情報は使わない（F0283）。
@MainActor
struct WeatherSearchView: View {
    let controller: WeatherController
    @State private var query: String = ""
    @State private var failure: String?
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("都市名（例: 札幌、那覇、London）", text: $query)
                            .focused($isFocused)
                            .submitLabel(.search)
                            .autocorrectionDisabled()
                            .onSubmit {
                                search()
                            }
                        Button("検索") {
                            search()
                        }
                        .disabled(controller.isSearching)
                    }
                } footer: {
                    Text("入力した文字を Open-Meteo に送って探します。")
                }
                WeatherSearchResults(controller: controller, failure: failure) { (location: WeatherLocation) in
                    add(location)
                }
            }
            .navigationTitle("場所を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        controller.clearSearch()
                        dismiss()
                    }
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }

    private func search() {
        failure = nil
        let text: String = query
        Task {
            await controller.search(text)
        }
    }

    private func add(_ location: WeatherLocation) {
        Task {
            if let message = await controller.add(location) {
                failure = message
            } else {
                dismiss()
            }
        }
    }
}

@MainActor
struct WeatherSearchResults: View {
    let controller: WeatherController
    let failure: String?
    let onSelect: @MainActor (WeatherLocation) -> Void

    var body: some View {
        if controller.isSearching {
            Section {
                ProgressView("探しています…")
            }
        } else if let message = failure ?? controller.searchMessage {
            Section {
                Text(message)
                    .foregroundStyle(.secondary)
            }
        }
        if !controller.searchResults.isEmpty {
            Section("見つかった場所") {
                ForEach(controller.searchResults) { (location: WeatherLocation) in
                    Button {
                        onSelect(location)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(location.name)
                                .foregroundStyle(Color.primary)
                            Text(location.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
