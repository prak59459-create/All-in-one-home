# ビルド方法と計測手順

アプリ本体は `MyHome.swiftpm`（Swift Playgrounds のアプリプロジェクト形式）。外部パッケージには依存しない。

## A. iPad の Swift Playgrounds（本番）

必要なもの: iPadOS 17 以上、Swift Playgrounds 4.4 以上（`@Observable` と iOS 17 SDK が必要）。
コンパイルを確認済みなのは iOS 18 SDK（Xcode 16.4 相当）と iOS 26 SDK（Xcode 26.3 相当）。iOS 17 SDK の Swift Playgrounds（4.4 / 4.5）では未確認。

1. `MyHome.swiftpm` フォルダを iPad に置く。例:
   - GitHub のリポジトリ画面で「Code」→「Download ZIP」→ ファイル App で ZIP を開いて展開する。
   - または Git クライアント App でクローンする。
2. ファイル App で `MyHome.swiftpm` をタップすると Swift Playgrounds で開く（iCloud Drive の「Playgrounds」フォルダへ移すと一覧にも出る）。
3. 実行（▶）してホーム画面が表示されることを確認する。

注意:
- `Package.swift` は Playgrounds の「App設定」を変更すると自動で書き直される場合がある。標準形だけを使っているので、書き直されても動く想定。
- `MyHome.swiftpm` の外（リポジトリ直下の `Package.swift`、`Tests/`、`scripts/`）は Playgrounds では使わない。

### アプリの中からの更新（設定 → ソフトウェアアップデート）

GitHub のブランチから、変わったファイルだけを iPad の `MyHome.swiftpm` に書き込む。

**最初の1回だけ**は、アップデート機能の入った版を上の手順で手動で入れる（今の iPad の版にはこの機能がないため）。
GitHub でブランチ（例: `claude/cool-maxwell-asqk2v`）を選んでから「Code」→「Download ZIP」とすると、そのブランチの版が取れる。

2回目からは MyHome の中で:

1. 設定 → ソフトウェアアップデート →「MyHome.swiftpm を選ぶ」。Files の「ブラウズ」で、Swift Playgrounds が使っている `MyHome.swiftpm`（ふつうは iCloud Drive の「Playgrounds」フォルダ）を選ぶ。
   - Files の中の元のフォルダを開く方式（コピーを受け取らない）。アプリの中へのコピーが選ばれた時は断る。
   - 選んだフォルダの `Package.swift` が Swift Playgrounds のアプリの形で、`Core/PackageIdentity.swift` の識別子がこのアプリと一致する時だけ、書き込み先として覚える。
2. 「ブランチを読み込む」→ ブランチを選ぶ →「違うファイルを確認」。手元の各ファイルの git のハッシュと、GitHub のファイル一覧を比べる。
   - そのコミットの CI（iOS 18 SDK・iOS 26 SDK でのビルドと起動テスト）が成功しているかも表示する。成功していないコミットは、もう一度確認しないと書き込めない（ビルドできない版を書き込むと、アプリから「元に戻す」も使えなくなるため）。
   - 手元で変更したファイル（前回の更新の後に変わったもの）と `Package.swift`（Swift Playgrounds の「App 設定」で書き換わる）は、選んだ時だけ上書きする。
3. 「書き込む」。必要なファイルを全部取得してハッシュを確かめてから、上書き・削除する前のファイルをアプリの中に退避して書き込む。途中で失敗したら、その場で書き込む前に戻す。
4. Swift Playgrounds で ■（停止）→ プロジェクトの一覧に戻って MyHome を開き直す → ▶。**アプリ自身はビルドし直せない**ので、この操作が必要。
   ソフトウェアアップデートの画面に、いま動いている版が書き込んだコミットでビルドされたかが表示される（`Core/BuildStamp.swift` に書き込んだコミットを入れている）。
5. おかしい時は「最後の更新の前に戻す」。

通信するのはこの画面でボタンを押した時だけ（api.github.com と raw.githubusercontent.com）。トークンなしの GitHub API は 1 時間に 60 回まで（1回の確認で 3 回使う。ファイル本体は raw.githubusercontent.com から取るので数えない）。

### iPad でのビルド時間の計測（手動）

Playgrounds はビルドログを出さないため、ストップウォッチで計る（誤差 ±0.5 秒程度）。

1. **初回フルビルド**: プロジェクトを開き直した直後に ▶ をタップしてから、アプリ画面が表示されるまで。
2. **増分ビルド**: 1ファイルの小さな変更（例: 表示文字列を1文字変える）をしてから ▶ をタップし、アプリが再表示されるまで。
3. iPad の機種、iPadOS、Swift Playgrounds のバージョンと一緒に [BUILD_TIMES.md](BUILD_TIMES.md) の「iPad」表に記入する。

## B. macOS（Xcode / GitHub Actions）

- Xcode で開く: Finder で `MyHome.swiftpm` をダブルクリック、または `xed MyHome.swiftpm`。
- コマンドラインでビルド時間を計測:

```bash
scripts/measure-app-build.sh
```

  iOS Simulator（最新ランタイムの iPad）向けに、クリーン / 変更なし / View 1ファイル変更 / Core 型のインターフェース変更の4種類を計測し（クリーン以外は3回の中央値。回数は `REPEAT` で変更可）、型チェックが 100ms を超えた関数・式を一覧にする。結果とログは `build-logs/app/`。

- Simulator で起動確認（`measure-app-build.sh` の後に実行。`SIM_UDID` は計測時に表示された値）。初期レイアウト、項目 0 件、1ページ 150 件、保存ファイルからの復元（`scripts/fixtures/home-restore.json`、形式の版 1）、フォルダ入りの保存ファイル（`home-folder.json`）での編集モードとフォルダを開いた状態、ミニアプリ5つ（`scripts/fixtures/apps/*.json` を置いて、それぞれを開いた状態）、壊れた保存ファイルの12通りで起動し、それぞれ 10 秒後も動いているかを確認してスクリーンショットを撮る。復元・ミニアプリ・破損では、保存ファイルが読まれたか・別名に退避されたかも確かめる:

```bash
SIM_UDID=<UDID> scripts/smoke-test-simulator.sh
```

- 検証用の起動引数（Xcode のスキーム設定や `simctl launch` で指定。Swift Playgrounds では指定できない）:
  - `-MyHomeSampleItems <件数>`: 初期レイアウトの代わりに、指定した件数の検証用項目を表示する（上限 2,000 件）
  - `-MyHomeSampleItemsPerPage <件数>`: 1ページあたりの件数（既定 60）
  - `-MyHomeStartEditing`: 編集モードで起動する（スクリーンショットで編集中の表示を確かめるため）
  - `-MyHomeOpenFolder <項目 ID>`: そのフォルダを開いて起動する
  - `-MyHomeOpenFeature <機能の名前>`: その機能（`notes`・`tasks`・`calculator`・`unitConverter`・`textTools` など。`AppFeature` の rawValue）を開いて起動する。準備中の機能は開かない
  - 検証用の配置で起動した時は保存しない（利用者の保存データを上書きしないため）。設定画面の「保存」に理由を表示する。

保存ファイルの場所（Simulator）: `xcrun simctl get_app_container <UDID> com.example.myhome data` の下の `Library/Application Support/MyHome/home.json`。
ミニアプリのデータは同じフォルダの `Apps/<名前>.json`（`notes`・`tasks`・`calculator`・`converter`・`texttools`）。

GitHub Actions（`.github/workflows/ci.yml` の `app-ios` ジョブ）でも同じスクリプトを Xcode 16.4（iOS 18 SDK）と Xcode 26.3（iOS 26 SDK）で実行し、ジョブのサマリーに結果表を出す。スクリーンショットとログはアーティファクト `app-build-logs-xcode-<版>` に保存される。

CI の注意: PR では `paths` の絞り込みが「PR 全体の差分」で判定されるため、文書だけを変えた push でも CI が動く。さらに同じ PR の実行中の CI は新しい push で取り消される（`concurrency`）。計測や起動テストの途中結果が欲しい時は、終わるまで push しない。

## C. Linux（Core のみ）

[swift.org](https://www.swift.org/install/) の Swift ツールチェーンを入れてから、リポジトリ直下で実行する。

```bash
scripts/measure-core-build.sh
```

```bash
swift test
```

Swift 6 言語モードで本体を確認する場合:

```bash
SWIFT_EXTRA_FLAGS="-Xswiftc -swift-version -Xswiftc 6" scripts/measure-core-build.sh
```

SwiftUI ファイルの構文だけを確認する（型チェックはしない）:

```bash
scripts/parse-ui.sh
```

## コンパイルエラーを再現するとき

1. どの層で失敗したかを確認する（A: Playgrounds / B: macOS / C: Linux）。
2. C で再現する場合は `scripts/measure-core-build.sh` のログ（`build-logs/core/*.log`）を見る。
3. B で再現する場合は `build-logs/app/clean.log` を見る。CI ではアーティファクト `app-build-logs-xcode-<版>` に同じログがある。
4. A でだけ失敗する場合は、Swift Playgrounds のバージョンと、エラーが出たファイル・行を記録する（Playgrounds の Swift バージョンが CI と異なる可能性が高い）。
