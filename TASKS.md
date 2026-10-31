# TASKS — 進捗管理

状態ラベルの定義は [PLAN.md](PLAN.md) の「9. 状態ラベル」を参照（実機確認済 / テスト済 / ビルド済 / 対応 / 部分・スタブ / 計画中 / 要PoC / OS制限）。
機能IDの正本は [docs/feature-catalog.md](docs/feature-catalog.md)。ここに載っていない機能IDはすべて「計画中」。

## Phase 0 — 調査・ビルド計測（完了。iPad でのビルド時間のみ未計測）

| タスクID | 内容 | 状態 | 関連機能ID |
|---|---|---|---|
| T0-1 | リポジトリ・Git 状態・ビルド環境の調査 | 完了 | — |
| T0-2 | Playgrounds 用マニフェストと最小アプリ（`MyHome.swiftpm`） | ビルド済（Xcode 16.4 / 26.3） | F0917 |
| T0-3 | 検証用パッケージ（`Package.swift`、`Tests/`）で Core を Linux ビルド | テスト済（Swift 5.10.1 / 6.0.3 / 6.4.1） | F0882, F0888, F0889 |
| T0-4 | 計測スクリプト（Core / アプリ / Simulator 起動）と構文チェック | 完了 | F0890, F0891, F0892, F0918, F0921 |
| T0-5 | CI（Linux 3 バージョン、macOS 2 バージョンの Xcode） | 完了 | F1061–F1080 の一部 |
| T0-6 | 基準ビルド時間の記録 | Linux・macOS 済 / iPad 未計測 | F0890, F0891, F0892 |
| T0-7 | PLAN.md / TASKS.md / docs/BUILD.md / docs/BUILD_TIMES.md | 完了 | — |
| T0-8 | モデルファイルをリポジトリに含めない設定（`.gitignore`） | 完了 | F0898 |

## Phase 1 — 最小ホーム（実装済み・ビルド済。iPad 実機での起動はユーザーが確認）

| タスクID | 内容 | 状態 | 関連機能ID |
|---|---|---|---|
| T1-1 | Core モデル：`HomeItem` / `HomePage` / `HomeLayout` / テーマ / 初期レイアウト | テスト済 | F0002, F0039, F0645 |
| T1-2 | URL 検証と起動方針（確認付き起動、危険なスキームの拒否） | テスト済 | F0069–F0071, F0764–F0766, F0853, F0854 |
| T1-3 | 画面幅からの列数計算 | テスト済 | F0005, F0006 |
| T1-4 | SwiftUI：時計、アイコングリッド、ページ、ページインジケーター、Dock | ビルド済 | F0001, F0008, F0009, F0081, F0201, F0206, F0207 |
| T1-5 | テーマ選択（プリセット 4 種、ライト / ダーク）とデザイントークン | ビルド済（配色のコントラストはテスト済） | F0641–F0646, D1201, D1202 |
| T1-6 | 機能状況画面（未実装・スタブ・OS 制限を明示） | ビルド済 | F0080, F0971, F1200 |
| T1-7 | LLM 境界：プロトコル、スタブ、遅延ロード制御（依存なし）と AI 画面（スタブ） | テスト済（制御）/ ビルド済（画面） | F0361, F0379, F0392, F0896, F0897, F0945, F0948 |
| T1-8 | 0 件・1 ページ 150 件での Simulator 起動テスト | ビルド済（3通りとも 10 秒後も動作中。スクリーンショットで表示も確認） | F0950, F0909, F0988 |

### ユーザーに確認してほしいこと（まだ分かっていないこと）

1. ~~iPad の Swift Playgrounds で `MyHome.swiftpm` を開き、ビルドと起動ができるか~~ → 起動できたと報告あり（2026-10-29）。その際の「印の右上が切れる」不具合は修正済み。
2. 初回ビルドと、1ファイル変更後の再ビルドにかかった秒数（[docs/BUILD.md](docs/BUILD.md) の手順）。
3. Swift Playgrounds のバージョンと iPadOS のバージョン（iOS 17 SDK の版では未確認のため）。

## Phase 2 — 編集・保存（実装済み・テスト済 / ビルド済。実機での操作は未確認）

| タスクID | 内容 | 状態 | 関連機能ID |
|---|---|---|---|
| T2-1 | 保存形式: `HomeLayout` と設定の Codable 化（`schemaVersion` 1。未知のキーは読み飛ばす。設定は値ごとに初期値へ戻す。古い形式の移行の入口） | テスト済 | F0801–F0803, F0807, F0822, F0823 |
| T2-2 | 読み込みの検証: 壊れた JSON・新しい版の形式・ID の重複・長すぎる文字列・項目数の超過を拒否し、初期配置で起動して元のファイルを別名で残す | テスト済（Linux）/ ビルド済（Simulator で退避を確認） | F0821, F0824, F0940 |
| T2-3 | 保存処理: 一時ファイル経由の書き込み、0.5 秒の間引き、裏に回る時の即時保存、actor でメインスレッドの外・順番に実行、失敗の通知と再試行、設定画面の保存状態 | テスト済 | F0834–F0838, F0902 |
| T2-4 | 編集モード: 長押しメニューの「ホーム画面を編集」、編集中のバー（追加・完了）、編集中はタップで開かない | ビルド済 | F0035, F0036, F0077 |
| T2-5 | 削除（確認付き。設定は削除できない）と追加（Web リンク / URL スキーム / アプリ内の機能。URL は入力のたびに URLPolicy で判定） | テスト済（ロジック）/ ビルド済（画面） | F0041, F0042, F0068, F0069 |
| T2-6 | 並べ替え（同じページ・Dock の中）。ドラッグで重ねる操作と、VoiceOver の「前に移動」「後ろに移動」 | テスト済（ロジック）/ ビルド済（画面） | F0059 |
| T2-7 | 再起動後の復元 | テスト済（Linux で保存→作り直し→復元）/ ビルド済（Simulator で保存ファイルから復元） | Phase 2 の完了条件 |

Phase 2 で決めたこと:

- 保存済みの URL は読み込み時には拒否せず、開く時に URLPolicy で判定する。URLPolicy を将来厳しくした時に、保存済みの配置全体が読めなくなることを避けるため（登録時は入力のたびに判定する）。
- 「設定」は削除できない（ホーム画面から消すと設定を開く手段がなくなるため）。他の機能は削除しても「項目を追加」から戻せる。
- ページをまたぐ移動と Dock とページの間の移動、取り消しは Phase 3。

## Phase 3 — ページ・フォルダ・Dock 編集・取り消し（実装済み・テスト済 / ビルド済。実機での操作は未確認）

| タスクID | 内容 | 状態 | 関連機能ID |
|---|---|---|---|
| T3-1 | ページの管理: 一覧と項目数、追加、並べ替え、空のページの削除（項目が残るページと最後の1ページは削除できない） | テスト済（ロジック）/ ビルド済（画面） | F0010, F0011, F0012, F0015 |
| T3-2 | ページ・Dock・フォルダをまたぐ移動: 別の項目に重ねる、ページの点に重ねる（そのページを表示して末尾へ）、Dock やページの余白に落とす、項目の編集シートで移動先を選ぶ。Dock の上限を守る | テスト済（ロジック）/ ビルド済（画面） | F0061, F0083, F0085, F0100, F0147 |
| T3-3 | フォルダ: 作成（編集シートの「新しいフォルダを作って入れる」）、フォルダに重ねて入れる、中の並べ替えと取り出し、解除（中の項目は元の場所に戻す）、空のフォルダは自動で取り除く、階層は1段 | テスト済（ロジック）/ ビルド済（画面） | F0121, F0122, F0123, F0126–F0128, F0131, F0143, F0146, F0156, F0157 |
| T3-4 | 取り消し・やり直し（30 手まで、アプリを開いている間だけ。⌘Z / ⇧⌘Z） | テスト済（ロジック）/ ビルド済（画面） | F0032, F0033, F0034, F0160 |
| T3-5 | 項目の名前・記号・色の変更（編集中に項目をタップ） | テスト済（ロジック）/ ビルド済（画面） | F0044, F0046, F0050 |
| T3-6 | 保存形式の版 2（項目の種類にフォルダが増えた）。版 1 のファイルは移行して読む | テスト済（Linux）/ ビルド済（Simulator で版 1 のファイルから復元） | F0823, F0158, F0159 |

Phase 3 で決めたこと:

- フォルダの「削除」は解除にした（中の項目は消さずにフォルダのあった場所へ戻す）。項目を消す時は1つずつ削除する。
- ページは空の時だけ削除できる（項目を失わないため）。
- フォルダはシートではなくホーム画面の上に重ねて表示する。フォルダの中から開いたリンクの確認や機能のシートを、ホーム画面からそのまま出せるようにするため。
- 取り消しの履歴は保存しない（再起動すると消える）。

## Phase 4 — 壁紙・アイコン画像・ウィジェット・タイマー（実装済み・テスト済 / ビルド済。実機での操作は未確認）

| タスクID | 内容 | 状態 | 関連機能ID |
|---|---|---|---|
| T4-1 | 壁紙: 写真を選んで（PhotosPicker。写真へのアクセスの許可は不要）画面に合う大きさに縮小して保存、ぼかし・暗さの調整、テーマの背景に戻す。画像の上では文字を白にして影を付ける。ファイルがなければグラデーションに戻す | テスト済（保存・整理）/ ビルド済（画面） | F0646, F0647, F0650, F0651, F0827 |
| T4-2 | アイコンの画像: 編集シートで写真を選び、中央を正方形に切り出して小さく保存。外すと記号に戻る | テスト済（保存）/ ビルド済（画面） | F0047, F0048 |
| T4-3 | アプリ内ウィジェット: 時計（デジタル / アナログ、秒の表示）、今月のカレンダー（週の始まりは端末の設定）、メモ、タイマー。ページの上部に置き、追加・削除・並べ替え・大きさ（小・中）の変更。1ページ 8 個まで | テスト済（配置・保存）/ ビルド済（画面。編集モードのスクリーンショットで4種類の表示を確認） | F0161–F0168, F0179, F0189, F0202, F0203, F0241, F0243, F0260 |
| T4-4 | タイマー: 複数のカウントダウン（名前、よく使う時間）、ストップウォッチ（ラップ）。終了時刻を覚えるので、裏に回っていても戻った時に正しい残り時間。開いている間は終了時に音と知らせ | テスト済（時刻を進めたテスト）/ ビルド済（画面） | F0218–F0227, F0237 |
| T4-5 | ホーム画面の時計の秒の表示 | ビルド済 | F0203 |
| T4-6 | 保存形式の版 3（ウィジェット・項目の画像・壁紙・タイマー）。版 1・2 のファイルはそのまま読み、増えた値は初期値。使われていない画像は、読み込みに成功した起動の時だけ消す | テスト済 | F0805, F0806, F0811, F0823 |

Phase 4 で決めたこと:

- iPadOS のホーム画面に置くウィジェット（WidgetKit）と、iPadOS の壁紙の変更は作らない（前者は要PoC、後者は OS の制限）。アプリ内のものだけ。
- タイマーは、アプリを閉じている間は音を鳴らせない（通知の許可を使う方法は Phase 10 の通知の項目で検討）。
- 写真は選んだ1枚だけを受け取る方式にし、写真へのアクセスの許可を求めない。

## Phase 5 — ミニアプリ（実装済み・テスト済 / ビルド済。実機での操作は未確認）

| タスクID | 内容 | 状態 | 関連機能ID |
|---|---|---|---|
| T5-1 | ミニアプリの保存の土台: 1つのミニアプリにつき1ファイル（`Application Support/MyHome/Apps/<名前>.json`）。開いた時にメインスレッドの外で読み込み、変更から 0.5 秒でまとめて保存、裏に回る時はすぐ保存。読めないファイルは消さずに別名で残して空の状態で開き、理由を表示。新しい版のファイル・別のミニアプリのファイルは読まない | テスト済 | F0489, F0498, F0500 |
| T5-2 | メモ: 作成・編集（タイトルと本文）・自動保存・削除（確認付き）・ピン留め・検索（全角半角・大文字小文字を区別しない）・更新日時の新しい順・文字数と作成/更新日時の表示。何も書かずに閉じたメモは残さない | テスト済（データ）/ ビルド済（画面） | F0506, F0321–F0327, F0330, F0332–F0335, F0339, F0353, F0357 |
| T5-3 | タスク: 作成（期限: なし・今日・明日・1週間後）・完了・編集（名前・日付・優先度）・削除・検索。期限切れ・今日・これから・期限なし・完了に分けて表示し、期限の近い順・優先度の高い順に並べる。今日までのタスクをまとめて完了、完了したタスクをまとめて削除（確認付き） | テスト済（データ）/ ビルド済（画面） | F0265–F0273, F0275 |
| T5-4 | 電卓: 四則演算・かっこ・%・±・⌫。掛け算と割り算を先に計算し、10 進数で計算する（0.1 + 0.2 = 0.3）。15 桁で表示し、大きい数は指数で表す。0 で割った時は理由を出して式を残す。履歴（50 件、タップで再利用）。iPad のハードウェアキーボードでも打てる | テスト済（計算・入力・表示）/ ビルド済（画面） | F0504 |
| T5-5 | 単位変換: 長さ・重さ・温度・面積・体積・速さ・時間・データ量（尺・坪・合・貫などの日本の単位を含む）。入力した値を同じ種類のすべての単位で表示。全角の数字や「,」の区切りも読む | テスト済 / ビルド済（画面） | F0505 |
| T5-6 | テキストツール: 文字数（見た目の1文字で数える）・行数・語数・バイト数・原稿用紙の枚数の目安、行の整形（空白の削除・空行の削除・重複の削除・並べ替え・1行に）、全角⇔半角、大文字・小文字、Base64、URL エンコード、JSON の整形（キーの順と数の書き方を変えない。読めない時は行と文字の位置を示す）。直前の変換を元に戻せる | テスト済 / ビルド済（画面） | F0511–F0514 |
| T5-7 | ホームからの起動: 初期配置と「項目を追加」にミニアプリを追加し、準備中の印を外す。天気は Phase 7 まで「準備中」の項目として追加できる。起動引数 `-MyHomeOpenFeature <名前>` と、Simulator の起動テスト（ミニアプリ5つを保存ファイル付きで開く） | テスト済 / ビルド済（Simulator で5つとも保存ファイルから復元して表示） | F0481, F0487 |

Phase 5 で決めたこと:

- ミニアプリのデータは、ホーム画面の保存ファイル（home.json）とは別のファイルにした。あるミニアプリのファイルが壊れても、ホーム画面と他のミニアプリには影響しない。ホーム画面の起動時には読まない。
- 保存形式の版（home.json の版 3）は上げていない。機能の種類が増えただけなので、新しい項目（タスクなど）を含まない保存データは、古い版のアプリでもそのまま読める。古い版のアプリが新しい項目を含むファイルを読んだ時は、これまでどおり消さずに別名で残す。
- 削除の確認は、メモ1件と、完了したタスクをまとめて消す時に出す。タスク1件はスワイプの「削除」を押した時に消す（全体をスワイプしただけでは消えない）。
- 貼り付けは PasteButton を使い、他のアプリの内容を勝手に読まない。

## Phase 6 — ローカル LLM（Apple の端末内モデル。実装済み・テスト済 / ビルド済。実機での応答は未確認）

| タスクID | 内容 | 状態 | 関連機能ID |
|---|---|---|---|
| T6-1 | 端末内モデル（Foundation Models）が使えるかの判定と理由の表示。FoundationModels がない SDK（Xcode 16.4・iOS 18 SDK の Swift Playgrounds）ではビルドから外し、iPadOS 26 未満では実行時に使わない | テスト済（理由の受け渡し）/ ビルド済（iOS 18 SDK ではビルドから外れ、iOS 26 SDK ではコンパイルされる） | F0381, F0422 |
| T6-2 | 端末内モデルのプロバイダー: LocalLLMProvider に合わせて組み込む。会話の文脈はセッションが覚える。応答は全文から増えた分を取り出して流す。よくある失敗（会話が長すぎる・安全の制限・未対応の言語など）を日本語で説明 | テスト済（境界）/ ビルド済 / 実機未確認 | F0361, F0391, F0421, F0434 |
| T6-3 | AI 画面: モデルの選択（端末内モデル・スタブ）、読み込み・解放・新しい会話、使えない理由、端末内で処理することの説明、回答のコピー、生成中の自動スクロール | ビルド済 / Simulator で画面を確認（端末内モデルが使えない時。スタブが選ばれた理由が出ていなかったので、Phase 7 で表示を追加） | F0362, F0374, F0378–F0380, F0394, F0397–F0399 |
| T6-4 | AI の項目の状態: 端末内モデルが使えない端末だけ「スタブ」の印を付ける（起動時に一度調べる。モデルは読み込まない） | テスト済 / Simulator で確認（端末内モデルを使えない CI の Mac では、Dock の AI に「スタブ」の印が付く） | F0080 |
| T6-5 | llama.cpp の PoC（本体とは別のブランチ `claude/llama-cpp-poc`、[PR #2](https://github.com/prak59459-create/All-in-one-home/pull/2)）: Swift Playgrounds のアプリが llama.cpp の XCFramework を使えるか、GGUF のモデルで生成できるか | PoC 作成済。CI の結果、iPad の Swift Playgrounds では使えない見込み（下の「決めたこと」）。iPad での確認待ち | F0375, F0401, F0403 |

Phase 6 で決めたこと:

- 本体に入れる実推論は、OS に入っている Apple の端末内モデルだけにした（モデルファイルを持ち込まない・外部パッケージを使わない）。llama.cpp は Swift Playgrounds で使えるか分からないので、別ブランチの PoC で確かめてから判断する。
- AI への指示（システムプロンプト）は固定。端末やアプリを操作できず、ネットも検索できないことを伝える。ツール（関数呼び出し）は使わない。
- 応答の上限は 512 トークン。会話が長くなりすぎたら「新しい会話」で読み込み直す。
- llama.cpp の PoC（[PR #2](https://github.com/prak59459-create/All-in-one-home/pull/2)）の結果:
  - 公式の XCFramework（動的ライブラリ）は、Xcode 16.4 / 26.3 で iPad 実機向けにコンパイル・リンクまではできた。
    ただし、.swiftpm の形のアプリには埋め込まれなかった（起動時にライブラリが見つからない見込み）。
  - 公開されている報告では、iPad の Swift Playgrounds はビルド済みのバイナリ（binaryTarget）も C / C++ のターゲットも使えない。
  - このため、MyHome には組み込まない。iPad で試してもらえれば確定する（手順は PoC の README）。

## Phase 7 — 天気（Open-Meteo。実装済み・テスト済 / ビルド済。実機での通信は未確認）

8320b4a の CI で、Xcode 16.4・26.3 のビルドと Simulator の起動テストが通った。ただし起動テストのスクリーンショットで、天気の画面が読み込み中の表示のまま止まる不具合が見つかった（WeatherController を後から @State に入れていたが、描き直されなかった）。1c8e162 で直し、その CI で、前回の天気と「通信はオフです」の表示を両方の Xcode で確かめた。

| タスクID | 内容 | 状態 | 関連機能ID |
|---|---|---|---|
| T7-1 | 通信の同意: 天気の画面で「通信をオンにする」を押すまで、検索も取得もしない（Core の WeatherController で止め、テストで確かめる）。送るもの・送らないものを表示。設定からいつでもオフにでき、保存した天気を消すかを選べる | テスト済 / ビルド済 | F0309, F0841, F0866 |
| T7-2 | 場所: 都市名で検索して登録（Open-Meteo の Geocoding API。2 文字以上）。位置情報は使わない。10 か所まで、切り替え・並べ替え・削除 | テスト済 / ビルド済 | F0281, F0283, F0302, F0303 |
| T7-3 | 予報の取得と読み取り: 今の天気・48 時間の時間別・7 日の日別。時刻は UNIX 時間で受け取り、その土地のタイムゾーンで表示。値の配列の長さが時刻と合わない応答は読まない。WMO の天気コードを日本語の名前と記号に | テスト済 | F0284–F0293, F0295–F0300, F0310, F0320 |
| T7-4 | 画面: 今の天気（天気と昼夜で背景の色を変える）、雨の見通し、時間別（降水確率の棒）、日別（週の気温の幅の棒）、詳細、出典（CC BY 4.0） | ビルド済 | F0289, F0294, F0315–F0317 |
| T7-5 | 更新と失敗: 取得した時刻、更新ボタンと引っぱって更新。30 分以内の天気があれば、開き直しても取得しない。同じ場所は 10 秒以内に続けて取得しない。失敗（オフライン・時間切れ・利用回数の上限・サーバーの不調・読めない応答）は理由を出し、前回の天気を表示し続ける | テスト済 / ビルド済 | F0304–F0308, F0319 |
| T7-6 | 単位: 気温（摂氏・華氏）、風速（m/s・km/h・mph）。保存は摂氏・km/h のままで、表示する時に換算する | テスト済 | F0311, F0312 |
| T7-7 | ホームからの起動と起動テスト: 天気の項目の「準備中」を外す。Simulator の起動テストで、通信オフ・前回の天気ありの保存ファイルを置いて開く（CI から Open-Meteo には接続しない） | テスト済 / ビルド済 | F0080, F0921 |

Phase 7 で作らなかったもの:

- 気象警報（F0301）: Open-Meteo の予報の API に警報がないため。
- 現在地（F0282）: 位置情報の許可が必要になり、Package.swift の変更も要るため。今回は都市名の検索だけにした。
- ホーム画面の天気のウィジェット（F0313、F0314）: ホーム画面の保存形式（ウィジェットの種類）を増やす必要があるため、後の Phase で。
- 天気の通知（F0318）: アプリを閉じている間は天気を取得できないため（iPadOS の制限）。

Phase 7 で決めたこと:

- 天気のデータは Apps/weather.json（Phase 5 のミニアプリと同じ仕組み）。ホーム画面の起動時には読まない。
- 保存する値は Open-Meteo の単位（摂氏・km/h・mm）のまま。単位を変えても取得し直さない。時間別の予報は 48 時間分だけ保存する。
- 雨の見通しは、この先 12 時間で降水確率 50% 以上、または 0.5mm 以上の最初の時間。予報そのものではなく目安として表示する。
- Open-Meteo の利用条件（無料・非商用、CC BY 4.0）に従い、天気を表示する画面に出典のリンクを置く。外部のページは確認してから開く。

## Phase 8 — 動き・文字の大きさ・キーボード・ヘルプ（実装済み・テスト済 / ビルド済。実機での操作は未確認）

1c8e162 の CI で、Xcode 16.4・26.3 のビルドと起動テスト（21 通り）が通った。スクリーンショットで見つけた 2 つを 461f3c6 で直した:
文字がいちばん大きい時に、アイコンの名前が「フ…」の 1 文字、ウィジェットの文字も 1〜2 文字しか見えなかった（幅の決まった部分は xxxLarge で止めた。iPad のホーム画面と同じ）。dark のケースは、使った保存ファイルが外観を「ライト」に固定していたため明るいままだった（アプリの不具合ではない。「端末に合わせる」の保存ファイルに変えた）。

| タスクID | 内容 | 状態 | 関連機能ID |
|---|---|---|---|
| T8-1 | 動きの設定: 端末の設定に合わせる・減らす（フェードだけ）・オフ。「端末の設定に合わせる」では iPad の「視差効果を減らす」に従う。アニメーションは MotionStyle の1か所から取り、画面ごとに判断しない | テスト済（判断・保存）/ ビルド済 | F0671, F0672, F0674, F0677, F0981 |
| T8-2 | アニメーション: フォルダの開閉、編集モードの切り替え（バーの出入り）、ページの移動、アイコンを押した時。どれも動きの設定に従う | ビルド済 | F0658, F0660–F0663 |
| T8-3 | 文字の大きさ: このアプリの中だけの文字の大きさ（端末の設定に合わせる・小さい〜最大）。設定を変えても画面を作り直さない（開いている設定のシートが閉じないように） | テスト済（保存）/ ビルド済 | F0977, F0978 |
| T8-4 | キーボード: ⌘, 設定、⌘E 編集、⌘← ⌘→ ページの移動。シートやフォルダが開いている時は、後ろのホーム画面を動かさない | ビルド済 | F0983 |
| T8-5 | 使い方と困った時（設定から）: 基本の操作・ミニアプリと機能・困った時・キーボード。見出しと手順の文で探せる | テスト済 / ビルド済 | F0963–F0967, F0970–F0972, F0998, F0999 |
| T8-6 | 起動テスト: 端末の文字を最大（アクセシビリティ XXXL）にした時のホーム画面と天気、ダークモードのホーム画面をスクリーンショットで確かめる | ビルド済（dark は 461f3c6 の直しを次の CI で確認） | F0977, F0985–F0987 |
| T8-7 | 画面の幅と向き: 列の数は画面（ウィンドウ）の幅で決める。Split View・Stage Manager の幅にも追従する。幅ごとの計算は Phase 1 からテスト済 | テスト済（計算）/ 実機未確認 | F0985–F0987, F1001 |

Phase 8 で作らなかったもの・分かったこと:

- 触覚フィードバック（F0675、F0676）: iPad には触覚の仕組みがない（Apple Pencil Pro を除く）ため作らない。
- タップ領域（F0982）: ページの点（当たり判定 28pt）と、項目・ウィジェットの − ボタン（30〜32pt）は、推奨の 44pt より小さい。
  代わりの操作として、ページは VoiceOver の調整操作とスワイプ、削除は長押しメニューの「削除」がある。
  大きくすると配置がずれるので、実機で使ってから決める。
- 画面の回転の自動テスト: Simulator をコマンドから回転させる方法がないため、起動テストは縦向き（iPad (10th generation)）だけ。
- 初回起動の案内（F0961）: ホーム画面に重なって邪魔になるので作らず、設定の「使い方と困った時」にまとめた。

## Phase 9 — バックアップ・復元・移行・ライセンスと権限（実装済み・テスト済 / ビルド済。実機での操作は未確認）

645d378 の CI で、Xcode 16.4・26.3 のビルドと起動テスト（23 通り）が通った。スクリーンショットで、バックアップと復元の画面（この iPad のバックアップ 2 つの一覧）、このアプリについて、端末に合わせたダークモードのホーム画面を確かめた。

| タスクID | 内容 | 状態 | 関連機能ID |
|---|---|---|---|
| T9-1 | 移行（アップデート相当）: Phase 2〜7 の各コミットのコードで作った保存ファイル（ホーム画面の形式の版 1・2・3、Phase 7 の設定、ミニアプリと天気の版 1）を、今の起動時の読み込みで読めることを確かめる。新規起動（保存先が空）も | テスト済（9 件。作り方は `scripts/fixtures/migration/README.md`） | F0823 |
| T9-2 | バックアップの形式: 1 つの JSON（format・formatVersion・createdAt・appVersion・files）。files はアプリの保存先と同じパス・同じ中身（Base64）。全体で 100MB まで | テスト済 | F0812, F0817, F0818 |
| T9-3 | 書き出しと読み込み: 「ファイルに書き出す」（ファイルアプリ・iCloud Drive などに保存）と「ファイルから復元」（選んだファイルを NSFileCoordinator で読む） | ビルド済 | F0813–F0815 |
| T9-4 | 検証とプレビュー: 種類・形式の版・パスの重複を確かめ、ホーム画面とミニアプリのデータは起動時と同じ規則で検証。1 つでも読めなければ何も変えない。危ないパス・知らないファイルは書かない。欠けている画像を数える。作成日時・版・大きさ・ページ・項目・ウィジェット・テーマ・画像の数を見せる | テスト済 / ビルド済 | F0819, F0821, F0822, F0824, F0827, F0861 |
| T9-5 | 復元: 戻すもの（ホーム画面と設定・ミニアプリごと）を選び、確認してから復元。今のデータを自動で「この iPad のバックアップ（復元の前）」に残し、ファイルを書き換え（途中で失敗したら元に戻す）、保存先から読み直す（アプリの再起動はいらない）。天気の通信の同意は今の端末のまま、動いていたタイマーは止めて戻す。入れ替える前のストアは保存をやめる（古い内容で上書きしない） | テスト済 / ビルド済 | F0820, F0828–F0830, F0835 |
| T9-6 | この iPad のバックアップ: 一覧（新しい順・種類・日時・大きさ）、中身を確かめて復元・書き出し・削除・すべて削除。自動のものは新しい 5 個、手動は 10 個まで | テスト済 / ビルド済 | F0831, F0832 |
| T9-7 | すべてのデータを消す: 消す前のデータを自動で残してから、ホーム画面・ミニアプリのデータ・画像・読めずに退避したファイルを消して、初めて起動した時の状態に戻す（この iPad のバックアップとアップデートの記録は残す） | テスト済 / ビルド済 | F0839, F0868 |
| T9-8 | このアプリについて（ライセンス・権限の確認）: OS の許可（1 つも求めない）・通信する相手（実際の URL から作り、テストで照合）・保存先・出典とライセンス（Open-Meteo と GeoNames は CC BY 4.0、外部のライブラリなし） | テスト済（内容）/ ビルド済 | F0742–F0746, F0756, F0840–F0849, F0865–F0867, F0870 |
| T9-9 | 起動テスト: この iPad のバックアップを 2 つ置き、設定の「バックアップと復元」と「このアプリについて」を開く（起動引数 `-MyHomeSettingsPage`）。開いてもバックアップが消えないかも確かめる | ビルド済 | F0921 |

Phase 9 で作らなかったもの:

- バックアップの暗号化・パスワード: 忘れた時に戻せなくなるため、鍵の扱いを決めてから。書き出す画面に「暗号化していない」ことを表示している。
- iCloud での自動の同期・定期的な自動バックアップ: Swift Playgrounds の .swiftpm では iCloud の設定（entitlements）を扱えず、アプリを開いていない間は動けないため。
  ファイルアプリで iCloud Drive に書き出すことはできる。
- バックアップの名前の設定（F0816）と検索（F0833）: 一覧は 15 個までなので、日時と種類で見分ける。
- ファイルを選んで復元する操作の自動テスト: Simulator では選ぶ操作ができない（UI テストの仕組みがない）。復元そのものは Linux の単体テストで確かめた。
- リポジトリのライセンスのファイル（LICENSE）: 決めるのはリポジトリの持ち主なので追加していない。

Phase 9 で決めたこと:

- 復元は「確かめてから、保存先にファイルを書き戻して、起動時と同じ読み込みで読み直す」。移行・検証・壊れたファイルの扱いが起動時と同じになる。
- 復元・消去の前に今のデータを端末内に残せなければ、何も変えない。
- 部分復元で選ばなかったもの、バックアップに入っていないミニアプリのデータは今のまま（消さない）。
- 天気の通信の同意はバックアップから戻さない（Phase 7 の「オンにするまで通信しない」を守る）。
- データの状態一式は AppSession が持ち、復元・消去の後は読み直したストアに入れ替える。開いている設定の画面もそのまま新しい状態を表示する。

## ソフトウェアアップデート（ユーザーの依頼で追加。実装済み・テスト済 / ビルド済。実機での操作は未確認）

ecc196f の CI で、iOS 18 SDK（Xcode 16.4）・iOS 26 SDK（Xcode 26.3）のビルドと Simulator の起動テストが通った。

| 内容 | 状態 | 場所 |
|---|---|---|
| GitHub のブランチ一覧、コミットのファイル一覧、CI の結果の取得 | テスト済（固定の応答） | `Core/Update/GitHubUpdateClient.swift`, `CommitCheckStatus.swift` |
| 手元との比較（git のブロブのハッシュ。SHA-1 は自前で実装し、git の値で検証） | テスト済 | `Core/Update/SHA1.swift`, `UpdatePlanner.swift` |
| 書き込み先の確認（.swiftpm、Package.swift、識別ファイル。コピーは断る） | テスト済（確認の部分）/ ビルド済（フォルダの選択） | `Core/Update/PackageVerifier.swift`, `Features/Update/PackageAccess.swift` |
| 全部取得してハッシュを確かめてから、退避して書き込む。途中で失敗したら戻す。元に戻す | テスト済（1〜4 回目の書き込みで失敗させても元のまま、元に戻すと完全に元通り） | `Core/Update/UpdateInstaller.swift` |
| iCloud Drive / Swift Playgrounds と同時に使っても壊さない書き込み（NSFileCoordinator） | ビルド済 | `Features/Update/CoordinatedPackageFileSystem.swift` |
| 書き込んだコミットでビルドされたかの表示（BuildStamp） | テスト済 | `Core/BuildStamp.swift`, `Core/Update/UpdateState.swift` |

制限: アプリ自身はビルドし直せない（書き込んだ後は Swift Playgrounds で実行し直す）。iPad の実機では未確認（フォルダの選択、iCloud Drive への書き込み、Swift Playgrounds が開いている時の書き込み）。

## 追加フェーズ A — 全画面のアプリ・ウィジェット型のホーム画面・起動と初期設定・Core ML の Qwen（ユーザーの依頼で追加。計画中）

2026-10-30 のユーザーの依頼:「アプリは全画面表示にするのと画面は基本アプリアイコンはおかずウィジェット型にして。AIはCoreMlを使いモデルはqwenの0.5Bモデルを標準搭載してビルドは早くしてね
あとiPad風の起動シークエンスや初期設定も作って（フェーズに入ってなければ作って入ってればその時作って）」。どれもまだどの Phase にも入っていなかったので、Phase 9 の次に作る。

| タスクID | 内容 | 状態 |
|---|---|---|
| TA-1 | アプリ（機能）を全画面で開く（シートではなく）。閉じるボタンとキーボードの ⌘W。項目の追加・編集・ページの管理はシートのまま | 実装済み・テスト済（どれを全画面にするか）/ ビルド確認中 |
| TA-2 | iPad 風の起動シークエンス（MyHome のロゴと進み具合。Apple のロゴは使わない。短く、タップで飛ばせ、動きを減らす設定に従う）と、初回の初期設定（こんにちは → 外観・テーマ → 文字と動き → ホーム画面 → 天気の同意 → AI → 完了） | 計画中 |
| TA-3 | ウィジェット型のホーム画面: アプリのアイコンは基本置かず、天気・メモ・タスク・カレンダー・時計・タイマー・AI などのウィジェットを並べる。タップで全画面のアプリを開く。今の配置は失わないよう、保存形式を移行する | 計画中 |
| TA-4 | Core ML で Qwen2.5-0.5B-Instruct（Apache 2.0）を標準搭載: まず試作で、変換（4bit・状態付きの KV キャッシュ・100MB 未満に分割）、CI の Mac での予測、Swift のトークナイザー、Swift Playgrounds でのリソースの扱い、ビルド時間とアプリの大きさ、ソフトウェアアップデート（1 ファイル 2MB まで）との関係を確かめてから組み込む | 試作中（下の表） |

TA-4 の試作の状況:

| 内容 | 状態 | 場所 |
|---|---|---|
| PyTorch で書き直した Qwen2（Core ML に変換しやすい形）が transformers と同じ答えになる | 確認済（logits の差は最大 0.00003、貪欲な生成が一致） | `scripts/coreml/qwen_model.py`、`convert_qwen.py verify` |
| Core ML への変換（iOS 18 以降。KV キャッシュは状態、重みは 4bit・32 個ずつの尺度） | 変換できた（Linux）。埋め込み 76.6MB・層 8 個ずつ 67.5MB × 3・出力 76.9MB、合計 約 356MB。どれも 100MB 未満 | `convert_qwen.py convert` |
| Core ML での予測が正しいか（4bit のずれ、float16 で溢れないか） | CI の Mac で確認中 | `scripts/coreml/check_coreml.py`、`.github/workflows/coreml-qwen.yml` |
| Swift のトークナイザー（バイト単位の BPE） | テスト済（Hugging Face と 20 種類の文・会話の形が一致） | `Core/AI/Qwen/QwenTokenizer.swift`・`QwenPrompt.swift` |
| 次のトークンの選び方（Qwen の既定値: 温度 0.7・上位 20・累積 0.8・繰り返し 1.1） | テスト済 | `Core/AI/Qwen/QwenSampler.swift` |
| Swift のエンジン（5 つのモデルを順に通す、MLState、会話の履歴） | CI の Mac で確認中（Swift のテストで実際に答えさせる） | `Core/AI/Qwen/QwenCoreML.swift`（iOS 18 SDK 以降だけビルド） |
| モデルの置き場所と取得 | 決めた: ビルドを速く保つため `.swiftpm` には入れず、リポジトリの `models/` に置き、AI の画面（と初期設定）から 1 回だけ取得して端末でコンパイルする。ソフトウェアアップデート（1 ファイル 2MB まで）の対象外 | 作成中 |


## Phase 10 — MyHome 総合機能・アプリ構成（300 項目。計画中・分類済み）

原本: [docs/phase10-catalog.md](docs/phase10-catalog.md)（2026-10-29 にユーザーから追加）。300 個を全部独立アプリにはせず、
**独立アプリ・設定・コントロールセンター・ブラウザ・各センター（AI / ツール / ネットワーク / セキュリティ / ファイル管理 / 開発者ツール / 学習 / デザイン・制作 / ゲーム / 健康 / 通知 / 自動化）**に統合する。
Phase 4〜9 で作る機能（天気・電卓・メモ・タイマー・AI・バックアップなど）と重なる項目は、先にその Phase で作り、Phase 10 で各センターへ組み込む。

### 実現性の分類

iPad の Swift Playgrounds で作る一般のアプリとしての分類。**OS制限**の項目は、システムの操作はせず、状態表示・iPadOS の設定への案内・MyHome の中だけで完結する設定として作る（原本の「重要な実装上の注意」のとおり）。

| 記号 | 意味 |
|---|---|
| A | 標準のフレームワークで作れる。権限は不要（例: SwiftUI、WebKit、PDFKit、CryptoKit、Vision、Core Image、SpriteKit、Swift Charts） |
| P | 利用者の許可が必要（カメラ、マイク、音声認識、連絡先、カレンダー・リマインダー、通知、位置情報、写真の保存、Bluetooth）。許可がない時の代替表示を作る |
| N | 通信が必要。設定でオンにするまで通信しない。送る内容を画面に示す |
| X | 外部のサービス（サーバー、API キー）が必要。MyHome だけでは提供できないので、受け渡し・下書き・自分の端末内だけの機能にとどめる |
| Q | Swift Playgrounds で使えるか未確認（要PoC。小さな試作で確かめてから判断する） |
| L | OS制限。状態表示・案内・MyHome 内の設定のみ |

| 区分（No.） | A | P | N | X | Q | L |
|---|---|---|---|---|---|---|
| 1. 基本アプリ・インターネット（1〜30） | 1–7, 12, 16, 19, 20, 22, 29, 30 | 11（現在地）, 15, 23（カメラ） | 8, 9, 10, 26, 27, 28 | 14（受信）, 21, 24（外部 IP） | 13, 17, 18 | 25（DNS は名前解決のみ） |
| 2. 設定・システム管理（31〜60） | 31–37, 39–46, 48–60 | — | — | — | 38（アプリ自体のアイコン）, 47 | 37（iPadOS の壁紙）, 44（端末の音量は標準の部品のみ） |
| 3. コントロールセンター（61〜80） | 61, 64–67, 71, 72, 76–80 | 63 | — | — | — | 62（接続の種類のみ。SSID 不可）, 68–70, 73–75 |
| 4. 日常生活・便利機能（81〜110） | 81–83, 85, 86, 88–90, 92–106, 108–110 | 87（通知）, 91（標準のリマインダー連携） | 84 | 107（相手との共有はファイル渡し） | — | — |
| 5. ファイル・文章管理（111〜140） | 111, 112, 114–118, 121–123, 125, 126, 130–138, 140 | 127, 128 | — | — | 113, 119, 120, 124, 139 | 129（他アプリのコピーを裏で記録できない） |
| 6. AIセンター（141〜170） | 150, 162, 163, 170 | 149, 151, 167 | 142 | 161（外部 AI の API キー） | 141, 143–148, 152–160, 164–166, 168, 169 | — |
| 7. 学習・教育（171〜190） | 171–173, 175–185, 187–190 | 174（発音の認識） | — | — | 186 | — |
| 8. 写真・動画・デザイン（191〜210） | 191–199, 201–209 | 191（ライブラリ全体）, 210（写真への保存） | — | — | 200 | 210（iPadOS の壁紙は設定できない） |
| 9. ゲーム・娯楽（211〜230） | 211–220, 222–226, 228–230 | — | — | — | 221（Game Center）, 227 | — |
| 10. 開発者・プログラミング（231〜250） | 231–234, 236, 237, 239, 240, 243, 245–250 | — | 238 | — | 241, 242, 244 | 235（Python は他アプリへの受け渡しのみ） |
| 11. 通信・連絡（251〜265） | 253, 255, 256, 258, 261–265 | 254, 259 | — | 251, 252, 257（回答の収集）, 260（日程調整） | — | — |
| 12. 健康・生活習慣（266〜280） | 266–268, 270–278, 280 | 272（GPS） | — | — | 279 | 269（多くの iPad に歩数計がない） |
| 13. クリエイティブ・制作（281〜290） | 281, 283–288, 290 | — | — | — | 282, 289 | — |
| 14. 高度な管理・拡張（291〜300） | 291–293, 295, 296, 299, 300 | — | — | 294（端末間の同期） | — | 291・292（OS の出来事での自動実行は不可）, 297・298（任意のコードを読み込む拡張は作らない。内蔵機能の有効 / 無効と一覧のみ） |

1つの項目が複数の列にある時は、できる部分（A）と制限のある部分を分けて作る（例: 23 は画像からの読み取りが A、カメラが P）。

### 進め方（案）

| タスクID | 内容 | 主な No. |
|---|---|---|
| T10-1 | センターの骨組み: 独立アプリとセンターの一覧、配置先ごとの入口、各機能の状態（実装済み・権限が必要・OS制限など）を「機能の状況」と同じ規則で表示 | 49–51, 300 |
| T10-2 | ツール・セキュリティセンター（権限不要の小さな道具） | 22, 101–105, 125, 134, 135, 237, 239 |
| T10-3 | コントロールセンター（状態表示と案内を含む） | 61–80 |
| T10-4 | ブラウザ（WebKit） | 1–7, 18–20, 27–30 |
| T10-5 | 日常の独立アプリ（Phase 5 のミニアプリを拡張） | 81–110 |
| T10-6 | ファイル管理（PDF、テキスト、暗号化・ハッシュ） | 111–140 |
| T10-7 | 開発者ツール | 231–250 |
| T10-8 | 学習センター | 171–190 |
| T10-9 | 写真・デザイン・制作センター | 191–210, 281–290 |
| T10-10 | ゲームセンター | 211–230 |
| T10-11 | 健康センター | 266–280 |
| T10-12 | AIセンター（Phase 6 の LLM 境界の上に作る。使えない端末ではスタブと明示） | 141–170 |
| T10-13 | 通信・通知センター（端末内で完結する部分） | 251–265 |
| T10-14 | 自動化・管理（MyHome の中だけで動く自動化） | 291–299 |

## 報告ログ

計画書「10. Claude Codeの作業フォーマット」に従う。

### Phase 0（2026-10-29）

```text
タスクID: T0-1〜T0-8
変更ファイル: .gitignore, Package.swift, MyHome.swiftpm/Package.swift, MyHome.swiftpm/App/MyHomeApp.swift,
  MyHome.swiftpm/Core/AppInfo.swift, Tests/MyHomeCoreTests/AppInfoTests.swift, scripts/*.sh,
  .github/workflows/ci.yml, PLAN.md, TASKS.md, README.md, docs/BUILD.md, docs/BUILD_TIMES.md, docs/feature-catalog.md
実装した機能: 最小アプリ（タイトル表示のみ）、Linux 検証パッケージ、計測スクリプト、CI
ビルド結果: Linux（Core）PASS / macOS（アプリ全体、Xcode 16.4・26.3）PASS / iPad NOT RUN
テスト結果: 1件 PASS（Swift 5.10.1 / 6.0.3 / 6.4.1）、Simulator 起動 PASS
初回/増分ビルド時間: docs/BUILD_TIMES.md（macOS: クリーン 25.0 / 31.6 秒、View 1ファイル変更 2.0 / 3.0 秒）
既知の制限: iPad 実機・Swift Playgrounds での確認ができない環境
次に行う最小タスク: T1-1（Core モデル）
```

途中で見つけて直した問題:

- `Package.swift` のプレースホルダーアイコン `.layers` は存在しない名前だった（xcodebuild のマニフェスト解決で失敗）→ `.clock` に変更。
- 計測スクリプトで、全角文字の直前の `$変数` を macOS の bash が変数名の一部と解釈して失敗し、さらに EXIT トラップのせいで失敗が成功扱いになっていた → `${変数}` と終了コードの保持で修正。

### Phase 1（2026-10-29）

```text
タスクID: T1-1〜T1-8
変更ファイル: MyHome.swiftpm/Core/**（モデル・ロジック・ストア・LLM 境界）、MyHome.swiftpm/DesignSystem/**、
  MyHome.swiftpm/Features/**（Home / Dock / Launch / Settings / Status / AIChat）、MyHome.swiftpm/App/MyHomeApp.swift、
  Tests/MyHomeCoreTests/**、scripts/measure-app-build.sh、scripts/smoke-test-simulator.sh
実装した機能: 時計、アイコングリッド（幅に応じた列数）、横スワイプのページとページインジケーター、Dock、
  確認付きの外部リンク起動、準備中・スタブの明示、テーマ 4 種とライト / ダーク、機能の状況、AI 画面（スタブのみ）
ビルド結果: Linux（Core）PASS / macOS（Xcode 16.4・26.3）PASS / iPad NOT RUN
テスト結果: 61件 PASS（Swift 5.10.1 / 6.0.3 / 6.4.1）、Simulator 起動 PASS（初期レイアウト・0件・1ページ150件）
初回/増分ビルド時間: docs/BUILD_TIMES.md（macOS の3回中央値: View 1ファイル変更 3.03 / 3.17 秒、変更なし 3.15 / 2.17 秒）
既知の制限: タップ・スワイプ・VoiceOver の操作は未確認。設定は保存されない（Phase 2）。iOS 17 SDK でのコンパイルは未確認
次に行う最小タスク: iPad での確認結果を受けて Phase 2（JSON 永続化）の T2-1
```

途中で見つけて直した問題:

- Swift 5.10.1 で `RGBAColor.init(hex:)` の型チェックに 60〜88ms かかっていた → 式を分割して 13ms 未満に。
- `unload()` が生成タスクの終了を待たずに戻り、「画面を離れたら推論が止まる」ことを保証できていなかった → 停止を待ってから戻るよう修正し、テストを追加。
- Swift 5.10.1 の旧 Foundation では `data:text/html,<b>x</b>` が URL として解析できず、理由が「形式エラー」になっていた → 危険なスキームと空白・制御文字を解析の前に判定し、環境によらず同じ結果に。
- Linux 版 XCTest（Swift 5.10.1 / 6.0.3）は同期の `@MainActor` テストをコンパイルできない → テストを async に。
- Simulator のスクリーンショット（iPad 10th generation、縦、ライト）で、グリッド最上段のアイコンの印（準備中・外部リンク）が上端で切れていた。iPad の実機でも同じ症状の報告があった → 印のはみ出し分（6pt と縁取り 1pt）を IconTile 自身の枠に含めるよう変更。入れ物（スクロール領域、今後のフォルダや一覧）の側で余白を足さなくても切れない。

スクリーンショットで確認できたこと（Xcode 26.3 の CI、操作はしていない）:

- 初期レイアウト: 時計と日付、6 列のアイコン、印（準備中・外部リンク・スタブ）、ページの点 2 つ、Dock 4 項目が表示される。
- 項目 0 件: 「このページには項目がありません」の説明が表示される。
- 1 ページ 150 件: 6 列で並び、Dock の手前で縦スクロール領域が切れる（スクロール自体は未確認）。ページが 1 枚なのでページの点は表示されない。
- Simulator の言語が英語のため、時刻は「2:40 PM」形式。日本語の端末では端末の設定に従う。

### Phase 2（2026-10-29）

```text
タスクID: T2-1〜T2-7
変更ファイル: MyHome.swiftpm/Core/Persistence/**（保存形式・検証・読み書き・保存の予約）、
  Core/Logic/HomeLayout+Editing.swift・LayoutValidator.swift・LayoutLimits.swift・LinkDraft.swift、
  Core/Models/RGBAColor+Hex.swift・IconChoices.swift・DefaultLayout.swift、Core/Store/*、Core/Navigation/AppRouter.swift、
  MyHome.swiftpm/Features/Edit/**（編集バー・削除ボタン・長押しメニュー・並べ替え・追加シート・保存状態）、
  Features/Home/*、Features/Dock/DockView.swift、Features/Launch/*、Features/Settings/SettingsView.swift、App/MyHomeApp.swift、
  Tests/MyHomeCoreTests/**（保存形式・破損データ・編集・ファイル・保存の予約）、scripts/smoke-test-simulator.sh、scripts/fixtures/home-restore.json
実装した機能: 長押しメニューからの編集モード、項目の追加（Web リンク・URL スキーム・アプリ内の機能）と削除（確認付き）、
  同じページ・Dock の中での並べ替え（ドラッグ / VoiceOver の操作）、配置と設定の自動保存と再起動後の復元、
  壊れた保存ファイルの退避と説明、保存失敗の通知と再試行、設定画面の保存状態
ビルド結果: Linux（Core）PASS / macOS（Xcode 16.4・26.3）PASS（adac863 の CI）/ iPad NOT RUN
テスト結果: 131件 PASS（Swift 5.10.1 / 6.0.3 / 6.4.1）、Simulator 起動 PASS（初期・0件・150件・復元・破損の5通り。
  保存ファイルからの復元と、壊れたファイルの退避と説明の表示をスクリーンショットで確認）
初回/増分ビルド時間: docs/BUILD_TIMES.md（macOS の3回中央値: View 1ファイル変更 2.37 / 4.93 秒、変更なし 1.41 / 3.12 秒。
  Linux 5.10.1: クリーン 5.36 秒、HomeItem.swift 変更の増分 1.15 秒）
既知の制限: 長押し・ドラッグ・追加シートの操作は実機で未確認。ページをまたぐ移動・Dock とページの間の移動・取り消しは Phase 3。
  起動時の読み込みはメインスレッドで同期的に行う（1MB 未満を想定）
次に行う最小タスク: T3-1（ページの追加・削除）
```

途中で見つけて直した問題:

- 検証用レイアウトで 2,000 件を指定すると、Dock の 4 件を合わせて保存できる上限（2,000 件）を超えていた（保存の往復テストで発見）→ 検証用レイアウトの上限を Dock と合わせて 2,000 件にした。
- Simulator 起動テストの「動いているか」の判定で、`launchctl list | grep -q` が SIGPIPE で失敗扱いになり、動いているアプリを「終了した」と誤判定していた（Xcode 16.4 の CI で発生。スクリーンショットで動作中を確認）→ 一覧を変数に取ってから探すように修正。

### Phase 3（2026-10-29）

```text
タスクID: T3-1〜T3-6
変更ファイル: MyHome.swiftpm/Core/Models/HomeItem.swift・HomeLayout.swift（フォルダ）、
  Core/Logic/HomeLayout+Editing.swift・+Moving.swift・+Folders.swift・+Pages.swift、LayoutValidator.swift、LaunchOptions.swift、
  Core/Store/HomeStore.swift（取り消し・やり直し）、Core/Navigation/AppRouter.swift、Core/Persistence/*（形式の版 2）、
  DesignSystem/FolderTile.swift、Features/Folder/FolderOverlayView.swift、Features/Edit/ItemEditorView.swift・ItemMoveSection.swift・
  PageManagerView.swift・EditModeBar.swift・DropMover.swift、Features/Home/*、Features/Dock/DockView.swift、
  Tests/MyHomeCoreTests/FolderAndPageTests.swift・UndoTests.swift ほか、scripts/smoke-test-simulator.sh、scripts/fixtures/home-folder.json
実装した機能: ページの管理、ページ・Dock・フォルダをまたぐ移動（ドラッグと移動先の選択）、フォルダ（作成・出し入れ・解除・1段まで）、
  名前・記号・色の変更、取り消し・やり直し、保存形式の版 2 と版 1 からの移行
ビルド結果: Linux（Core）PASS / macOS（Xcode 16.4・26.3）PASS（f574871 の CI）/ iPad NOT RUN
テスト結果: 155件 PASS（Swift 5.10.1 / 6.0.3 / 6.4.1）、Simulator 起動 PASS（編集モードとフォルダを開いた状態をスクリーンショットで確認）
既知の制限: ドラッグでのページ間移動（ページの点に重ねる）は実機で未確認。フォルダの中からのドラッグでの取り出しはできない（編集シートを使う）。
  取り消しの履歴は保存しない
次に行う最小タスク: T4-1（壁紙の選択）
```

### ソフトウェアアップデート（2026-10-29、ユーザーの依頼で追加）

```text
変更ファイル: MyHome.swiftpm/Core/Update/**、Core/PackageIdentity.swift、Core/BuildStamp.swift、MyHome.swiftpm/Features/Update/**、
  Features/Settings/SettingsView.swift、Tests/MyHomeCoreTests/SoftwareUpdateTests.swift・UpdateTestSupport.swift、docs/BUILD.md
実装した機能: 設定 → ソフトウェアアップデート。GitHub のブランチを選び、手元の MyHome.swiftpm と比べて変わったファイルだけを書き込む。
  書き込み先の確認、取得したファイルのハッシュの照合、退避と失敗時の巻き戻し、最後の更新の前に戻す、CI が通っていないコミットの確認
ビルド結果: Linux（Core）PASS / macOS（Xcode 16.4・26.3）PASS（ecc196f の CI）/ iPad NOT RUN
テスト結果: 177件 PASS（Swift 5.10.1 / 6.0.3 / 6.4.1）、Simulator 起動 PASS
既知の制限: アプリ自身はビルドし直せない（書き込んだ後は Swift Playgrounds で開き直して実行する）。フォルダの選択・iCloud Drive への書き込みは実機で未確認。
  この機能が入っていない版からは、最初の1回だけ手動で入れ替える必要がある
```

### Phase 4（2026-10-29）

```text
タスクID: T4-1〜T4-6
変更ファイル: MyHome.swiftpm/Core/Models/HomeWidget.swift・WallpaperSetting.swift・TimerModels.swift・HomeItem.swift・HomeLayout.swift、
  Core/Logic/HomeLayout+Widgets.swift・MonthGrid.swift・TimerValidator.swift・LayoutValidator.swift、Core/Store/TimerStore.swift・SettingsStore.swift・HomeStore.swift、
  Core/Persistence/*（形式の版 3、ImageFileStore.swift）、Core/Navigation/AppRouter.swift、
  DesignSystem/IconTile.swift・FolderTile.swift・WallpaperView.swift・ThemeBridge.swift・DesignTokens.swift、
  Features/Widgets/**、Features/Timer/**、Features/Media/ImageSupport.swift、Features/Settings/WallpaperSettingsSection.swift、
  Features/Edit/ItemImageSection.swift・ItemEditorView.swift・AddItemView.swift、Features/Home/*、Features/Launch/*、App/MyHomeApp.swift、
  Tests/MyHomeCoreTests/WidgetAndWallpaperTests.swift・TimerTests.swift・ImageFileStoreTests.swift ほか、scripts/fixtures/home-folder.json
実装した機能: 写真の壁紙（ぼかし・暗さ）、アイコンの画像、アプリ内ウィジェット（デジタル / アナログ時計、今月のカレンダー、メモ、タイマー）、
  タイマー（複数のカウントダウンとストップウォッチ）、ホーム画面の時計の秒の表示、保存形式の版 3
ビルド結果: Linux（Core）PASS / macOS（Xcode 16.4・26.3）PASS（f0e59d2 の CI）/ iPad NOT RUN
テスト結果: 202件 PASS（Swift 5.10.1 / 6.0.3 / 6.4.1）、Simulator 起動 PASS（編集モードのスクリーンショットで、アナログ時計・カレンダー・メモ・タイマーのウィジェットを確認）
初回/増分ビルド時間: docs/BUILD_TIMES.md（macOS の3回中央値: View 1ファイル変更 4.55 / 3.67 秒、変更なし 2.58 / 1.86 秒。
  Linux 5.10.1 クリーン 7.73 秒、HomeItem.swift 変更の増分 2.24 秒。アプリ本体の Swift 8,615 行、123 ファイル: Core 68 / UI 55）
遅い型チェック: Linux（50ms 超）0 件。Xcode 16.4（100ms 超）で TimerAppView のストップウォッチの body が 122ms → Phase 5 で分割して修正
既知の制限: アプリを閉じている間はタイマーの音が鳴らない（iPadOS の制限。戻った時に知らせる）。iPadOS のホーム画面のウィジェットと壁紙は変えられない。
  写真の選択・ウィジェットの操作は実機で未確認。ウィジェットの「大」（F0168）はない
次に行う最小タスク: T5-1（メモのミニアプリ）
```

### Phase 5（2026-10-30）

```text
タスクID: T5-1〜T5-7
変更ファイル: MyHome.swiftpm/Core/MiniApps/**（保存の土台、メモ、タスク、電卓、単位変換、テキストツール）、
  Core/Persistence/HomeArchiveStorage.swift（ファイル名の元を指定できるように）・DecodingErrorText.swift・AppBootstrap.swift・HomeArchiveCodec.swift、
  Core/Models/AppFeature.swift・DefaultLayout.swift・FeatureStatusCatalog.swift、Core/Logic/LaunchOptions.swift、
  MyHome.swiftpm/Features/MiniApps/**、Features/Launch/FeatureSheetView.swift、Features/Update/UpdatePlanViews.swift、App/MyHomeApp.swift、
  Features/Timer/TimerAppView.swift（Xcode 16.4 で遅かった型チェックの修正）、Features/Widgets/WidgetRow.swift（− ボタンを角に寄せた）、
  Tests/MyHomeCoreTests/MiniAppStorageTests.swift・NotesAndTasksTests.swift・CalculatorTests.swift・ConverterAndTextToolsTests.swift・LaunchTests.swift、
  scripts/smoke-test-simulator.sh、scripts/fixtures/apps/*.json
実装した機能: ミニアプリ5つ（メモ・タスク・電卓・単位変換・テキストツール）と、1アプリ1ファイルの保存（開いた時だけ読む、読めないファイルは退避）。
  ホーム画面の初期配置と「項目を追加」から起動。天気は Phase 7 まで「準備中」の項目
ビルド結果: Linux（Core）PASS（Swift 5.10.1 strict concurrency / 6.0.3・6.4.1 の Swift 6 言語モード）/ macOS（Xcode 16.4・26.3）PASS（48db4f1 の CI）/ iPad NOT RUN
テスト結果: 245件 PASS（Swift 5.10.1 / 6.0.3 / 6.4.1）、Simulator 起動 PASS（12 通り。ミニアプリ5つを保存ファイル付きで開き、電卓の式と途中結果・
  タスクの区切り・メモのピン留め・単位変換の結果・テキストツールの文字数が復元・表示されることをスクリーンショットで確認）。遅い型チェック 0 件（Linux 50ms・Xcode 100ms）
初回/増分ビルド時間: docs/BUILD_TIMES.md（macOS の3回中央値: View 1ファイル変更 2.20 / 6.30 秒、変更なし 1.04 / 2.58 秒。
  Linux 5.10.1 クリーン 10.04 秒、HomeItem.swift 変更の増分 2.91 秒。アプリ本体の Swift 12,456 行、160 ファイル: Core 95 / UI 65）
  Xcode 26.3 の View 1ファイル変更が Phase 4 の 3.67 秒から延びた（原因は Phase 8 で調べる）。
  Simulator で見つけて直したこと: 今年でないタスクの期限に年が出ず「1月1日」とだけ表示されていた → 年も出す（Phase 6 の後の修正に含める）
既知の制限: ミニアプリの画面の操作（入力・スワイプ・ハードウェアキーボード）は実機で未確認。iCloud での同期・書き出し・読み込み（バックアップ）は Phase 9。
  削除したメモ・タスクは元に戻せない（ゴミ箱はない）。古い版のアプリに戻すと、新しい機能の項目を含む保存データは読めない（消さずに別名で残す）
次に行う最小タスク: T6-1（Foundation Models の利用可否の判定と、AI 画面のプロバイダの切り替え）
```

### Phase 6（2026-10-30）

```text
タスクID: T6-1〜T6-4（T6-5 の llama.cpp の PoC は別ブランチ）
変更ファイル: MyHome.swiftpm/Core/AI/LLMAvailability.swift・LLMStreamText.swift・LocalLLMProvider.swift・LLMSessionController.swift、
  Core/Models/AppFeature.swift・FeatureStatusCatalog.swift、
  MyHome.swiftpm/Features/AIChat/SystemModelSupport.swift・AIProviderOption.swift・AIChatView.swift（旧 AIStubChatView）・AIModelPanel.swift（旧 AIStatusBanner）・
  AIInputBar.swift・AIMessageRow.swift、Features/Launch/FeatureSheetView.swift、App/MyHomeApp.swift、Tests/MyHomeCoreTests/AIBackendTests.swift
実装した機能: Apple の端末内モデル（Foundation Models）での会話（使える端末だけ）、使えない理由の表示、モデルの選択・読み込み・解放・新しい会話、
  回答のコピー、端末内モデルが使えない端末だけ AI の項目に「スタブ」の印
ビルド結果: Linux（Core）PASS（Swift 5.10.1 strict concurrency / 6.0.3・6.4.1 の Swift 6 言語モード）/ macOS（Xcode 16.4・26.3）PASS（fe0eb26 の CI）/ iPad NOT RUN
  Foundation Models のコードは Xcode 16.4（iOS 18 SDK）ではビルドから外れ、Xcode 26.3（iOS 26 SDK）ではコンパイルされることを確認
テスト結果: 252件 PASS（Swift 5.10.1 / 6.0.3 / 6.4.1）、Simulator 起動 PASS（12 通り）。どちらの SDK でも、CI の Mac では端末内モデルを使えないため
  Dock の AI に「スタブ」の印が付くことをスクリーンショットで確認
初回/増分ビルド時間: docs/BUILD_TIMES.md（macOS の3回中央値: View 1ファイル変更 3.49 / 4.15 秒、変更なし 1.38 / 1.86 秒。
  アプリ本体の Swift 12,857 行、165 ファイル: Core 97 / UI 68）。Xcode 26.3 の View 1ファイル変更は Phase 5 の 6.30 秒から 4.15 秒に戻った
  （Phase 5 の値はランナーの差だった可能性が高い）。遅い型チェック 0 件
既知の制限: 端末内モデルの実際の応答は未確認（CI の Mac では Apple Intelligence を使えない）。iPadOS 26 未満・非対応機種・iOS 18 SDK の Swift Playgrounds では
  スタブだけ。会話は保存しない（閉じると消える）。応答は 512 トークンまで
次に行う最小タスク: T7-1（天気の設定と通信の同意）。T6-5（llama.cpp の PoC）は別ブランチで作成済みで、iPad での確認待ち
```

### Phase 7（2026-10-30）

```text
タスクID: T7-1〜T7-7
変更ファイル: MyHome.swiftpm/Core/Weather/**（WeatherLocation・WeatherCondition・WeatherSnapshot・WeatherData・WeatherError・
  OpenMeteoClient・OpenMeteoDecoding・WeatherFormat・WeatherInsights・WeatherController）、
  Core/Models/AppFeature.swift・FeatureStatusCatalog.swift・HomeItem+Presentation.swift、Core/Logic/LaunchPlanner.swift、
  MyHome.swiftpm/Features/Weather/**、Features/Launch/FeatureSheetView.swift、
  Features/AIChat/AIModelPanel.swift（使えないモデルの理由を、選んでいない時も表示）、
  Tests/MyHomeCoreTests/WeatherTests.swift・WeatherControllerTests.swift・WeatherTestSupport.swift・LaunchTests.swift、
  scripts/smoke-test-simulator.sh、scripts/fixtures/make-weather-fixture.py
実装した機能: Open-Meteo の天気（通信は利用者がオンにするまでしない）。都市名の検索と登録（10 か所まで）、
  今の天気・時間別（48 時間）・日別（7 日）・詳細・雨の見通し、取得した時刻と更新、失敗時は前回の天気を表示、単位の切り替え、出典の表示
ビルド結果: Linux（Core）PASS（Swift 5.10.1 strict concurrency / 6.0.3・6.4.1 の Swift 6 言語モード）/ macOS（Xcode 16.4・26.3）PASS（8320b4a の CI）/ iPad NOT RUN
  起動テストのスクリーンショットで天気の画面が読み込み中のまま止まる不具合が見つかり、1c8e162 で直した（その CI で表示を確認）
テスト結果: 279件 PASS（Swift 5.10.1）。天気の 27 件を追加（Open-Meteo の応答の読み取り、送る内容、失敗の説明、単位と表示、雨の見通し、
  保存データ、通信がオフの間は一度も通信しないこと、取得の間隔、失敗しても前の天気を残すこと）
既知の制限: 実機での通信は未確認（CI からは Open-Meteo に接続しない。起動テストは通信オフの保存ファイルで画面を確認する）。
  現在地・気象警報・天気のウィジェット・通知はない。Open-Meteo は無料・非商用の範囲で使う（1 日 1 万回まで）
次に行う最小タスク: Phase 8 の計画（アニメーション・アクセシビリティ・回転・マルチタスク・Xcode 26.3 の増分ビルドの調査）
```

### Phase 8（2026-10-30）

```text
タスクID: T8-1〜T8-7
変更ファイル: MyHome.swiftpm/Core/Models/AccessibilityPreferences.swift・HelpCatalog.swift、Core/Persistence/SavedHome.swift、Core/Store/SettingsStore.swift、
  DesignSystem/Motion.swift、App/MyHomeApp.swift、Features/Home/HomeScreen.swift・HomeKeyboardShortcuts.swift・HomeItemButton.swift、
  Features/Widgets/WidgetRow.swift、Features/Settings/SettingsView.swift・HelpView.swift、Tests/MyHomeCoreTests/AccessibilityPreferencesTests.swift、
  scripts/smoke-test-simulator.sh、型チェックの境目の 3 関数（SHA1・TimerValidator・LLMSessionController）
実装した機能: 動きの設定（端末に合わせる・減らす・オフ）とアニメーション、このアプリの中の文字の大きさ、キーボードショートカット、
  使い方と困った時（検索できるヘルプ）
ビルド結果: Linux（Core）PASS / macOS（Xcode 16.4・26.3）PASS（1c8e162 の CI）/ iPad NOT RUN
テスト結果: 285件 PASS（Swift 5.10.1 / 6.0.3 / 6.4.1）、Simulator 起動 PASS（21 通り）。文字を最大にした時に、アイコンの名前とウィジェットの文字が
  1〜2 文字しか見えなかったので xxxLarge で止めた。dark のケースは使った保存ファイルが「ライト」固定だったので直した（461f3c6。次の CI で確認）
初回/増分ビルド時間: docs/BUILD_TIMES.md（View 1ファイル変更 2.73 / 6.37 秒、変更なし 1.12 / 3.11 秒）。遅い型チェック 0 件
既知の制限: 実機での操作は未確認。画面の回転は自動テストできない。タップ領域が 44pt 未満の所がある（理由は Phase 8 の節）
次に行う最小タスク: T9-1（古い版の保存ファイルでの移行テスト）
```

### Phase 9（2026-10-30）

```text
タスクID: T9-1〜T9-9
変更ファイル: MyHome.swiftpm/Core/Backup/**（BackupArchive・BackupError・MiniAppDataCatalog・BackupBuilder・BackupReader・BackupRestorer・
  LocalBackupStore・BackupSummary・BackupController）、Core/Persistence/AppSession.swift・AppBootstrap.swift・PersistenceController.swift、
  Core/MiniApps/MiniAppDocument.swift・MiniAppLibrary.swift、Core/Models/AboutCatalog.swift・HelpCatalog.swift、Core/Navigation/SettingsPage.swift・AppRouter.swift、
  Core/Logic/LaunchOptions.swift、Core/Update/GitHubUpdateClient.swift（通信先の名前を定数に。URL は同じ）、
  App/MyHomeApp.swift・SessionRootView.swift、Features/Settings/SettingsView.swift・AboutView.swift・Backup/**、
  Tests/MyHomeCoreTests/MigrationFixtureTests.swift・BackupTests.swift・BackupRestoreTests.swift・BackupControllerTests.swift・Fixtures/Migration/**、
  Package.swift（テストの Fixtures を除外）、scripts/smoke-test-simulator.sh、scripts/fixtures/make-backup-fixture.py・migration/**
実装した機能: バックアップの書き出し（ファイルアプリ）と読み込み、中身の確認と部分復元、復元前の自動バックアップと失敗時の巻き戻し、
  この iPad のバックアップの一覧、すべてのデータの消去、このアプリについて（OS の許可・通信・保存先・出典とライセンス）、古い版の保存ファイルの移行テスト
ビルド結果: Linux（Core）PASS（Swift 5.10.1 strict concurrency / 6.0.3・6.4.1 の Swift 6 言語モード）、SwiftUI の構文チェック PASS（84 ファイル）/
  macOS（Xcode 16.4・26.3）は PR の CI で確認 / iPad NOT RUN
テスト結果: 320件 PASS（Swift 5.10.1 / 6.0.3 / 6.4.1）。35 件を追加（移行 9、形式と検証 7、復元・消去・端末内のバックアップ 11、画面の状態・このアプリについて・起動引数 8）
初回/増分ビルド時間: Linux の Core はクリーン 15.50 秒、`HomeItem.swift` 変更の増分 4.31 秒（Phase 8 は 13.76 / 3.81 秒）。遅い型チェック 0 件
既知の制限: ファイルの選択・書き出し・復元の操作は実機でも Simulator でも未確認（Simulator では選ぶ操作ができない）。バックアップは暗号化しない。
  iCloud での自動同期と定期的な自動バックアップはない
次に行う最小タスク: TA-1（アプリを全画面で開く）。並行して TA-4（Core ML の Qwen の試作）
```

## 機能カタログの分類（62 カテゴリ / 1,740 項目）

優先度は計画書「12. 優先順位の定義」（P0: 起動・表示・編集・保存・データ保護・ビルド安定性 / P1: ページ・フォルダ・Dock・壁紙・基本ウィジェット・検索・ミニアプリ / P2: LLM 実推論・天気・AI 支援・複雑なジェスチャ / P3: 高度な統計・拡張・実験的連携）。
「Phase」は主に着手する Phase。横断的なカテゴリは全 Phase で扱う。

| ID 範囲 | カテゴリ | Phase | 優先度 | 実現性・制限のメモ |
|---|---|---|---|---|
| F0001–F0040 | ホーム画面・レイアウト | 1→2→3 | P0/P1 | ステージマネージャー対応はウィンドウ幅への追従として扱う |
| F0041–F0080 | アイコン・アプリランチャー | 1→2→4 | P0/P1 | 写真からのアイコンは PhotosPicker（権限不要の選択）で Phase 4 |
| F0081–F0120 | Dock・クイックアクセス | 1→3 | P1 | |
| F0121–F0160 | フォルダ | 3 | P1 | 階層は1段に制限（循環参照を構造上防ぐ） |
| F0161–F0200 | ウィジェット・配置 | 4 | P1 | アプリ内ウィジェットのみ。WidgetKit は別機能（要PoC） |
| F0201–F0240 | 時計・時間・アラーム | 1→4→5 | P1 | バックグラウンドでのタイマー継続は OS制限（通知で代替） |
| F0241–F0280 | カレンダー・予定・タスク | 4→5 | P1 | ローカル保存が基本。カレンダー連携は権限が必要 |
| F0281–F0320 | 天気・環境情報 | 7 | P2 | API / キー管理が必要。WeatherKit は Playgrounds での利用可否が未確認（要PoC） |
| F0321–F0360 | メモ・ノート・クリップボード | 5 | P1 | |
| F0361–F0400 | ローカルLLM・AIアシスタント | 6 | P2 | 最初はスタブ。実推論は要PoC |
| F0401–F0440 | ローカルLLM・モデル管理 | 6 | P2 | モデルはユーザーが取り込む。同梱しない |
| F0441–F0480 | AIによる端末内支援・検索 | 6以降 | P2/P3 | 実行前確認が必須 |
| F0481–F0520 | 自作アプリ・ミニアプリ | 5 | P1 | 任意コードを実行するプラグインは作らない |
| F0521–F0560 | 開発者ツール・コードラボ | 5以降 | P3 | アプリ内でのコード実行は対象外（F0558） |
| F0561–F0600 | 検索・コマンドセンター | 3→5 | P1 | |
| F0601–F0640 | 通知・リマインダー | 5以降 | P2 | 通知権限が必要。まずアプリ内通知センター |
| F0641–F0680 | 外観・アニメーション | 1→4→8 | P1/P3 | Reduce Motion に従う |
| F0681–F0720 | 壁紙・画像・メディア | 4 | P1 | 大きな画像の縮小はメインスレッド外 |
| F0721–F0760 | バッテリー・システム情報 | 4以降 | P2 | Wi-Fi SSID・セルラー詳細は OS制限（説明のみ） |
| F0761–F0800 | ショートカット・連携 | 1→2→7 | P1/P2 | 他アプリ起動は対応 URL スキームのみ |
| F0801–F0840 | データ保存・バックアップ | 2→9 | P0 | アトミック書き込み、不正 JSON の拒否 |
| F0841–F0880 | プライバシー・安全性 | 全 Phase | P0 | 外部送信なしが既定 |
| F0881–F0920 | パフォーマンス・コンパイル | 0→全 Phase | P0 | |
| F0921–F0960 | テスト・品質管理 | 0→全 Phase | P0 | UI 操作テストは Simulator / 実機で別途 |
| F0961–F1000 | ヘルプ・アクセシビリティ | 1→8 | P1 | |
| F1001–F1020 | マルチタスク・ウィンドウ・作業空間 | 8以降 | P3 | アプリ内の作業空間として |
| F1021–F1040 | AIエージェント・自動化 | 6以降 | P3 | 実行前確認が必須 |
| F1041–F1060 | 創作・メディアスタジオ | 未定 | P3 | |
| F1061–F1080 | 開発者向け自動テスト・診断 | 0以降 | P2 | CI で一部を先行 |
| F1081–F1100 | パーソナライズ・ルールエンジン | 未定 | P3 | 自動変更ではなく提案＋承認 |
| F1101–F1120 | 共有・同期・複数端末 | 未定 | P3 | iCloud 等の利用可否は要PoC |
| F1121–F1140 | 空間UI・視覚効果・アクセシビリティ | 8以降 | P3 | 機能フラグで無効化できること |
| F1141–F1160 | セキュリティ・復元・堅牢性 | 2→9 | P1 | |
| F1161–F1180 | 知識ベース・学習・検索 | 6以降 | P3 | |
| F1181–F1200 | 超高度な統合・拡張 | 未定 | P3 | 任意コード実行はしない |
| D1201–D1220 | ビジュアル基礎・デザインシステム | 1→4 | P1 | まずデザイントークン |
| D1221–D1240 | ホーム画面レイアウト（デザイン） | 2→4 | P1 | |
| D1241–D1260 | アプリアイコン工房 | 4 | P1 | |
| D1261–D1280 | ウィジェットの見た目 | 4 | P1 | |
| D1281–D1300 | アニメーション・モーション | 8 | P2 | |
| D1301–D1320 | 壁紙・背景スタジオ | 4 | P1 | |
| D1321–D1340 | タイポグラフィ・文字表現 | 4 | P2 | Dynamic Type を優先 |
| D1341–D1360 | コントロール・ボタン設計 | 4 | P2 | |
| D1361–D1380 | フォルダ・整理表現 | 3 | P1 | |
| D1381–D1400 | 検索・ランチャーのデザイン | 3→5 | P2 | |
| D1401–D1420 | 通知・バナー・アラート | 5以降 | P2 | |
| D1421–D1440 | 設定画面のビジュアル | 4 | P2 | |
| D1441–D1460 | マルチタスク・ウィンドウ表現 | 8以降 | P3 | |
| D1461–D1480 | 3D・空間・奥行きデザイン | 8以降 | P3 | 2D の擬似表現から |
| D1481–D1500 | ビジュアルエフェクト | 8 | P3 | 機能フラグ必須 |
| D1501–D1520 | テーマ・スキン・プリセット | 1→4 | P1 | |
| D1521–D1540 | 色・配色インテリジェンス | 4以降 | P2 | |
| D1541–D1560 | レスポンシブ・画面適応 | 1→8 | P1 | |
| D1561–D1580 | アクセシビリティの視覚設計 | 8 | P1 | |
| D1581–D1600 | ドラッグ・ジェスチャーの見た目 | 2→3 | P2 | |
| D1601–D1620 | チャート・データ可視化 | 未定 | P3 | |
| D1621–D1640 | ミニアプリ共通デザイン | 5 | P1 | |
| D1641–D1660 | クリエイティブ編集UI | 未定 | P3 | |
| D1661–D1680 | オンボーディング・チュートリアル | 8 | P2 | |
| D1681–D1700 | デザイン品質・検証ツール | 8 | P2 | |
| D1701–D1720 | 未来型・超大型デザイン構想 | PoC のみ | P3 | |
| D1721–D1740 | デザイン共有・バージョン管理 | 9以降 | P3 | |
| M1–M10 | ムーンショット構想 | PoC のみ | — | 計画書「16. 評価テンプレート」を記録してから着手 |

## 着手済みの機能ID

「ビルド済」の UI は、コンパイルと Simulator での起動だけを確認したもの。タップ・スワイプ・読み上げは実機での確認待ち。

### ホーム・アイコン・Dock

| 機能ID | 名称 | 状態 | 場所・備考 |
|---|---|---|---|
| F0001 | アイコングリッドの表示 | ビルド済 | `Features/Home/HomePageGridView.swift` |
| F0002 | ページ単位のレイアウト | ビルド済 | `Core/Models/HomeLayout.swift`, `Features/Home/PagedGridView.swift` |
| F0003, F0004 | 縦画面 / 横画面用レイアウト | 部分 | 幅に応じて列数が変わるだけ。向きごとの専用レイアウトはない |
| F0005 | 画面幅に応じた列数調整 | テスト済 / ビルド済 | `Core/Logic/GridMetrics.swift` |
| F0006 | ウィンドウ幅変更への追従 | ビルド済 | GeometryReader で幅を取得。実機での幅変更は未確認 |
| F0008 | ページスワイプ | ビルド済 | TabView（ページ形式） |
| F0009 | ページインジケーター | ビルド済 | タップと VoiceOver の上下スワイプで移動 |
| F0039 | ホーム画面の初期レイアウト | テスト済 | `Core/Models/DefaultLayout.swift` |
| F0069 | Web URL ショートカット | テスト済 / ビルド済 | |
| F0070 | 確認付きリンク起動 | テスト済 / ビルド済 | `Core/Navigation/AppRouter.swift`, `Features/Launch/LaunchPresentationModifier.swift` |
| F0071 | 無効 URL の検出 | テスト済 | `Core/Logic/URLPolicy.swift` |
| F0078 | アイコンタップの演出 | ビルド済 | `DesignSystem/IconPressStyle.swift` |
| F0079 | アイコンのアクセシビリティ名 | ビルド済（補足文はテスト済） | |
| F0080 | デモアイコンと実リンクの区別 | テスト済 / ビルド済 | 外部リンク・スタブ・準備中の印 |
| F0081 | Dock の表示 | ビルド済 | `Features/Dock/DockView.swift` |
| F0117, F0118 | Dock の画面幅 / 狭いウィンドウ対応 | ビルド済 | ViewThatFits で小さいアイコン → 横スクロール |

### 編集・保存（Phase 2）

| 機能ID | 名称 | 状態 | 場所・備考 |
|---|---|---|---|
| F0035, F0036 | 編集モードの切替 / 視覚的区別 | ビルド済 | `Features/Edit/EditModeBar.swift`。時計を薄くしてバーを重ね、削除できる項目に − を表示 |
| F0077 | アイコンの長押し操作 | ビルド済 | `Features/Edit/ItemEditingModifiers.swift`（contextMenu。VoiceOver では「操作」） |
| F0041 | アイコンの追加 | テスト済 / ビルド済 | `Features/Edit/AddItemView.swift`、`Core/Logic/HomeLayout+Editing.swift` |
| F0042 | アイコンの削除 | テスト済 / ビルド済 | 確認ダイアログ付き。設定は削除できない |
| F0059 | アイコンの並べ替え | テスト済 / ビルド済 | 同じページ・Dock の中だけ。ドラッグで重ねる / VoiceOver の操作 |
| F0068 | アプリ URL スキームの登録 | テスト済 / ビルド済 | `Core/Logic/LinkDraft.swift`。危険なスキームは登録できない |
| F0801–F0803, F0807 | レイアウト・ページ・アイコン・テーマの保存 | テスト済 / ビルド済 | `Core/Persistence/`。`Application Support/MyHome/home.json` |
| F0821 | 不正 JSON の拒否 | テスト済 / ビルド済 | 元のファイルは `home.unreadable-<時刻>.json` に残す |
| F0822 | 未知フィールドの扱い | テスト済 | 読み飛ばす。設定の読めない値は初期値へ |
| F0823 | 古い形式の移行 | テスト済 / ビルド済 | 版 1（Phase 2）・版 2（Phase 3）のファイルを版 3 として読む（増えた値は初期値）。Simulator では版 1 のファイルからの復元を確認。新しい版のデータは上書きせず退避 |
| F0824 | ID 重複の検出 | テスト済 | ページ ID・項目 ID |
| F0834 | 保存エラーの通知 | テスト済 / ビルド済 | ホーム画面の帯と設定画面。再試行できる |
| F0835 | 保存処理の競合防止 | テスト済 | actor で順番に実行し、古い内容で新しい内容を上書きしない |
| F0836 | アトミック書き込み | テスト済 | `Data.write(options: .atomic)` |
| F0837 | 定期的な自動保存 | 部分 | 変更から 0.5 秒後と、裏に回る時に保存（時間ごとの定期保存はしない） |
| F0838 | 保存状態インジケーター | ビルド済 | 設定画面の「保存」 |
| F0940 | 破損 JSON テスト | テスト済 / ビルド済 | Linux の単体テストと、Simulator の起動テスト（broken） |

### ページ・フォルダ・Dock・取り消し（Phase 3）

| 機能ID | 名称 | 状態 | 場所・備考 |
|---|---|---|---|
| F0010, F0011, F0012, F0015 | ページ一覧・追加・削除・並べ替え | テスト済 / ビルド済 | `Features/Edit/PageManagerView.swift`、`Core/Logic/HomeLayout+Pages.swift`。削除は空のページだけ |
| F0032, F0033, F0034 | 編集履歴・取り消し・やり直し | テスト済 / ビルド済 | `Core/Store/HomeStore.swift`。30 手まで、起動中のみ |
| F0044, F0046, F0050 | 名前変更・SF Symbols の選択・背景色 | テスト済 / ビルド済 | `Features/Edit/ItemEditorView.swift` |
| F0061 | アイコンの一括移動 | 部分 | 1つずつの移動のみ（移動先の選択・ドラッグ） |
| F0076 | アイコンのコンテキストメニュー | ビルド済 | 「ホーム画面を編集」「削除」 |
| F0083, F0084, F0085 | Dock への追加・削除・並べ替え | テスト済 / ビルド済 | 6 個まで |
| F0099, F0100, F0110 | Dock の編集モード・ドラッグ・長押しメニュー | ビルド済 | ホームと同じ操作 |
| F0102 | Dock からのフォルダ起動 | ビルド済 | |
| F0121, F0122, F0123 | フォルダの作成・削除（解除）・名前変更 | テスト済 / ビルド済 | `Core/Logic/HomeLayout+Folders.swift`、`Features/Folder/FolderOverlayView.swift` |
| F0126, F0127, F0128 | フォルダ内の移動・取り出し・並べ替え | テスト済 / ビルド済 | |
| F0131 | フォルダプレビュー | ビルド済 | 最初の4項目を小さく表示（`DesignSystem/FolderTile.swift`） |
| F0143 | 空フォルダの自動整理 | テスト済 | 最後の項目を出すと取り除く |
| F0144 | フォルダ内の URL 起動 | ビルド済 | 確認ダイアログはホーム画面と同じ |
| F0146, F0147 | フォルダへのドラッグ追加 / フォルダ・ページ間の移動 | テスト済 / ビルド済 | フォルダからの取り出しは編集シートの「ページ N に移動」 |
| F0156, F0157 | フォルダの階層制限・循環参照の防止 | テスト済 | 1段まで。保存データの検証でも拒否 |
| F0160 | フォルダ操作の取り消し | テスト済 | 取り消しは全操作が対象 |

### 壁紙・画像・ウィジェット・タイマー（Phase 4）

画面は PR の CI でビルドと起動を確認する。写真の選択やタップの操作は実機での確認待ち。

| 機能ID | 名称 | 状態 | 場所・備考 |
|---|---|---|---|
| F0047, F0048 | カスタム画像アイコン / 写真から画像を選択 | テスト済（保存）/ 画面は確認中 | `Features/Edit/ItemImageSection.swift`。PhotosPicker（写真へのアクセスの許可は不要）。中央を正方形に切り出して 256px に |
| F0161, F0162 | ウィジェットギャラリー / 追加 | テスト済 / 画面は確認中 | 「項目を追加」の「ウィジェット」。1ページ 8 個まで |
| F0163, F0164, F0165 | ウィジェットの削除・移動・サイズ変更 | テスト済 / 画面は確認中 | 編集中の − と、ウィジェットの設定シート。移動は同じページの中の前後 |
| F0166, F0167 | 小 / 中サイズ | 画面は確認中 | 大（F0168）はない |
| F0179, F0189 | ウィジェットの編集メニュー / 設定の保存 | テスト済 / 画面は確認中 | `Features/Widgets/WidgetEditorView.swift` |
| F0202, F0203 | アナログ時計 / 秒表示 | 画面は確認中 | ウィジェットとホーム画面の時計。秒を表示する時だけ1秒ごとに描き直す |
| F0204, F0205 | 12 / 24 時間表示 | 対応 | 端末の設定に従う（アプリの中の切り替えはない） |
| F0218–F0224, F0227 | タイマーの作成・開始・一時停止・再開・リセット・複数・名前・カウントダウン | テスト済 / 画面は確認中 | `Core/Store/TimerStore.swift`、`Features/Timer/TimerAppView.swift`。終了時刻を覚えるので、戻った時の残り時間は正しい |
| F0225, F0226 | ストップウォッチ / ラップ | テスト済 / 画面は確認中 | |
| F0237 | バックグラウンド時の制限説明 | 画面は確認中 | 閉じている間は音が鳴らないことをタイマーの画面に表示 |
| F0241, F0243, F0260 | 月間カレンダー / 今日の強調 / 週の始まり | テスト済 / 画面は確認中 | `Core/Logic/MonthGrid.swift`。週の始まりは端末の設定 |
| F0647, F0650, F0651 | 壁紙の画像 / 明るさ / ぼかし | テスト済（保存）/ 画面は確認中 | `Features/Settings/WallpaperSettingsSection.swift`。長辺 2,800px に縮小して保存 |
| F0678 | 描画負荷の軽減 | 部分 | 画像は縮小して保存し、読み込んだものはメモリに 120 枚まで置く |
| F0805, F0806, F0811 | ウィジェット・壁紙・タイマーの保存 | テスト済 | 保存形式の版 3 |
| F0827 | 画像ファイル欠損の検出 | テスト済 / 画面は確認中 | なければ記号・グラデーションで表示。使われていない画像は、読み込みに成功した起動の時だけ消す |

### ミニアプリ（Phase 5）

画面は PR の CI でビルドと起動（保存ファイルを置いて各ミニアプリを開いた状態）を確認する。タップや入力の操作は実機での確認待ち。

| 機能ID | 名称 | 状態 | 場所・備考 |
|---|---|---|---|
| F0481, F0487 | ミニアプリの一覧・起動 | テスト済 / 画面は確認中 | 「項目を追加」の「アプリ内の機能」。ホーム画面の項目から開く |
| F0489, F0498 | 状態の保存・データ領域の分離 | テスト済 | `Core/MiniApps/MiniAppDocument.swift`・`MiniAppLibrary.swift`。1アプリ1ファイル（`Apps/<名前>.json`）、開いた時だけ読む |
| F0500 | ミニアプリのエラー画面 | テスト済（読めないファイルの退避）/ 画面は確認中 | 読めなかった理由を表示し、保存できない時は下に帯を出す |
| F0506, F0321–F0327 | メモ（作成・編集・削除・自動保存・検索・タイトル・本文） | テスト済 / 画面は確認中 | `Features/MiniApps/Notes/`。検索は全角・半角、大文字・小文字を区別しない |
| F0330, F0332 | ピン留め・最近編集した順 | テスト済 / 画面は確認中 | |
| F0333, F0334, F0335 | 文字数・作成日時・更新日時 | 画面は確認中 | 編集画面の下に表示 |
| F0339, F0353, F0357 | 削除の確認・ローカル保存・空のメモの扱い | テスト済 / 画面は確認中 | 何も書かずに閉じたメモは残さない |
| F0265–F0268 | タスクの作成・完了・期限・優先度 | テスト済 / 画面は確認中 | `Features/MiniApps/Tasks/`。期限は日付だけで保存（タイムゾーンが変わっても同じ日） |
| F0269–F0273 | 分類・並べ替え・期限切れ・今日・検索 | テスト済 / 画面は確認中 | 期限切れ・今日・これから・期限なし・完了に分ける |
| F0275 | 一括完了 | テスト済 / 画面は確認中 | 今日までのタスクをまとめて完了。完了したタスクのまとめての削除も（確認付き） |
| F0504 | 電卓 | テスト済 / 画面は確認中 | `Core/MiniApps/Calculator/`。10 進数で計算、優先順位とかっこ、履歴 50 件、ハードウェアキーボード |
| F0505 | 単位変換 | テスト済 / 画面は確認中 | 8 種類、日本の単位（尺・坪・合・貫）を含む |
| F0511, F0512, F0513, F0514 | JSON の整形・テキスト整形・Base64・文字数 | テスト済 / 画面は確認中 | `Core/MiniApps/TextTools/`。URL エンコード、全角⇔半角も |

### 時計・外観

| 機能ID | 名称 | 状態 | 場所・備考 |
|---|---|---|---|
| F0201 | デジタル時計 | ビルド済 | `Features/Home/ClockHeaderView.swift`（1分ごとに更新。秒を表示する時は1秒ごと） |
| F0206, F0207 | 日付 / 曜日表示 | ビルド済 | |
| F0641, F0642, F0643 | ライト / ダーク / システム連動 | ビルド済 | 設定は自動で保存（Phase 2） |
| F0645 | 複数のカラーパレット | テスト済 / ビルド済 | `Core/Models/ThemeCatalog.swift` |
| F0646 | 背景グラデーション | ビルド済 | `DesignSystem/WallpaperView.swift`（画像の壁紙がない時・読めない時もこれ） |
| F0653 | ガラス風マテリアル | ビルド済 | Dock の背景 |
| F0658 | アイコンのタップ縮小 | ビルド済 | |
| F0674 | Reduce Motion への配慮 | 部分 | タップ演出とページ移動のアニメーションのみ |
| D1201 | デザイントークン | 部分 | 余白・角丸・大きさ・動き。色と文字は未分離 |
| D1202 | ライトテーマのコントラスト | テスト済 | 壁紙上の文字 4.5:1 以上、強調色 3:1 以上 |
| D1205 | 複数パレットの切り替え | ビルド済 | 4 種 |

### リンク・安全性

| 機能ID | 名称 | 状態 | 場所・備考 |
|---|---|---|---|
| F0761 | Web サイトショートカット | テスト済 / ビルド済 | F0069 と同じ |
| F0762 | カスタム URL スキーム | テスト済 / ビルド済 | 「項目を追加」で登録（F0068） |
| F0764, F0854 | 起動前の確認 | テスト済 / ビルド済 | |
| F0765 | URL 形式の検証 | テスト済 | |
| F0766, F0853 | 危険なスキームの拒否 | テスト済 | javascript / vbscript / data / file / blob / about |
| F0781 | リンク先ドメイン表示 | テスト済 | 確認ダイアログにホスト名を表示 |
| F0782 | 外部ブラウザー起動 | ビルド済 | SwiftUI の openURL |
| F0784 | 起動失敗の通知 | テスト済 / ビルド済 | |
| F0866 | データ収集を行わない既定値 | 対応 | 通信するのは、確認したリンクを開く時、ソフトウェアアップデート（GitHub）、利用者がオンにした天気（Open-Meteo）だけ |

### ローカル LLM・AI（Phase 6）

Apple の端末内モデル（Foundation Models）は、iPadOS 26 以降・Apple Intelligence 対応機種・iOS 26 SDK でビルドした時だけ使える。
CI（Xcode 26.3）ではコンパイルだけを確認でき、実際の応答は Apple Intelligence に対応した iPad での確認待ち。

| 機能ID | 名称 | 状態 | 場所・備考 |
|---|---|---|---|
| F0361 | AI チャット画面 | ビルド確認中（端末内モデル）/ ビルド済（スタブ） | `Features/AIChat/AIChatView.swift`。スタブの応答は「[スタブ応答]」で始まる決まった文 |
| F0362 | 新しい会話 | テスト済 / 画面は確認中 | 会話を消し、モデルの会話の記憶もなくすため読み込み直す |
| F0374, F0380 | モデルの一覧・切り替え | ビルド済（Simulator で表示を確認） | Apple の端末内モデルとスタブ。使えないモデルは理由を表示して読み込めない |
| F0378 | モデルのロード状態表示 | ビルド済 | |
| F0379, F0439 | モデルのアンロード / 安全なアンロード | テスト済 | 画面を閉じると生成を止めて解放 |
| F0381, F0422 | 初回の案内・使えない理由 | テスト済（理由の受け渡し）/ 画面は確認中 | 機種が非対応・Apple Intelligence がオフ・準備中・iPadOS が古い・SDK が古い、を分けて表示 |
| F0391 | ストリーミング出力 | テスト済（全文から増えた分を取り出す）/ 実機未確認 | 端末内モデルは「それまでの全文」を返すので、増えた分だけを足す |
| F0392 | 生成のキャンセル | テスト済 / ビルド済 | |
| F0394 | 回答のコピー | 画面は確認中 | 長押しでコピー |
| F0397, F0398, F0399 | 端末内で処理する表示・ネット不要・データの説明 | 画面は確認中 | 端末内モデルは入力を端末の外に送らない |
| F0421, F0434 | 失敗の説明・会話が長すぎる時の案内 | テスト済（受け渡し）/ 実機未確認 | 長すぎる・安全の制限・未対応の言語・データがない・使いすぎ を日本語で説明 |
| F0468, F0991 | モデル未導入時の説明 | ビルド済 | |
| F0895 | LLM エンジンの独立モジュール化 | 部分 | プロトコルの境界と、iOS 26 SDK の時だけビルドする端末内モデルの部分（`#if canImport(FoundationModels)`）。llama.cpp は別ブランチの PoC |
| F0896 | LLM の遅延ロード | テスト済 | 起動時は作らない。読み込みはボタンを押した時だけ |
| F0897 | モデル未導入でもビルド可能 | ビルド済 | 推論エンジン・モデルへの依存なし |
| F0898 | モデルファイルをソースに含めない | 対応 | `.gitignore` |
| F0945, F0947, F0948, F0949 | モデル未導入 / ロード失敗 / キャンセル / 長文入力のテスト | テスト済 | `Tests/MyHomeCoreTests/LLMSessionControllerTests.swift` |

### 天気（Phase 7）

Open-Meteo（無料・非商用、API キーなし）。通信は天気の画面で利用者がオンにするまでしない。実機での通信は未確認。

| 機能ID | 名称 | 状態 | 場所・備考 |
|---|---|---|---|
| F0281, F0302, F0303 | 都市名の入力・お気に入りの場所・切り替え | テスト済 / ビルド済 | `Core/Weather/WeatherController.swift`、`Features/Weather/WeatherSearchView.swift`。10 か所まで |
| F0283 | 位置情報なしの利用 | 対応 | 位置情報は使わず、許可も求めない |
| F0284–F0289 | 今の天気・気温・体感・最高・最低・記号 | テスト済（読み取り・表示の文字）/ ビルド済 | `Features/Weather/CurrentWeatherCard.swift` |
| F0290–F0293 | 時間別・日別の予報、降水確率・降水量 | テスト済 / ビルド済 | 時間別は 48 時間分を保存し、24 時間分を表示 |
| F0294 | 降水開始の予測 | テスト済 | 12 時間以内で降水確率 50% 以上の最初の時間（目安） |
| F0295–F0300 | 風速・風向・湿度・UV 指数・日の出・日の入り | テスト済 / ビルド済 | 風向は 16 方位、UV は気象庁の区分 |
| F0304–F0307 | 更新日時・更新ボタン・失敗時の表示・オフライン時の最終データ | テスト済 / ビルド済 | 失敗しても前回の天気を消さない |
| F0308 | API の利用制限の表示 | テスト済 | HTTP 429 の時に上限を説明 |
| F0309, F0310 | API キーの扱い・サービスの差し替え | 対応 | キーは不要（保存しない）。通信は WeatherTransport の後ろに分けた |
| F0311, F0312 | 摂氏・華氏、風速の単位 | テスト済 / ビルド済 | |
| F0315, F0316 | 降水のグラフ・週間の気温のグラフ | ビルド済 | 降水確率の棒と、週の気温の幅の中の棒（Swift Charts は使っていない） |
| F0317 | 天気に応じた背景色 | ビルド済 | 天気と昼夜で色を変える |
| F0319, F0320 | 天気のキャッシュ・テスト用のモック | テスト済 | 場所ごとに最後の1回分。`Tests/MyHomeCoreTests/WeatherTestSupport.swift` |
| F0301, F0282, F0313, F0314, F0318 | 気象警報・現在地・天気のウィジェット・通知 | 未実装 | 理由は「Phase 7 で作らなかったもの」 |

### データ・バックアップ・プライバシー（Phase 9）

| 機能ID | 名称 | 状態 | 場所・備考 |
|---|---|---|---|
| F0812, F0814 | JSON バックアップの出力、ファイルアプリへの書き出し | テスト済（作成）/ ビルド確認中（書き出し） | `Core/Backup/BackupBuilder.swift`、`Features/Settings/Backup/` |
| F0813, F0815 | JSON バックアップの読み込み、ファイルアプリから読み込み | テスト済（読み込み）/ ビルド確認中（選択） | `Core/Backup/BackupReader.swift`、`BackupDocument.swift` |
| F0817, F0818 | バックアップの日時・版の表示 | テスト済 | 作成日時（ISO 8601）・形式の版・アプリの版 |
| F0819, F0820, F0861 | 読み込み前のプレビューと確認、含む情報の表示 | テスト済（要約）/ ビルド確認中 | ページ・項目・ウィジェット・テーマ・画像・ミニアプリ |
| F0821, F0822, F0824, F0827 | 不正な JSON の拒否、未知のファイルの扱い、重複の検出、画像の欠損の検出 | テスト済 | 1 つでも読めなければ何も変えない。知らないファイルは書かない |
| F0823 | 古い形式の移行 | テスト済 | 各 Phase のコミットのコードで作った保存ファイルで確認 |
| F0828, F0829 | 部分復元・全体復元 | テスト済 / ビルド確認中 | 選ばなかったものは今のまま |
| F0830 | 復元前の自動バックアップ | テスト済 | 残せなければ中止 |
| F0831, F0832 | バックアップの削除・一覧 | テスト済 / ビルド確認中 | 自動 5 個・手動 10 個まで |
| F0835 | 保存処理の競合防止（復元時） | テスト済 | 入れ替える前のストアは保存をやめる |
| F0839, F0868 | データの全消去、ユーザーデータの削除手段 | テスト済 / ビルド確認中 | 消す前のデータを残す |
| F0742–F0746, F0756, F0840–F0849, F0865–F0867, F0870 | 権限・通信・保存先・データ保護の説明 | テスト済（内容）/ ビルド確認中 | `Core/Models/AboutCatalog.swift`。通信先は実際の URL と照合 |
| F0816, F0833 | バックアップの名前・検索 | 未実装 | 一覧が少ないため |

### パフォーマンス・テスト・ヘルプ

| 機能ID | 名称 | 状態 | 場所・備考 |
|---|---|---|---|
| F0881, F0883–F0887 | ファイル・View の分割、型推論が重い式の分割 | 対応 | 最大 124 行 / ファイル。遅い型チェックを CI で監視 |
| F0888, F0889 | 依存関係・外部パッケージの最小化 | 対応 | 外部パッケージ 0 |
| F0890, F0891, F0892 | 初期 / 増分ビルドの計測と記録 | 部分 | Linux・macOS は記録済み。iPad は未計測 |
| F0901 | LazyVGrid の利用 | ビルド済 | |
| F0902 | 重い処理のメインスレッド回避 | 部分 | 保存のエンコードと書き込みは actor で実行。写真の縮小とアップデートの読み書きはメインスレッドの外。起動時の読み込みは同期（1MB 未満）。推論はプロバイダー側のタスクで行う設計 |
| F0903, F0904 | 非同期処理、キャンセル可能なタスク | テスト済 | LLM セッション |
| F0905, F0906 | 無駄な状態更新の削減、描画更新範囲の限定 | 対応 | @Observable、時計は TimelineView 内だけ更新。描画回数の計測はしていない |
| F0909, F0950 | 大量項目の検証 | テスト済（ロジック）/ ビルド済（150 件で起動・表示） | スクロール操作は未確認 |
| F0916 | サンプルデータの分離 | 対応 | `Core/Models/SampleLayout.swift`、起動引数でのみ使用 |
| F0917 | ビルド可能な最小構成の維持 | ビルド済 | |
| F0918 | コンパイルエラーの再現手順 | 対応 | `docs/BUILD.md` |
| F0921 | 起動テスト | ビルド済 | `scripts/smoke-test-simulator.sh` |
| F0941 | 不正 URL テスト | テスト済 | |
| F0971 | OS 制限の説明 | ビルド済 | 機能の状況画面 |
| F0975 | VoiceOver ラベル | ビルド済 | 読み上げの確認は未実施 |
| F0977 | Dynamic Type 対応 | 部分 | システムフォント。時計は ScaledMetric |
| F0979 | コントラスト確認 | テスト済 | テーマとアイコンの印 |
| F0980 | 色だけに依存しない状態表示 | ビルド済 | 印の文字・選択中の記号 |
| F0982 | タップ領域の確保 | 部分 | ページの点は 28pt（44pt 未満） |
| F0988 | 空状態の説明 | ビルド済 | |
| F1200 | アプリ内ロードマップ表示 | ビルド済 | 機能の状況画面 |
