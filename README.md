# All-in-one-home

iPad 版 Swift Playgrounds / SwiftUI で作る、アプリ内のオールインワン・ホーム画面「My Home」。
iPadOS の標準ホーム画面を置き換えるものではなく、独立したアプリの中で動くランチャーです。

- iPad で開くもの: [`MyHome.swiftpm`](MyHome.swiftpm)（外部パッケージ依存なし）
- 計画: [PLAN.md](PLAN.md) ／ 進捗: [TASKS.md](TASKS.md) ／ 機能カタログ（原本）: [docs/feature-catalog.md](docs/feature-catalog.md) ／ Phase 10 の総合機能 300 項目（原本）: [docs/phase10-catalog.md](docs/phase10-catalog.md)
- ビルド方法: [docs/BUILD.md](docs/BUILD.md) ／ ビルド時間の記録: [docs/BUILD_TIMES.md](docs/BUILD_TIMES.md)

## 現在の状態

Phase 4（壁紙・ウィジェット・タイマー）まで実装済み。時計、アイコングリッド、ページ切り替え、Dock、テーマ（4種・ライト / ダーク）、
確認付きの外部リンク起動、機能の状況画面、AI 画面（スタブのみ・モデル未導入）に加えて、
長押しからの編集モード、項目の追加（Web リンク・URL スキーム・アプリ内の機能）と削除、同じページ・Dock の中での並べ替え、
配置と設定の自動保存と再起動後の復元、ページの管理、ページ・Dock・フォルダをまたぐ移動、フォルダ（1段まで）、
名前・記号・色の変更、取り消し・やり直し、壁紙の写真とアイコンの画像、アプリ内ウィジェット（時計・カレンダー・メモ・タイマー）、
タイマーとストップウォッチ、設定の「ソフトウェアアップデート」（GitHub のブランチから変わったファイルだけを書き込む）があります。

- 確認済み: Linux での Core の単体テスト（202件、Swift 5.10.1 / 6.0.3 / 6.4.1）、macOS での iOS Simulator 向けビルドと起動（Xcode 16.4 / 26.3。保存ファイルからの復元と、壊れたファイルの退避を含む）、
  iPad 実機の Swift Playgrounds での Phase 1 の起動（ユーザー報告）
- 未確認: iPad 実機での Phase 2・3 の操作（長押し・ドラッグ・追加シート・フォルダ）、画面の読み上げ
- まだ無いもの: ミニアプリ（Phase 5）、ローカル LLM の実推論（Phase 6、要 PoC）、天気（Phase 7）

各機能の状態は TASKS.md を参照してください。
