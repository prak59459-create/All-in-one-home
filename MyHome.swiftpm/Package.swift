// swift-tools-version: 5.9

// Swift Playgrounds (iPad) / Xcode 用のアプリマニフェスト。
// Swift Playgrounds の「App設定」を変更すると、このファイルは自動で書き直される場合がある。
// 書き直されても壊れないよう、Playgrounds が生成する標準形だけを使う（外部パッケージ依存なし）。
// Linux での検証ビルドはリポジトリ直下の Package.swift が担当し、このファイルは読まない。

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "MyHome",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "MyHome",
            targets: ["AppModule"],
            bundleIdentifier: "com.example.myhome",
            teamIdentifier: "",
            displayVersion: "0.1",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .clock),
            accentColor: .presetColor(.indigo),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
