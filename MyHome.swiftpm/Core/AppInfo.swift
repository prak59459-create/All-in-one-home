// Core/ 配下は SwiftUI・UIKit に依存しない層。
// リポジトリ直下の Package.swift から Linux でもビルド・テストされるため、
// ここで SwiftUI / UIKit を import するとビルドが失敗する（層の分離をビルドで強制する）。

/// アプリ全体で共有する識別情報。
enum AppInfo {
    static let displayName: String = "My Home"
    static let version: String = "0.1"
}
