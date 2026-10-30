import Observation

/// 開くシート。
enum AppSheet: Identifiable, Hashable, Sendable {
    case feature(AppFeature)
    case unavailable(AppFeature)
    /// 項目の追加（追加先のページ番号）。
    case addItem(pageIndex: Int)
    /// 項目の編集（名前・記号・色・移動先。項目 ID）。
    case editItem(String)
    /// ページの管理（追加・削除・並べ替え）。
    case managePages
    /// ウィジェットの設定（ウィジェット ID）。
    case editWidget(String)

    var id: String {
        switch self {
        case .feature(let feature): return "feature.\(feature.rawValue)"
        case .unavailable(let feature): return "unavailable.\(feature.rawValue)"
        case .addItem(let pageIndex): return "add.\(pageIndex)"
        case .editItem(let itemID): return "edit.\(itemID)"
        case .managePages: return "pages"
        case .editWidget(let widgetID): return "widget.\(widgetID)"
        }
    }
}

/// 出すダイアログ。
enum AppAlert: Hashable, Sendable {
    case confirmURL(CheckedURL)
    case message(String)
    /// 項目の削除の確認（F0042）。
    case confirmRemoval(HomeItem)
    /// 起動時の説明など、操作の結果ではないお知らせ。
    case notice(title: String, message: String)
    /// ウィジェットの削除の確認（F0163）。
    case confirmWidgetRemoval(HomeWidget)

    var title: String {
        switch self {
        case .confirmURL: return "リンクを開きますか？"
        case .message: return "開けません"
        case .confirmRemoval(let item):
            return item.isFolder ? "フォルダ「\(item.title)」を解除しますか？" : "「\(item.title)」を削除しますか？"
        case .notice(let title, _): return title
        case .confirmWidgetRemoval(let widget): return "ウィジェット「\(widget.kind.title)」を削除しますか？"
        }
    }

    var message: String {
        switch self {
        case .confirmURL(let checked): return checked.confirmationMessage
        case .message(let text): return text
        case .confirmRemoval(let item):
            if let children = item.folderItems {
                return "中の \(children.count) 個の項目は、フォルダのあった場所に戻します。項目は削除されません。"
            }
            return "ホーム画面から取り除きます。リンク先の Web ページや他のアプリには影響しません。"
        case .notice(_, let message): return message
        case .confirmWidgetRemoval: return "ホーム画面から取り除きます。メモの内容も消えます（取り消しで戻せます）。"
        }
    }
}

/// シート・ダイアログ・編集モードの状態。項目をタップした時に何をするかの判断は LaunchPlanner に任せる。
@MainActor
@Observable
final class AppRouter {
    var sheet: AppSheet?
    private(set) var alert: AppAlert?
    /// 編集モード（F0035）。編集中は項目をタップしても開かない。
    private(set) var isEditing: Bool = false
    /// 開いているフォルダ（項目 ID）。ホーム画面の上に重ねて表示する（シートにしないのは、
    /// フォルダの中から開いたリンクの確認ダイアログや機能のシートを、ホーム画面からそのまま出せるようにするため）。
    var openFolderID: String?
    /// 設定の中で開いているページ。設定を閉じたら空にする。
    var settingsPath: [SettingsPage] = []

    init() {}

    func launch(_ item: HomeItem) {
        guard !isEditing else { return }
        switch LaunchPlanner.plan(for: item.action) {
        case .confirmURL(let checked):
            alert = .confirmURL(checked)
        case .rejectURL(let reason):
            alert = .message(reason.message)
        case .openFeature(let feature):
            sheet = .feature(feature)
        case .explainUnavailable(let feature):
            sheet = .unavailable(feature)
        case .openFolder:
            openFolderID = item.id
        }
    }

    /// 編集中に項目をタップした時。名前・記号・色・移動先を変えるシートを開く。
    func presentItemEditor(for item: HomeItem) {
        sheet = .editItem(item.id)
    }

    func presentPageManager() {
        sheet = .managePages
    }

    func presentWidgetEditor(_ widget: HomeWidget) {
        sheet = .editWidget(widget.id)
    }

    func requestWidgetRemoval(_ widget: HomeWidget) {
        alert = .confirmWidgetRemoval(widget)
    }

    /// フォルダを開く（編集中でも開ける。中の項目の並べ替えや取り出しのため）。
    func openFolder(_ item: HomeItem) {
        guard item.isFolder else { return }
        openFolderID = item.id
    }

    func closeFolder() {
        openFolderID = nil
    }

    func beginEditing() {
        isEditing = true
    }

    func endEditing() {
        isEditing = false
    }

    /// 削除の確認を出す。削除できない項目では何もしない。
    func requestRemoval(of item: HomeItem) {
        guard item.isRemovable else { return }
        alert = .confirmRemoval(item)
    }

    func presentAddItem(pageIndex: Int) {
        sheet = .addItem(pageIndex: pageIndex)
    }

    func showNotice(title: String, message: String) {
        alert = .notice(title: title, message: message)
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
