import Observation

/// 項目から開くシート。
enum AppSheet: Identifiable, Hashable, Sendable {
    case feature(AppFeature)
    case unavailable(AppFeature)

    var id: String {
        switch self {
        case .feature(let feature): return "feature.\(feature.rawValue)"
        case .unavailable(let feature): return "unavailable.\(feature.rawValue)"
        }
    }
}

/// 項目から出すダイアログ。
enum AppAlert: Hashable, Sendable {
    case confirmURL(CheckedURL)
    case message(String)

    var title: String {
        switch self {
        case .confirmURL: return "リンクを開きますか？"
        case .message: return "開けません"
        }
    }

    var message: String {
        switch self {
        case .confirmURL(let checked): return checked.confirmationMessage
        case .message(let text): return text
        }
    }
}

/// シートとダイアログの表示状態。何をするかの判断は LaunchPlanner に任せる。
@MainActor
@Observable
final class AppRouter {
    var sheet: AppSheet?
    private(set) var alert: AppAlert?

    init() {}

    func launch(_ item: HomeItem) {
        switch LaunchPlanner.plan(for: item.action) {
        case .confirmURL(let checked):
            alert = .confirmURL(checked)
        case .rejectURL(let reason):
            alert = .message(reason.message)
        case .openFeature(let feature):
            sheet = .feature(feature)
        case .explainUnavailable(let feature):
            sheet = .unavailable(feature)
        }
    }

    /// ブラウザや他アプリへの受け渡しに失敗した時に呼ぶ。
    func reportOpenFailure(_ checked: CheckedURL) {
        alert = .message("「\(checked.destination)」を開けませんでした。対応するアプリがインストールされていない可能性があります。")
    }

    /// SwiftUI の alert(isPresented:) 用。false を設定するとダイアログを閉じる。
    var isShowingAlert: Bool {
        get { alert != nil }
        set {
            if !newValue {
                alert = nil
            }
        }
    }
}
