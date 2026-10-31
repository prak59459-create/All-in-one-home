import Foundation
import Observation

/// ミニアプリ1つ分のデータと、その保存（F0489）。初めて開いた時にメインスレッドの外で読み込み、
/// 変更から少し待ってまとめて保存する（ホーム画面の PersistenceController と同じ規則）。
/// アプリが裏に回る時は MiniAppLibrary.flushAll から待たずに保存する。
@MainActor
@Observable
final class MiniAppDocument<Content: MiniAppContent> {
    private(set) var content: Content = Content.initial
    /// 読み込みが終わったか。終わるまでは変更を受け付けない（読み込んだ内容で上書きされて、変更が消えるため）。
    private(set) var isLoaded: Bool = false
    private(set) var status: PersistenceController.Status
    /// 読み込めなかった時の説明。画面で一度表示したら nil にする。
    var notice: String?

    @ObservationIgnored private let storage: (any HomeArchiveStorage)?
    @ObservationIgnored private var writer: MiniAppArchiveWriter<Content>?
    @ObservationIgnored private let delay: Duration
    @ObservationIgnored private var loading: Task<Void, Never>?
    @ObservationIgnored private var scheduled: Task<Void, Never>?
    /// 変更のたびに増やす番号と、保存できた番号。2つが同じなら保存待ちの変更はない。
    @ObservationIgnored private var revision: Int = 0
    @ObservationIgnored private var savedRevision: Int = 0
    /// 保存をやめたか（復元・消去でファイルを書き換える時）。やめた後は二度と保存しない。
    @ObservationIgnored private(set) var isSuspended: Bool = false

    /// storage が nil なら保存しない（検証用の起動など）。
    init(storage: (any HomeArchiveStorage)?, disabledReason: String = "", delay: Duration = .milliseconds(500)) {
        self.storage = storage
        self.delay = delay
        status = storage == nil ? .disabled(disabledReason) : .saved
    }

    /// 読み込む（2回目からは何もしない）。読み込み中に呼ばれたら、終わるまで待つ。
    func load() async {
        if isLoaded {
            return
        }
        if let loading {
            await loading.value
            return
        }
        guard let storage else {
            isLoaded = true
            return
        }
        let task: Task<Void, Never> = Task { [weak self] in
            let outcome: MiniAppLoadOutcome<Content> = await Task.detached(priority: .userInitiated) {
                MiniAppArchiveLoader.load(Content.self, from: storage)
            }.value
            self?.finishLoading(outcome, storage: storage)
        }
        loading = task
        await task.value
    }

    /// 内容を変える。変わらなければ保存しない。読み込みの前は何もしない。
    func update(_ change: (inout Content) -> Void) {
        guard isLoaded else { return }
        var next: Content = content
        change(&next)
        commit(next)
    }

    /// 上限などで失敗することがある変更。失敗したら内容は変えない。
    func perform(_ change: (inout Content) throws -> Void) throws {
        guard isLoaded else { return }
        var next: Content = content
        try change(&next)
        commit(next)
    }

    /// 保存待ちの変更があればすぐ保存する（アプリが裏に回る時、アプリを終える時）。
    func flush() async {
        guard writer != nil, !isSuspended, revision != savedRevision else { return }
        scheduled?.cancel()
        scheduled = nil
        await save()
    }

    /// 保存をやめる（PersistenceController.suspend と同じ）。読み込み中なら、読み込んだ後も保存しない。
    func suspend(reason: String) {
        isSuspended = true
        scheduled?.cancel()
        scheduled = nil
        status = .disabled(reason)
    }

    private func finishLoading(_ outcome: MiniAppLoadOutcome<Content>, storage: any HomeArchiveStorage) {
        content = outcome.content
        notice = outcome.notice
        if isSuspended {
            // 読み込み中に保存をやめた時は、書く手段を作らない（status は suspend で設定済み）
        } else if outcome.canSave {
            writer = MiniAppArchiveWriter<Content>(storage: storage)
        } else {
            status = .disabled("読めなかったファイルを上書きしないよう、変更は保存しません。")
        }
        isLoaded = true
        loading = nil
    }

    private func commit(_ next: Content) {
        guard next != content else { return }
        content = next
        scheduleSave()
    }

    private func scheduleSave() {
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

    private func save() async {
        guard let writer, !isSuspended else { return }
        let target: Int = revision
        let snapshot: Content = content
        do {
            try await writer.write(snapshot, revision: target)
            savedRevision = max(savedRevision, target)
            if savedRevision == revision {
                status = .saved
            }
        } catch let error as MiniAppArchiveError {
            if target == revision {
                status = .failed("保存できませんでした。" + error.message)
            }
        } catch {
            // 書いている間に次の変更があれば、その保存の結果に任せる
            if target == revision {
                status = .failed(PersistenceController.failureMessage(for: error))
            }
        }
    }
}

/// アプリが裏に回る時に、開いたことのあるミニアプリをまとめて保存する（復元の前は保存をやめる）ための共通の窓口。
@MainActor
protocol MiniAppFlushing: AnyObject {
    func flush() async
    func suspend(reason: String)
}

extension MiniAppDocument: MiniAppFlushing {}
