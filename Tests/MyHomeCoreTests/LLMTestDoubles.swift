import Foundation
@testable import MyHomeCore

/// 呼び出しの記録。複数のタスクから書き込まれるためロックで守る。
final class CallLog: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [String] = []

    func record(_ entry: String) {
        lock.lock()
        entries.append(entry)
        lock.unlock()
    }

    func count(of entry: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.filter { $0 == entry }.count
    }
}

/// 取り消されるまで終わらない生成を返すモデル。生成が止まったか（onTermination）と解放を記録する。
struct EndlessModel: LoadedLLM {
    let log: CallLog

    func generate(_ request: LLMGenerationRequest) -> AsyncThrowingStream<String, Error> {
        let log: CallLog = self.log
        return AsyncThrowingStream { continuation in
            continuation.yield("…")
            continuation.onTermination = { _ in
                log.record("terminated")
            }
        }
    }

    func unload() async {
        log.record("unload")
    }
}

/// load() の回数を記録するプロバイダー。
struct SpyProvider: LocalLLMProvider {
    let descriptor = LLMModelDescriptor(id: "spy", displayName: "Spy", format: .gguf)
    let log: CallLog

    func load() async throws -> any LoadedLLM {
        log.record("load")
        return EndlessModel(log: log)
    }
}

/// 読み込みに失敗するプロバイダー。
struct FailingProvider: LocalLLMProvider {
    struct LoadError: Error {}

    let descriptor = LLMModelDescriptor(id: "broken", displayName: "Broken", format: .gguf)

    func load() async throws -> any LoadedLLM {
        throw LoadError()
    }
}

/// release() されるまで読み込みが終わらないプロバイダー（読み込み中に画面を離れた場合の確認用）。
final class GatedProvider: LocalLLMProvider, @unchecked Sendable {
    let descriptor = LLMModelDescriptor(id: "gated", displayName: "Gated", format: .gguf)
    let log: CallLog
    private let lock = NSLock()
    private var waiter: CheckedContinuation<Void, Never>?
    private var released: Bool = false

    init(log: CallLog) {
        self.log = log
    }

    func load() async throws -> any LoadedLLM {
        log.record("load-started")
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.lock()
            if released {
                lock.unlock()
                continuation.resume()
            } else {
                waiter = continuation
                lock.unlock()
            }
        }
        return EndlessModel(log: log)
    }

    func release() {
        lock.lock()
        released = true
        let pending: CheckedContinuation<Void, Never>? = waiter
        waiter = nil
        lock.unlock()
        pending?.resume()
    }
}
