/// 使い方と困った時（F0963–F0967、F0970–F0972、F0998、F0999）。設定 → 使い方と困った時 で表示する。
/// 画面の言葉（ボタンの名前など）は実際の画面と同じにする。機能を変えたらここも直す。
struct HelpTopic: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let symbol: String
    let steps: [String]
}

struct HelpSection: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let topics: [HelpTopic]
}

enum HelpCatalog {
    static func sections() -> [HelpSection] {
        [
            HelpSection(id: "basics", title: "基本の操作", topics: basics()),
            HelpSection(id: "apps", title: "ミニアプリと機能", topics: apps()),
            HelpSection(id: "data", title: "データ", topics: data()),
            HelpSection(id: "trouble", title: "困った時", topics: trouble()),
            HelpSection(id: "keyboard", title: "キーボード", topics: keyboard())
        ]
    }

    /// 見出しと手順の文で探す（大文字小文字・全角半角を区別しない。語を空白で区切ると、全部を含むものだけ）。
    static func search(_ query: String) -> [HelpSection] {
        let terms: [String] = TextSearch.terms(in: query)
        guard !terms.isEmpty else { return sections() }
        return sections().compactMap { (section: HelpSection) -> HelpSection? in
            let topics: [HelpTopic] = section.topics.filter { (topic: HelpTopic) -> Bool in
                TextSearch.matches(terms, in: [section.title, topic.title] + topic.steps)
            }
            return topics.isEmpty ? nil : HelpSection(id: section.id, title: section.title, topics: topics)
        }
    }

    private static func basics() -> [HelpTopic] {
        [
            HelpTopic(id: "edit", title: "ホーム画面を編集する", symbol: "square.and.pencil", steps: [
                "アイコンを長押しして「ホーム画面を編集」を選びます。",
                "編集中は、アイコンを長押しして別のアイコン・フォルダ・ページの点・Dock に重ねると移動します。",
                "アイコンをタップすると、名前・記号・色・移動先を変えられます。左上の − で削除します（確認があります）。",
                "上のバーの「取り消す」「やり直す」で 30 回まで戻せます（アプリを開いている間だけ）。終わったら「完了」。"
            ]),
            HelpTopic(id: "add", title: "項目・ウィジェットを追加する", symbol: "plus.app", steps: [
                "編集中に上のバーの「追加」を押します。",
                "Web リンク・URL スキーム・アプリ内の機能・ウィジェットから選びます。",
                "外部のリンクは、開く前に確認します。危険な種類のリンク（javascript: など）は登録できません。",
                "ウィジェットは MyHome の中だけのもので、1ページに \(WidgetLimits.maximumPerPage) 個まで置けます。"
            ]),
            HelpTopic(id: "folders", title: "フォルダを作る", symbol: "folder", steps: [
                "編集中に、アイコンを別のアイコンに重ねるとフォルダになります。",
                "フォルダの中にフォルダは作れません（1段まで）。",
                "空になったフォルダは自動で消えます。"
            ]),
            HelpTopic(id: "pages", title: "ページを切り替える・増やす", symbol: "rectangle.stack", steps: [
                "横にスワイプするか、ページの点をタップします。",
                "編集中に上のバーの「ページ」で、ページの追加・並べ替え・削除（空のページだけ）ができます。"
            ]),
            HelpTopic(id: "looks", title: "見た目・動き・文字の大きさ", symbol: "paintbrush", steps: [
                "設定で、テーマ・ライトとダーク・壁紙（写真）・時計の秒を変えられます。",
                "設定の「動きと文字」で、アニメーションを減らす・なくすことと、このアプリの文字の大きさを選べます。",
                "iPadOS 自体の壁紙やホーム画面は、このアプリからは変えられません。"
            ])
        ]
    }

    private static func apps() -> [HelpTopic] {
        [
            HelpTopic(id: "miniapps", title: "メモ・タスク・電卓・単位変換・テキストツール", symbol: "square.grid.2x2", steps: [
                "データはミニアプリごとに、この iPad の中へ自動で保存します。iCloud での同期はしません。",
                "削除したメモやタスクは元に戻せません。"
            ]),
            HelpTopic(id: "timer", title: "タイマー", symbol: "timer", steps: [
                "アプリを閉じている間は音が鳴りません（iPadOS の制限）。開いた時に、終わったタイマーを知らせます。"
            ]),
            HelpTopic(id: "ai", title: "AI", symbol: "sparkles", steps: [
                "iPadOS 26 以降の Apple Intelligence に対応した iPad では、Apple の端末内モデルで答えます。入力した文章は端末の外に送りません。",
                "使えない時はスタブ（決まった文を返すだけ）になり、使えない理由を AI の画面に表示します。"
            ]),
            HelpTopic(id: "weather", title: "天気", symbol: "cloud.sun", steps: [
                "天気の画面で「通信をオンにする」を押すまで、通信はしません。",
                "都市名で場所を探して追加します（位置情報は使いません）。",
                "通信できない時は、前回取得した天気を表示します。右上の設定から通信をオフにできます。"
            ]),
            HelpTopic(id: "update", title: "ソフトウェアアップデート", symbol: "arrow.down.circle", steps: [
                "設定 → ソフトウェアアップデート で、GitHub のブランチから変わったファイルだけを MyHome.swiftpm に書き込みます。",
                "書き込んだ後は、Swift Playgrounds でプロジェクトを開き直して実行してください（アプリ自身はビルドし直せません）。"
            ])
        ]
    }

    private static func data() -> [HelpTopic] {
        [
            HelpTopic(id: "backup", title: "バックアップと復元", symbol: "externaldrive", steps: [
                "設定 → バックアップと復元 の「ファイルに書き出す」で、ホーム画面の配置・設定・タイマー、ミニアプリのデータ、アイコンと壁紙の画像を 1 つのファイルにまとめ、ファイルアプリ（iCloud Drive など）に保存します。",
                "「この iPad に保存」は MyHome の中に残します。MyHome を削除すると一緒に消えます。",
                "「ファイルから復元」でファイルを選ぶと、中身を確かめてから、戻すもの（ホーム画面・ミニアプリごと）を選んで復元できます。",
                "復元する前の状態は、自動で「この iPad のバックアップ」（復元の前）に残ります。元に戻したい時は、それを選んで復元します。",
                "天気の通信のオン・オフは、復元しても今の設定のままです。動いていたタイマーは止めた状態で戻ります。"
            ]),
            HelpTopic(id: "erase", title: "すべてのデータを消す", symbol: "trash", steps: [
                "設定 → バックアップと復元 の「すべてのデータを消す」で、初めて起動した時の状態に戻します。",
                "消す前のデータは「この iPad のバックアップ」（消去の前）に残ります。残したくない時は、一覧から削除してください。"
            ]),
            HelpTopic(id: "privacy", title: "通信とデータの保存先", symbol: "hand.raised", steps: [
                "設定 → このアプリについて に、使う OS の許可（ありません）、通信する相手、データの保存先、出典とライセンスをまとめています。"
            ])
        ]
    }

    private static func trouble() -> [HelpTopic] {
        [
            HelpTopic(id: "save-failed", title: "「保存できませんでした」と出る", symbol: "exclamationmark.triangle", steps: [
                "iPad の空き容量を確かめてください。次に変更した時に、もう一度保存します。",
                "設定の「保存」の欄に理由を表示します。"
            ]),
            HelpTopic(id: "reset-layout", title: "配置が初めの状態に戻った", symbol: "arrow.counterclockwise", steps: [
                "保存ファイルが読めなかった時は、元のファイルを消さずに別の名前でアプリの中に残し、初めの配置で起動します。",
                "その時は、起動した時に理由を表示します。"
            ]),
            HelpTopic(id: "after-update", title: "アップデートの後にうまく動かない", symbol: "clock.arrow.circlepath", steps: [
                "設定 → ソフトウェアアップデート の「最後の更新の前に戻す」で、書き込む前の状態に戻せます。",
                "戻した後は、Swift Playgrounds でもう一度実行してください。"
            ]),
            HelpTopic(id: "restore-failed", title: "「このバックアップは使えません」と出る", symbol: "externaldrive.badge.xmark", steps: [
                "MyHome で書き出したバックアップのファイル（.json）かを確かめてください。新しい版の MyHome で作ったものは、アップデートしてから読み込みます。",
                "中に 1 つでも読めないデータがあると、何も変えずに中止します。"
            ]),
            HelpTopic(id: "weather-stale", title: "天気が更新されない", symbol: "cloud.sun", steps: [
                "天気の通信がオンになっているか、インターネットにつながっているかを確かめてください。",
                "Open-Meteo の利用回数の上限に達した時は、しばらく待ってから更新してください。"
            ]),
            HelpTopic(id: "limits", title: "このアプリでできないこと", symbol: "lock", steps: [
                "iPadOS のホーム画面の置き換え、他のアプリの通知の取得、Wi-Fi・Bluetooth などの設定の変更、iPadOS の壁紙の変更はできません。",
                "詳しくはホーム画面の「機能の状況」を見てください。"
            ])
        ]
    }

    private static func keyboard() -> [HelpTopic] {
        [
            HelpTopic(id: "shortcuts", title: "キーボードショートカット", symbol: "keyboard", steps: [
                "⌘ キーを長押しすると、使えるショートカットの一覧が出ます（iPadOS の版によって出方が違います）。",
                "⌘, 設定 ／ ⌘E ホーム画面の編集 ／ ⌘← ⌘→ ページの移動 ／ ⌘W 開いているアプリを閉じる",
                "編集中: ⌘Z 取り消す ／ ⇧⌘Z やり直す",
                "メモ: ⌘N 新しいメモ ／ 電卓: 数字と記号のキー"
            ])
        ]
    }
}
