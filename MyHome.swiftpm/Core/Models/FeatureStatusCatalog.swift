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
            entry("folders", "フォルダ・ページの管理・取り消し", .available, "フォルダは1段まで。ページは空の時だけ削除できます。取り消しはアプリを開いている間だけです。"),
            entry("widgets", "アプリ内ウィジェット（時計・カレンダー・メモ・タイマー）", .available, "ページの上部に置きます。編集中にタップで大きさや表示を変えられます。"),
            entry("wallpaper", "壁紙の写真・アイコンの画像", .available, "選んだ写真だけを受け取ります（写真へのアクセスの許可は不要）。iPadOS 自体の壁紙は変えられません。"),
            entry("timer", "タイマー・ストップウォッチ", .available, "アプリを閉じている間は音が鳴りません（iPadOS の制限）。"),
            entry(
                "miniapps",
                "ミニアプリ（メモ・タスク・電卓・単位変換・テキストツール）",
                .available,
                "データはミニアプリごとに別のファイルへ自動で保存し、開いた時だけ読み込みます。iCloud での同期はしません。"
            ),
            entry("update", "ソフトウェアアップデート", .available, "設定から。GitHub のブランチから変わったファイルだけを書き込みます。書き込んだ後は Swift Playgrounds で実行し直してください（アプリ自身はビルドし直せません）。"),
            entry(
                "weather",
                "天気（Open-Meteo）",
                .available,
                "通信は、天気の画面でオンにするまで行いません。位置情報は使わず、都市名で探した場所の天気を表示します。前回の天気は通信できない時も表示します。"
            )
        ]
        return entries
    }

    private static func stubs() -> [FeatureStatusEntry] {
        let entries: [FeatureStatusEntry] = [
            aiEntry()
        ]
        return entries
    }

    private static func planned() -> [FeatureStatusEntry] {
        let entries: [FeatureStatusEntry] = [
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

    /// AI は端末によって状態が違う（Apple の端末内モデルが使えれば本物、使えなければスタブだけ）。
    private static func aiEntry() -> FeatureStatusEntry {
        if LLMRuntime.isSystemModelAvailable {
            return entry("ai", "AI アシスタント", .available, "Apple の端末内モデルで答えます。入力した文章は端末の外に送りません。読み込みは AI 画面でボタンを押した時だけです。")
        }
        return entry("ai", "AI アシスタント", .stub, "この端末では Apple の端末内モデルが使えないため、スタブ（決まった文を返すだけ）です。理由は AI 画面に表示します。llama.cpp は Swift Playgrounds のアプリでは使えない見込みです（別ブランチの PoC の結果）。")
    }

    private static func entry(_ id: String, _ title: String, _ state: FeatureState, _ note: String) -> FeatureStatusEntry {
        FeatureStatusEntry(id: id, title: title, state: state, note: note)
    }
}
