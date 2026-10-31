import Foundation

/// バックアップに含めるミニアプリのデータ（Apps/<fileID>.json）の種類。
struct MiniAppDataKind: Sendable {
    let fileID: String
    let title: String
    /// 中身を確かめる。読めなければ理由を投げる。
    let validate: @Sendable (Data) throws -> Void
    /// 復元する時の調整。incoming はバックアップの中身、current は今のファイル（なければ nil）。
    let prepareForRestore: @Sendable (_ incoming: Data, _ current: Data?) throws -> Data

    var path: String {
        "Apps/\(fileID).json"
    }
}

/// ミニアプリのデータの一覧。ミニアプリ（MiniAppContent）を増やしたら、ここにも足す（足さないとバックアップに入らない）。
enum MiniAppDataCatalog {
    static let all: [MiniAppDataKind] = [
        plain(NoteBook.self, feature: .notes),
        plain(TodoList.self, feature: .tasks),
        plain(CalculatorState.self, feature: .calculator),
        plain(ConverterState.self, feature: .unitConverter),
        plain(TextToolsState.self, feature: .textTools),
        weather()
    ]

    static func kind(path: String) -> MiniAppDataKind? {
        all.first { (kind: MiniAppDataKind) -> Bool in kind.path == path }
    }

    private static func plain<Content: MiniAppContent>(_ type: Content.Type, feature: AppFeature) -> MiniAppDataKind {
        MiniAppDataKind(
            fileID: Content.fileID,
            title: feature.title,
            validate: { (data: Data) throws in
                _ = try MiniAppArchiveCodec.decode(Content.self, from: data)
            },
            prepareForRestore: { (incoming: Data, _: Data?) -> Data in incoming }
        )
    }

    /// 天気: 通信の同意は、今の端末の状態を引き継ぐ。バックアップから戻しても、勝手に通信を始めない（Phase 7 の約束）。
    private static func weather() -> MiniAppDataKind {
        MiniAppDataKind(
            fileID: WeatherData.fileID,
            title: AppFeature.weather.title,
            validate: { (data: Data) throws in
                _ = try MiniAppArchiveCodec.decode(WeatherData.self, from: data)
            },
            prepareForRestore: { (incoming: Data, current: Data?) throws -> Data in
                var restored: WeatherData = try MiniAppArchiveCodec.decode(WeatherData.self, from: incoming)
                restored.isNetworkEnabled = currentWeatherConsent(current)
                return try MiniAppArchiveCodec.encode(restored)
            }
        )
    }

    private static func currentWeatherConsent(_ current: Data?) -> Bool {
        guard let current, let data = try? MiniAppArchiveCodec.decode(WeatherData.self, from: current) else {
            return false
        }
        return data.isNetworkEnabled
    }
}
