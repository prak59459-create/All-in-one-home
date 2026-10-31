import Foundation
import Observation

/// 配置と設定の保存（F0834–F0838）。変更から少し待ってまとめて保存し（間引き）、
/// アプリが裏に回る時は待たずに保存する。保存中も操作は止めない。
@MainActor
@Observable
final class PersistenceController {
    enum Status: Hashable, Sendable {
        /// 保存しない（検証用の起動引数など）。理由を表示する。
        case disabled(String)
        /// 保存待ちの変更はない。
        case saved
        /// 保存待ち、または保存中。
        case pending
        /// 保存に失敗した。次の変更か、やり直しの操作でもう一度試す。
        case failed(String)
    }

    private(set) var status: Status
    /// 最後に保存できた時刻（この起動中）。
    private(set) var lastSavedAt: Date?

    @ObservationIgnored private let writer: HomeArchiveWriter?
    @ObservationIgnored private let delay: Duration
    @ObservationIgnored private var scheduled: Task<Void, Never>?
    /// 変更のたびに増やす番号と、保存できた番号。2つが同じなら保存待ちの変更はない。
    @ObservationIgnored private var revision: Int = 0
    @ObservationIgnored private var savedRevision: Int = 0
    @ObservationIgnored private var snapshot: (@MainActor () -> SavedHome)?
    /// 保存をやめたか（復元・消去でファイルを書き換える時）。やめた後は二度と保存しない。
    @ObservationIgnored private(set) var isSuspended: Bool = false

    /// storage が nil なら保存しない。
    init(storage: (any HomeArchiveStorage)?, disabledReason: String = "", delay: Duration = .milliseconds(500)) {
        if let storage {
            writer = HomeArchiveWriter(storage: storage)
            status = .saved
        } else {
            writer = nil
            status = .disabled(disabledReason)
        }
        self.delay = delay
    }

    /// 保存する内容の取り出し方を登録し、ストアの変更を受け取る。
    func attach(home: HomeStore, settings: SettingsStore, timers: TimerStore) {
        snapshot = {
            SavedHome(layout: home.layout, settings: settings.saved, timers: timers.board)
        }
        home.onChange = { [weak self] in
            self?.scheduleSave()
        }
        settings.onChange = { [weak self] in
            self?.scheduleSave()
        }
        timers.onChange = { [weak self] in
            self?.scheduleSave()
        }
    }

    /// 変更があった時に呼ぶ。delay の間に続いた変更は、まとめて1回で保存する。
    func scheduleSave() {
        guard writer != nil, !isSuspended else { return }
        revision += 1
        status = .pending
        scheduled?.cancel()
        let delay: Duration = self.delay
        scheduled = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.save()
        }
    }

    /// 保存待ちの変更があればすぐ保存する（アプリが裏に回る時、やり直しの操作）。
    func flush() async {
        guard writer != nil, !isSuspended, revision != savedRevision else { return }
        scheduled?.cancel()
        scheduled = nil
        await save()
    }

    /// 保存をやめる。復元・消去でファイルを書き換える前に、flush の後で呼ぶ（書き換えた後に、古い内容で上書きしないため）。
    /// この後の変更は保存しない（この PersistenceController は、読み直した新しいものに置き換わる）。
    func suspend(reason: String) {
        isSuspended = true
        scheduled?.cancel()
        scheduled = nil
        status = .disabled(reason)
    }

    private func save() async {
        guard let writer, let snapshot, !isSuspended else { return }
        let target: Int = revision
        let saved: SavedHome = snapshot()
        do {
            try await writer.write(saved, revision: target)
            savedRevision = max(savedRevision, target)
            lastSavedAt = Date()
            if savedRevision == revision {
                status = .saved
            }
        } catch {
            // 書いている間に次の変更があれば、その保存の結果に任せる
            if target == revision {
                status = .failed(PersistenceController.failureMessage(for: error))
            }
        }
    }

    static func failureMessage(for error: Error) -> String {
        "変更を保存できませんでした。端末の空き容量を確認してください。（\(error.localizedDescription)）"
    }
}
