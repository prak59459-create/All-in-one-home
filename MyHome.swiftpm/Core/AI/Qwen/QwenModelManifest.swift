/// Qwen のモデルのファイル 1 つ（リポジトリの models/qwen2.5-0.5b-instruct-coreml の中の相対パス）。
struct QwenModelFile: Hashable, Sendable {
    let path: String
    let size: Int
    /// git のブロブのハッシュ（GitHub の tree API の sha と同じ）。
    let blob: String

    /// 取得した後に中身のハッシュまで確かめるか（大きな重みのファイルは、tree API で版を確かめたうえで大きさだけ確かめる。
    /// 純粋な Swift の SHA-1 で数百 MB を計算すると、端末では時間がかかりすぎるため）。
    var verifiesContent: Bool {
        size <= QwenModelManifest.contentCheckLimit
    }
}

/// 取得するファイルの一覧。files は scripts/coreml/make_manifest.py で作る（QwenModelManifest+Files.swift。手で書き換えない）。
/// アプリは、この一覧と GitHub の tree の sha が全部同じ版（ブランチ・コミット）からだけ取得する（版の違うモデルを入れない）。
enum QwenModelManifest {
    static let repositoryFolder: String = "models/qwen2.5-0.5b-instruct-coreml"
    /// Core ML のモデル（.mlpackage）の名前。埋め込み → 層（4 つずつ）→ 出力（語彙の前半・後半）の順に通す。
    static let embeddingPackage: String = "QwenEmbedding"
    static let layerPackages: [String] = (0..<6).map { (number: Int) -> String in "QwenLayers\(number)" }
    static let headPackages: [String] = ["QwenHead0", "QwenHead1"]
    static let packages: [String] = [embeddingPackage] + layerPackages + headPackages
    static let tokenizerFiles: [String] = ["vocab.json", "merges.txt"]
    /// これ以下の大きさのファイルは、中身の SHA-1 も確かめる。
    static let contentCheckLimit: Int = 8_000_000

    static var totalSize: Int {
        files.reduce(0) { (total: Int, file: QwenModelFile) -> Int in total + file.size }
    }

    /// 入れるのに要る空き容量の目安（取得したファイルと、コンパイルしたもの）。
    static var requiredSpace: Int {
        totalSize * 2 + 100_000_000
    }
}
