/// 「機能の状況」画面の1行。
struct FeatureStatusEntry: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let state: FeatureState
    let note: String
}

/// アプリ内に表示する機能の状況。未実装・スタブ・OS 制限を隠さずに示す。
/// Phase が進んだらここを更新する（TASKS.md と食い違わないようにする）。
enum FeatureStatusCatalog {
    static func entries() -> [FeatureStatusEntry] {
        available() + stubs() + planned() + limited()
    }

    private static func available() -> [FeatureStatusEntry] {
        let entries: [FeatureStatusEntry] = [
            entry("home", "ホーム画面（時計・アイコン・ページ・Dock）", .available, "アイコンを長押しすると編集できます。"),
            entry("links", "Web リンク・URL スキームの起動と登録", .available, "開く前に確認します。危険なスキームは開かず、登録もできません。"),
            entry("theme", "テーマ（4種類、ライト / ダーク）", .available, "変更は自動で保存します。"),
            entry("edit", "配置の編集・保存", .available, "項目の追加・削除・名前や記号の変更、ページ・Dock・フォルダをまたぐ移動。再起動後も復元します。"),
            entry("folders", "フォルダ・ページの管理・取り消し", .available, "フォルダは1段まで。ページは空の時だけ削除できます。取り消しはアプリを開いている間だけです。")
        ]
        return entries
    }

    private static func stubs() -> [FeatureStatusEntry] {
        let entries: [FeatureStatusEntry] = [
            entry("ai", "AI アシスタント", .stub, "モデル未導入です。スタブの応答だけを返し、実際の推論は行いません。実推論は Phase 6 で PoC を行ってから判断します。")
        ]
        return entries
    }

    private static func planned() -> [FeatureStatusEntry] {
        let entries: [FeatureStatusEntry] = [
            entry("widgets", "ウィジェット・壁紙画像・タイマー", .planned(phase: 4), "アプリ内のウィジェットです。"),
            entry("miniapps", "メモ・電卓などのミニアプリ", .planned(phase: 5), ""),
            entry("weather", "天気", .planned(phase: 7), "天気 API は未設定です。"),
            entry("backup", "バックアップと復元", .planned(phase: 9), "")
        ]
        return entries
    }

    private static func limited() -> [FeatureStatusEntry] {
        let entries: [FeatureStatusEntry] = [
            entry("replace-home", "iPadOS の標準ホーム画面の置き換え", .osLimited, "このアプリの中だけで動くランチャーです。"),
            entry("app-list", "インストール済みアプリの一覧の取得", .osLimited, "公開された方法がないため、URL スキームを登録して起動します。"),
            entry("network-detail", "Wi-Fi 名・セルラーの詳細", .osLimited, "一般のアプリには公開されていません。"),
            entry("background", "アプリを閉じている間のタイマー・推論", .osLimited, "OS が制限します。通知などで代替します。"),
            entry("home-widgets", "iPadOS のホーム画面に置くウィジェット", .needsPoC, "アプリ内ウィジェットとは別機能です。Swift Playgrounds で作れるかは未確認です。")
        ]
        return entries
    }

    private static func entry(_ id: String, _ title: String, _ state: FeatureState, _ note: String) -> FeatureStatusEntry {
        FeatureStatusEntry(id: id, title: title, state: state, note: note)
    }
}
