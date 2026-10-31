# Core ML の Qwen2.5-0.5B（追加フェーズ A の TA-4）

ユーザーの依頼「AI は Core ML を使い、モデルは Qwen の 0.5B を標準搭載。ビルドは早く」のための変換と確認。

| ファイル | 内容 |
|---|---|
| `qwen_model.py` | Qwen2 を Core ML に変換しやすい形で書き直したもの（KV キャッシュは Core ML の状態、RMSNorm は layer_norm で計算、形から整数を取り出さない） |
| `convert_qwen.py` | `verify`: transformers と同じ答えになるか。`convert`: 9 つの .mlpackage に変換する |
| `check_coreml.py` | macOS の Core ML で予測し、正解と比べる（Linux では Core ML の予測ができない） |
| `quantization_study.py` | 量子化のしかたと答えの変わり方を、PyTorch の上で比べる |
| `make_tokenizer_cases.py` | Swift のトークナイザーのテストの正解を作る |
| `make_manifest.py` | アプリが取得するファイルの一覧（`QwenModelManifest+Files.swift`）を作る |

確認は `.github/workflows/coreml-qwen.yml`（CI の Mac で変換 → Python で予測 → アプリと同じ Swift のエンジンで答えさせる）。

## 量子化を決めた理由

`quantization_study.py` の結果（5 つの質問・146 トークン。元のモデルの答えと、各位置の一番高いトークンが同じだった割合）:

| 層 | 入力の埋め込み | 出力 | 区切り | 一致 |
|---|---|---|---|---|
| 4bit | 4bit | 4bit | 32 | 71% |
| 4bit | 4bit | 4bit | 16 | 78% |
| 8bit | 8bit | 8bit | 32 | 93% |
| 8bit | 4bit | 8bit | 32 | 93% |
| 8bit | 4bit | 4bit | 16 | 86% |
| 4bit | 8bit | 8bit | 16 | 71% |

- 0.5B の小さなモデルは、層を 4bit にすると答えが目に見えて変わる（朝ごはんを聞くと「お答えできません」と言うなど）。
- 入力の埋め込みは 4bit にしても変わらない。層と出力は 8bit にする。
- 最初に全部を 4bit にした版は、CI の Mac の Core ML で「日本の首都は東京です。」と答え、毎秒 21.8 トークンだった（正解は「東京都です。」。一致 75%）。

8bit にすると 1 ファイル 100MB（GitHub の上限）を超えるので、層は 4 つずつ 6 つ、出力は語彙の前半と後半の 2 つに分けた。合計 約 600MB。
