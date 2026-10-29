// swift-tools-version: 5.9

// 検証専用パッケージ。Swift Playgrounds では使わない（iPad では MyHome.swiftpm を開く）。
// MyHome.swiftpm/Core（SwiftUI・UIKit に依存しない層）を Linux / macOS でビルドし、単体テストを実行する。
// Core に SwiftUI を import すると Linux ビルドが失敗するため、層の分離をビルドで強制できる。

import PackageDescription

let package = Package(
    name: "MyHomeVerification",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "MyHomeCore", targets: ["MyHomeCore"])
    ],
    targets: [
        .target(
            name: "MyHomeCore",
            path: "MyHome.swiftpm/Core"
        ),
        .testTarget(
            name: "MyHomeCoreTests",
            dependencies: ["MyHomeCore"],
            path: "Tests/MyHomeCoreTests"
        )
    ]
)
