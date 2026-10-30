# 移行テストの保存ファイルの作り方

`Tests/MyHomeCoreTests/Fixtures/Migration/` の保存ファイルは、手で書いたものではなく、
それぞれの時点のコミットのコードで作ったものです（「アップデート相当の移行」を確かめるため。Phase 9）。

| ファイル | 作ったコミット | 内容 |
|---|---|---|
| `home-v1-phase2.json` | `adac863`（Phase 2、形式の版 1） | 項目の追加・並べ替え・削除、テーマ forest・ダーク |
| `home-v2-phase3.json` | `f574871`（Phase 3、形式の版 2） | フォルダ・ページの追加・項目の名前の変更、テーマ sunset・ライト |
| `home-v3-phase4.json` | `f0e59d2`（Phase 4、形式の版 3） | ウィジェット・アイコンの画像・画像の壁紙・タイマー（動いているもの・ストップウォッチ） |
| `home-v3-phase7.json` | `8320b4a`（Phase 7） | 動き・文字の大きさの設定がない最後の版の設定 |
| `apps-v1-*.json`（天気以外） | `48db4f1`（Phase 5） | メモ・タスク・電卓・単位変換・テキストツール |
| `apps-v1-weather.json` | `8320b4a`（Phase 7） | 天気（場所 2 か所・前回の天気・単位） |

## 作り直す時

`FixtureGen-<コミット>.swift.txt` が、それぞれのコミットで使ったテストです。

```bash
git worktree add --detach /tmp/gen-adac863 adac863
```

```bash
cp scripts/fixtures/migration/FixtureGen-adac863.swift.txt /tmp/gen-adac863/Tests/MyHomeCoreTests/FixtureGenTests.swift
```

```bash
cd /tmp/gen-adac863 && FIXTURE_OUT=/path/to/output swift test --filter FixtureGenTests
```

作ったファイルは、そのまま `Tests/MyHomeCoreTests/Fixtures/Migration/` に置きます（中身は書き換えない）。
保存形式を変えた時は、変える前のコミットでも同じように作り、新しい版との組み合わせをテストに足します。
