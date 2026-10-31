import Foundation

/// 選んだフォルダが、このアプリのパッケージ（MyHome.swiftpm）かを確かめる。どれか1つでも合わなければ書き込まない。
/// 1. フォルダ名が .swiftpm で終わる  2. Package.swift が Swift Playgrounds のアプリの形（.iOSApplication）
/// 3. Core/PackageIdentity.swift に、このアプリと同じ識別子がある
enum PackageVerifier {
    static func verify(folderName: String, package: PackageFileSystem) throws {
        guard folderName.hasSuffix(".swiftpm") else {
            throw UpdateError.wrongPackage("フォルダ名が .swiftpm で終わっていません: \(folderName)")
        }
        guard let manifest = try? package.read(UpdatePlanner.manifestPath),
              String(decoding: manifest, as: UTF8.self).contains(".iOSApplication(") else {
            throw UpdateError.wrongPackage("Package.swift が Swift Playgrounds のアプリの形ではありません")
        }
        guard let marker = try? package.read(PackageIdentity.markerPath),
              String(decoding: marker, as: UTF8.self).contains(PackageIdentity.id) else {
            throw UpdateError.wrongPackage("\(PackageIdentity.markerPath) の識別子が一致しません（別のアプリか、更新機能のない古い版です）")
        }
    }
}
