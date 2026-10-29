# All-in-one-home

iPad 版 Swift Playgrounds / SwiftUI で作る、アプリ内のオールインワン・ホーム画面「My Home」。
iPadOS の標準ホーム画面を置き換えるものではなく、独立したアプリの中で動くランチャーです。

- iPad で開くもの: [`MyHome.swiftpm`](MyHome.swiftpm)（外部パッケージ依存なし）
- 計画: [PLAN.md](PLAN.md) ／ 進捗: [TASKS.md](TASKS.md) ／ 機能カタログ（原本）: [docs/feature-catalog.md](docs/feature-catalog.md)
- ビルド方法: [docs/BUILD.md](docs/BUILD.md) ／ ビルド時間の記録: [docs/BUILD_TIMES.md](docs/BUILD_TIMES.md)

## 現在の状態

Phase 1（最小ホーム）まで実装済み。時計、アイコングリッド、ページ切り替え、Dock、テーマ（4種・ライト / ダーク）、
確認付きの外部リンク起動、機能の状況画面、AI 画面（スタブのみ・モデル未導入）があります。

- 確認済み: Linux での Core の単体テスト（61件、Swift 5.10.1 / 6.0.3 / 6.4.1）、macOS での iOS Simulator 向けビルドと起動（Xcode 16.4 / 26.3）
- 未確認: iPad 実機の Swift Playgrounds でのビルドと操作、画面のタップ・スワイプ・読み上げ
- まだ無いもの: 配置の編集と保存（Phase 2）、フォルダ（Phase 3）、ウィジェット・壁紙画像（Phase 4）、ミニアプリ（Phase 5）、ローカル LLM の実推論（Phase 6、要 PoC）、天気（Phase 7）

各機能の状態は TASKS.md を参照してください。
