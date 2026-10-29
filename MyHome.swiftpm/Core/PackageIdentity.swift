/// この Swift Playgrounds パッケージ（MyHome.swiftpm）の識別子。ソフトウェアアップデートで、
/// 利用者が選んだフォルダが本当にこのアプリのパッケージかを確かめるために使う（別のフォルダやコピーに書き込まない）。
/// このファイルの中身は変えない（変えると、古い版からの更新で書き込み先と認められなくなる）。
enum PackageIdentity {
    /// 選んだフォルダの Core/PackageIdentity.swift にこの文字列があれば、このアプリのパッケージとみなす。
    static let id: String = "myhome-swiftpm-7f3c2a1e-package-identity"
    static let markerPath: String = "Core/PackageIdentity.swift"
    static let repositoryOwner: String = "prak59459-create"
    static let repositoryName: String = "All-in-one-home"
    /// リポジトリの中のパッケージの場所。
    static let packagePathInRepository: String = "MyHome.swiftpm"
}
