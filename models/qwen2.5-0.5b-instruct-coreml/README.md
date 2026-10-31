# Qwen2.5-0.5B-Instruct（Core ML）

MyHome の AI 画面で使う、端末内で動く小さな言語モデル（追加フェーズ A の TA-4）。

- 元のモデル: [Qwen/Qwen2.5-0.5B-Instruct](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct)（Alibaba Cloud、Apache License 2.0。全文は `LICENSE-Qwen2.5.txt`）
- このフォルダのファイル:
  - `vocab.json`・`merges.txt`: トークナイザー（元のモデルのファイルをそのまま）
  - `Qwen*.mlpackage`（これから置く）: `scripts/coreml/convert_qwen.py` で Core ML に変換したもの（iOS 18 以降、重みは 4bit、
    KV キャッシュは Core ML の状態）。GitHub の 1 ファイル 100MB の上限に収めるため 5 つに分けている
- アプリは、このフォルダのファイルを AI の画面（と初期設定）から 1 回だけ取得し、端末の上でコンパイルして使う。
  ビルドを速く保つため、`MyHome.swiftpm` には入れていない（ソフトウェアアップデートの対象にもならない）。
- 変換と確認の手順は `.github/workflows/coreml-qwen.yml`（変換 → Python での予測の確認 → アプリと同じ Swift のエンジンで答えさせる）。
