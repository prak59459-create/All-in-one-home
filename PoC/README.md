# llama.cpp PoC（LlamaPoC.swiftpm）

MyHome とは別の、小さな試作アプリです。iPad の Swift Playgrounds で作ったアプリから llama.cpp（GGUF 形式のモデルを動かすライブラリ）を使えるかを確かめます。
MyHome 本体はこのアプリを使いません（MyHome の AI は Phase 6 で Apple の端末内モデル（Foundation Models）を使うようにしました）。

## 今のところの結論

**iPad の Swift Playgrounds で llama.cpp を使うのは、難しい見込みです。** iPad で試すと確定できます（下の「iPad での確認」）。

- **CI で分かったこと（Xcode 16.4 と 26.3）**: llama.cpp 公式の XCFramework（b11998）は、取得（checksum の照合）とコンパイル・リンクまではできました。
  ただし、**できたアプリに `llama.framework` が入っていませんでした**（アプリの中に Frameworks フォルダがない）。
  この XCFramework は動的ライブラリなので、アプリに入っていないと、iPad で起動した時にライブラリが見つからずに落ちる可能性が高いです。
  Swift Playgrounds の形（.swiftpm）のアプリには、「このライブラリをアプリに入れる」と指定する場所がありません。
- **公開されている報告**（どれも少し古く、今の版で変わった可能性はあります）:
  - iPad の Swift Playgrounds 4 では、ビルド済みのバイナリ（binaryTarget）を含むパッケージを読み込めなかった
    （2022 年 1 月、[Apple Developer Forums](https://developer.apple.com/forums/thread/698119)。返信なし）。
  - iPad の Swift Playgrounds は Swift のターゲットだけに対応し、C / C++ / Objective-C のターゲットは使えない
    （2021 年 12 月、[Swift Forums](https://forums.swift.org/t/adding-packages-in-swift-playgrounds-4/54173/2)）。
    2024 年 3 月にも、Swift Playgrounds 4.4.1（iPadOS 17.4）で「target type, "ClangTarget", is not supported」という報告がある
    （[vapor/mysql-nio#107](https://github.com/vapor/mysql-nio/issues/107)）。
  - llama.cpp は C / C++ で書かれているので、ソースからビルドする方法も、iPad の Swift Playgrounds では使えない見込みです。

## CI で確かめていること・いないこと

- 確かめている: Xcode 16.4（iOS 18 SDK）と Xcode 26.3（iOS 26 SDK）で、iPad 実機向け（`generic/platform=iOS`、署名なし）にコンパイルし、
  llama.framework をリンクできること。アプリに llama.framework が入っているかは、結果として記録する（入っていなければ警告を出す）。
  設定は `.github/workflows/poc-llama.yml`。
- 確かめていない: 実際に動くかどうか。llama.cpp の配布物には iOS Simulator 用が入っていないため Simulator では起動できず、CI には iPad もありません。
  Swift Playgrounds での動作も CI では分かりません。

## iPad での確認（5 分ほど。任意）

1. iPad の Safari で GitHub のこのリポジトリを開き、ブランチを `claude/llama-cpp-poc` に切り替えて「Code」→「Download ZIP」。
2. ファイル App で zip を展開し、`PoC/LlamaPoC.swiftpm` を Swift Playgrounds で開く。
   最初の1回は llama.cpp の XCFramework（約 70MB）をダウンロードするので、インターネットにつないでおく。
3. （A・B を通った場合だけ）GGUF 形式の小さなモデルを、ファイル App の「このiPad内」に置く（iCloud Drive にあると、ダウンロードされていなくて読めないことがあります）。
   まずは 1B 以下の指示調整済み（Instruct）モデルを Q4_K_M などで量子化した、1GB 未満のファイルから試してください。
   例: Qwen2.5-0.5B-Instruct の GGUF（Apache-2.0）。モデルごとにライセンスが違うので、使う前に配布元のページで確認してください。
4. アプリを実行し、「GGUF ファイルを選ぶ」→ 読み込みが終わったら「生成する」。

Swift Playgrounds の「App設定」は変えないでください。変えると Package.swift が書き直され、llama.cpp の指定が消えることがあります。

| 段階 | 予想 | うまくいった時 |
|---|---|---|
| A. パッケージの取得とビルド | 報告どおりなら、ここで止まる（パッケージを解決できない） | エラーなしで実行できる |
| B. 起動 | A を通っても、llama.framework がアプリに入らず、起動直後に落ちる見込み | 画面が出る |
| C. モデルの読み込み | A・B を通った場合だけ確かめられる | 「読み込みました」と時間が出る |
| D. 生成 | 同上 | 日本語の答えとトークン/秒が出る |

どの段階で止まったか、出たエラーの文（またはスクリーンショット）、iPad の機種・iPadOS の版・Swift Playgrounds の版を教えてください。
最後まで動いた場合は、使ったモデルのファイル名と大きさ・読み込み時間・トークン/秒もお願いします。

## 続けるとしたら（次の手の候補）

- **llama.cpp を静的ライブラリとしてビルドし、XCFramework にしてパッケージに入れる。** 静的ライブラリはアプリ本体に組み込まれるので、
  「アプリに入らない」問題は起きません。ただし、iPad の Swift Playgrounds がビルド済みのバイナリを読めない（段階 A で止まる）なら、これも使えません。
  A を通るかを先に確かめます。
- **通常の Xcode プロジェクト（.xcodeproj）にする。** 「アプリに入れる」設定ができるので動かせる見込みですが、Mac の Xcode が必要になり、
  iPad だけで作るという前提から外れます。

## この PoC の範囲

- 1問1答だけ。前の質問は覚えていません（毎回消します）。コンテキストは 2,048 トークン。
- 生成中にアプリを裏に回すと、iPadOS は裏での GPU の利用を許さないため、失敗することがあります。生成中は前に出しておいてください。
- モデルのファイルはアプリにコピーせず、選んだ場所から直接読みます（大きなファイルを二重に持たないため）。読み込んでいる間はそのファイルを動かさないでください。
- MyHome には組み込みません（外部のバイナリに依存し、ダウンロードとビルドの時間も増えるため。上の結論のとおり、Swift Playgrounds では動かない見込みでもある）。

## llama.cpp の版を上げる時

`Package.swift` の URL の b番号と `checksum` を一緒に変えます。`checksum` は zip ファイルの SHA-256 です
（`swift package compute-checksum <zip>` または `shasum -a 256 <zip>` で求められます）。

## ライセンス

llama.cpp（ggml を含む）は MIT License です（https://github.com/ggml-org/llama.cpp ）。
このアプリを人に配る場合は、llama.cpp のライセンス表記を含めてください。モデルのライセンスは、それぞれの配布元の条件に従ってください。
