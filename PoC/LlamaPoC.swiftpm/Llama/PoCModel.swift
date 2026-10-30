import Foundation
import Observation
import os

/// 画面の状態。llama.cpp の呼び出しはメインスレッドの外で行い、結果だけをメインスレッドに戻す。
@MainActor
@Observable
final class PoCModel {
    enum Phase: Equatable {
        case empty
        case loading
        case ready
        case generating
    }

    private(set) var phase: Phase = .empty
    private(set) var modelName: String = ""
    private(set) var status: String = "GGUF 形式のモデルファイルを選んでください。"
    private(set) var output: String = ""
    private(set) var report: String = ""
    @ObservationIgnored private var runner: LlamaRunner?
    @ObservationIgnored private var accessedURL: URL?
    private let stopFlag: StopFlag = StopFlag()

    /// アプリがあとどれだけメモリを使えるか（iOS が決める上限までの残り）。モデルの大きさの目安にする。
    var memoryText: String {
        let available: Int = os_proc_available_memory()
        let physical: UInt64 = ProcessInfo.processInfo.physicalMemory
        return "このアプリが使えるメモリ: 約 \(gigabytes(Int64(available)))（端末のメモリ \(gigabytes(Int64(physical)))）"
    }

    func load(url: URL) {
        guard phase != .loading && phase != .generating else { return }
        unload()
        // Files で選んだファイルは、使っている間だけ読む権限を開いておく（llama.cpp はファイルを mmap で読み続ける）
        let isScoped: Bool = url.startAccessingSecurityScopedResource()
        if let problem = PoCModel.ggufProblem(at: url) {
            if isScoped {
                url.stopAccessingSecurityScopedResource()
            }
            status = problem
            return
        }
        accessedURL = isScoped ? url : nil
        modelName = url.lastPathComponent
        phase = .loading
        status = "読み込み中…"
        output = ""
        report = ""
        let path: String = url.path
        let size: Int64 = PoCModel.fileSize(at: url)
        Task {
            let started: Date = Date()
            let result: Result<LlamaRunner, Error> = await Task.detached(priority: .userInitiated) {
                Result { try LlamaRunner(modelPath: path) }
            }.value
            finishLoading(result, seconds: Date().timeIntervalSince(started), size: size)
        }
    }

    func generate(prompt: String, maxTokens: Int) {
        guard phase == .ready, let runner else { return }
        let text: String = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        phase = .generating
        status = "生成中…"
        output = ""
        report = ""
        stopFlag.reset()
        let flag: StopFlag = stopFlag
        Task {
            let result: Result<LlamaRunner.Stats, Error> = await Task.detached(priority: .userInitiated) {
                Result {
                    try runner.generate(prompt: text, maxTokens: maxTokens) { (piece: String) -> Bool in
                        self.post(piece)
                        return !flag.isSet
                    }
                }
            }.value
            // post は DispatchQueue.main に順番に積むので、それが全部終わってから結果を出す
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.finishGenerating(result)
                }
            }
        }
    }

    func stop() {
        stopFlag.set()
    }

    func unload() {
        guard phase != .loading && phase != .generating else { return }
        runner = nil
        accessedURL?.stopAccessingSecurityScopedResource()
        accessedURL = nil
        modelName = ""
        phase = .empty
        status = "GGUF 形式のモデルファイルを選んでください。"
    }

    /// 生成された文字を、メインスレッドで順番どおりに足す。
    nonisolated private func post(_ piece: String) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                self.output += piece
            }
        }
    }

    private func finishLoading(_ result: Result<LlamaRunner, Error>, seconds: Double, size: Int64) {
        switch result {
        case .success(let loaded):
            runner = loaded
            phase = .ready
            status = "読み込みました。"
            report = String(format: "読み込み %.1f 秒（ファイル %@）", seconds, gigabytes(size))
        case .failure(let error):
            accessedURL?.stopAccessingSecurityScopedResource()
            accessedURL = nil
            modelName = ""
            phase = .empty
            status = PoCModel.message(for: error)
        }
    }

    private func finishGenerating(_ result: Result<LlamaRunner.Stats, Error>) {
        phase = .ready
        switch result {
        case .success(let stats):
            status = stopFlag.isSet ? "止めました。" : "完了しました。"
            report = String(
                format: "プロンプト %d トークン（%.2f 秒）／生成 %d トークン（%.2f 秒、%.1f トークン/秒）",
                stats.promptTokens,
                stats.promptSeconds,
                stats.generatedTokens,
                stats.generationSeconds,
                stats.tokensPerSecond
            )
        case .failure(let error):
            status = PoCModel.message(for: error)
        }
    }

    private func gigabytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .memory)
    }

    private static func message(for error: Error) -> String {
        if let runnerError = error as? LlamaRunner.RunnerError {
            return runnerError.description
        }
        return "失敗しました: \(error.localizedDescription)"
    }

    /// GGUF のファイルは先頭が "GGUF" の4バイト。違うファイルを llama.cpp に渡す前に断る。
    private static func ggufProblem(at url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return "ファイルを開けませんでした。iCloud Drive にある場合は、先にダウンロードしてから選んでください。"
        }
        defer { try? handle.close() }
        guard let head = try? handle.read(upToCount: 4), head == Data("GGUF".utf8) else {
            return "GGUF 形式のファイルではありません。"
        }
        return nil
    }

    private static func fileSize(at url: URL) -> Int64 {
        let values: URLResourceValues? = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }
}

/// 生成を止める合図。生成のスレッドから読み、メインスレッドから立てる。
final class StopFlag: @unchecked Sendable {
    private let lock: NSLock = NSLock()
    private var value: Bool = false

    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set() {
        lock.lock()
        value = true
        lock.unlock()
    }

    func reset() {
        lock.lock()
        value = false
        lock.unlock()
    }
}
