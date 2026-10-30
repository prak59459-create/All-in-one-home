/// ミニアプリのデータ（F0489、F0498）。1つのミニアプリにつき1ファイル（Application Support/MyHome/Apps/<fileID>.json）に保存し、
/// ホーム画面の保存ファイルとは分ける。あるミニアプリのファイルが壊れても、ホーム画面や他のミニアプリには影響しない。
protocol MiniAppContent: Codable, Hashable, Sendable {
    /// ファイル名の元（"notes" → Apps/notes.json）。英小文字・数字・"-" だけを使う。
    static var fileID: String { get }
    /// 形式の版。これより新しい版のファイルは読まずに退避する（新しい版のアプリのデータを上書きしないため）。
    static var formatVersion: Int { get }
    /// 読み書きするファイルの大きさの上限（バイト）。
    static var maximumByteCount: Int { get }
    /// ファイルがない時の内容。
    static var initial: Self { get }
    /// 読んだ内容の問題（ID の重複、上限を超えた値など）。空なら問題なし。
    var problems: [String] { get }
}
