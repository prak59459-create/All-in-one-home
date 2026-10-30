# llama.cpp PoC（LlamaPoC.swiftpm）

MyHome とは別の、小さな試作アプリです。iPad の Swift Playgrounds で作ったアプリから llama.cpp（GGUF 形式のモデルを動かすライブラリ）を使えるかを確かめます。
MyHome 本体はこのアプリを使いません（MyHome の AI は Phase 6 で Apple の端末内モデル（Foundation Models）を使うようにしました）。

## 確かめたいこと

1. **Swift Playgrounds がこのパッケージをビルドして起動できるか。** いちばん分からない点です。
   llama.cpp は公式リリースの XCFramework（ビルド済みのバイナリ、b11998、zip で約 70MB）を `binaryTarget` で取り込んでいます。
   中身は動的ライブラリ（`llama.framework`）なので、Swift Playgrounds が取得・署名・読み込みのどこかで断る可能性があります。
2. **iPad で GGUF のモデルを読み込み、文章を生成できるか。** 読み込みにかかった時間と、生成の速さ（トークン/秒）を画面に出します。

## CI で確かめていること・いないこと

- 確かめている: Xcode 16.4（iOS 18 SDK）と Xcode 26.3（iOS 26 SDK）で、iPad 実機向け（`generic/platform=iOS`、署名なし）にコンパイル・リンクできること。
  できたアプリに `llama.framework` が入っていること（`.github/workflows/poc-llama.yml`）。
- 確かめていない: 実際に動くかどうか。llama.cpp の配布物には iOS Simulator 用が入っていないため Simulator では起動できず、CI には iPad もありません。
  Swift Playgrounds での動作も CI では分かりません。**動作の確認は iPad で試してもらう必要があります。**

## iPad での試し方

1. iPad の Safari で GitHub のこのリポジトリを開き、ブランチを `claude/llama-cpp-poc` に切り替えて「Code」→「Download ZIP」。
2. ファイル App で zip を展開し、`PoC/LlamaPoC.swiftpm` を Swift Playgrounds で開く。
   最初の1回は llama.cpp の XCFramework（約 70MB）をダウンロードするので、インターネットにつないでおく。
3. GGUF 形式の小さなモデルを用意して、ファイル App の「このiPad内」に置く（iCloud Drive にあると、ダウンロードされていなくて読めないことがあります）。
   まずは 1B 以下の指示調整済み（Instruct）モデルを Q4_K_M などで量子化した、1GB 未満のファイルから試してください。
   例: Qwen2.5-0.5B-Instruct の GGUF（Apache-2.0）。モデルごとにライセンスが違うので、使う前に配布元のページで確認してください。
4. アプリを実行し、「GGUF ファイルを選ぶ」→ 読み込みが終わったら「生成する」。

Swift Playgrounds の「App設定」は変えないでください。変えると Package.swift が書き直され、llama.cpp の指定が消えることがあります。

## 結果を教えてほしいこと

| 段階 | うまくいった時 | 失敗した時に考えられること |
|---|---|---|
| A. パッケージの取得とビルド | エラーなしで実行できる | Swift Playgrounds が `binaryTarget`（ビルド済みのバイナリ）に対応していない |
| B. 起動 | 画面が出る | 起動直後に落ちる → `llama.framework`（動的ライブラリ）を読み込めない・署名が通らない |
| C. モデルの読み込み | 「読み込みました」と時間が出る | メモリが足りない（小さいモデルで試す）、ファイルが GGUF でない・iCloud にある |
| D. 生成 | 日本語の答えとトークン/秒が出る | 文字化け・意味の通らない文 → モデルのチャットの形式が合っていない可能性 |

あわせて、iPad の機種・iPadOS の版・Swift Playgrounds の版・使ったモデルのファイル名と大きさ・読み込み時間・トークン/秒を教えてください。
エラーが出た時は、その文（またはスクリーンショット）があると原因を絞れます。

## この PoC の範囲

- 1問1答だけ。前の質問は覚えていません（毎回消します）。コンテキストは 2,048 トークン。
- 生成中にアプリを裏に回すと、iPadOS は裏での GPU の利用を許さないため、失敗することがあります。生成中は前に出しておいてください。
- モデルのファイルはアプリにコピーせず、選んだ場所から直接読みます（大きなファイルを二重に持たないため）。読み込んでいる間はそのファイルを動かさないでください。
- MyHome には組み込みません。組み込むかどうかは、この PoC の結果を見て別に決めます
  （組み込むと MyHome が外部のバイナリに依存し、ダウンロードとビルドの時間も増えるため）。

## llama.cpp の版を上げる時

`Package.swift` の URL の b番号と `checksum` を一緒に変えます。`checksum` は zip ファイルの SHA-256 です
（`swift package compute-checksum <zip>` または `shasum -a 256 <zip>` で求められます）。

## ライセンス

llama.cpp（ggml を含む）は MIT License です（https://github.com/ggml-org/llama.cpp ）。
このアプリを人に配る場合は、llama.cpp のライセンス表記を含めてください。モデルのライセンスは、それぞれの配布元の条件に従ってください。
