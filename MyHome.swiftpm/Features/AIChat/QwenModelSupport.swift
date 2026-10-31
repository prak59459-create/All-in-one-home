import Foundation
#if canImport(CoreML)
import CoreML
#endif

/// Core ML の Qwen（追加フェーズ A）をアプリから使うための部品: 置き場所、取得、コンパイル、使えるかの判定。
/// モデルは .swiftpm に入れず、AI の画面から 1 回だけ取得する（QwenModelInstaller。ビルドを速く保つため）。
@MainActor
enum QwenModelSupport {
    static let displayName: String = "Qwen2.5 0.5B（Core ML）"

    /// Application Support/MyHome/Models/qwen2.5-0.5b-instruct-coreml。保存先を用意できなければ nil。
    static var directory: URL? {
        guard let base = try? FileHomeArchiveStorage.standard().directory else { return nil }
        return base.appendingPathComponent("Models/qwen2.5-0.5b-instruct-coreml", isDirectory: true)
    }

    static var isInstalled: Bool {
        guard let directory else { return false }
        return QwenModelInstaller.isInstalled(at: directory, manifest: QwenModelManifest.files)
    }

    /// このビルド・この端末で動かせるか（モデルを入れたかは見ない）。動かせない時は理由。
    static var unsupportedReason: String? {
        #if canImport(CoreML) && compiler(>=6.0)
        if #available(iOS 18.0, *) {
            return nil
        }
        return "iPadOS 18 以降が必要です。"
        #else
        return "このビルドでは使えません（iOS 18 SDK 以降の Swift Playgrounds・Xcode でビルドしてください）。"
        #endif
    }

    static func availability() -> LLMAvailability {
        if let reason = unsupportedReason {
            return .unavailable(reason)
        }
        if !isInstalled {
            return .unavailable("モデルをまだ入れていません。下の「モデルを入れる」で取得してください（約 \(sizeText)）。")
        }
        return .available
    }

    static func makeProvider() -> (any LocalLLMProvider)? {
        #if canImport(CoreML) && compiler(>=6.0)
        guard #available(iOS 18.0, *), let directory, isInstalled else { return nil }
        return QwenCoreMLProvider(directory: directory)
        #else
        return nil
        #endif
    }

    static func makeInstaller() -> QwenModelInstaller? {
        guard let directory else { return nil }
        return QwenModelInstaller(
            directory: directory,
            transport: URLSessionTransport(),
            downloader: URLSessionQwenDownloader(),
            compiler: { (source: URL) async throws -> URL in try await QwenModelSupport.compile(source) }
        )
    }

    static var sizeText: String {
        BackupFormat.size(QwenModelManifest.totalSize)
    }

    /// 端末の上で .mlpackage をコンパイルする（数十秒かかることがある）。
    nonisolated static func compile(_ source: URL) async throws -> URL {
        #if canImport(CoreML)
        return try await MLModel.compileModel(at: source)
        #else
        throw QwenModelInstallError.badResponse
        #endif
    }

    /// 取得に要る空きがあるか。分からない時は true（取得の途中で失敗したら、その時に説明する）。
    static func hasEnoughSpace() -> Bool {
        guard let directory,
              let values = try? directory.deletingLastPathComponent().deletingLastPathComponent()
                .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let available = values.volumeAvailableCapacityForImportantUsage else {
            return true
        }
        return available >= Int64(QwenModelManifest.requiredSpace)
    }
}

/// URLSession で大きなファイルを取得する（一時ファイルに書いてから移す）。
struct URLSessionQwenDownloader: QwenFileDownloader {
    func download(_ url: URL, to destination: URL) async throws -> Int {
        var request = URLRequest(url: url)
        request.setValue("MyHome-AIModel", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 120
        let temporary: URL
        let response: URLResponse
        do {
            (temporary, response) = try await URLSession.shared.download(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .dataNotAllowed:
                throw QwenModelInstallError.offline
            case .timedOut:
                throw QwenModelInstallError.timedOut
            case .cancelled:
                throw CancellationError()
            default:
                throw error
            }
        }
        let status: Int = (response as? HTTPURLResponse)?.statusCode ?? 0
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard status == 200 else { return status }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporary, to: destination)
        return status
    }
}
