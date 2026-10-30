// swift-tools-version: 5.9

// llama.cpp を Swift Playgrounds のアプリから使えるかを確かめる PoC（本体の MyHome.swiftpm とは別のアプリ）。
// llama.cpp は公式リリースの XCFramework（ビルド済みのバイナリ）を使う。ソースからのビルド（C/C++）は試さない。
// 確かめたいこと: (1) Swift Playgrounds が binaryTarget を解決してビルドできるか (2) iPad で GGUF のモデルを読み込んで生成できるか。
// 版を上げる時は、URL の b番号と checksum（zip の SHA-256。`swift package compute-checksum` の値）を一緒に変える。

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "LlamaPoC",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "LlamaPoC",
            targets: ["AppModule"],
            bundleIdentifier: "com.example.llamapoc",
            teamIdentifier: "",
            displayVersion: "0.1",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .clock),
            accentColor: .presetColor(.orange),
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
            dependencies: ["llama"],
            path: "."
        ),
        .binaryTarget(
            name: "llama",
            url: "https://github.com/ggml-org/llama.cpp/releases/download/b11998/llama-b11998-xcframework.zip",
            checksum: "48ae11bfd9681126e993ee6b69af57ca8986e4341071d266fe8a09d16da472b8"
        )
    ]
)
