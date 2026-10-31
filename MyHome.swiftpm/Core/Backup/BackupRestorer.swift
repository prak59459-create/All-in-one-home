import Foundation

/// 復元する部分（F0828 部分復元、F0829 全体復元）。バックアップに入っていない部分は、今のまま残す。
enum BackupPart: Hashable, Sendable {
    /// ホーム画面の配置・設定・タイマーと、それが使っている画像。
    case home
    /// ミニアプリ 1 つ（fileID）。
    case miniApp(String)
}

extension BackupContents {
    /// バックアップに入っている部分（全体を復元する時に戻すもの）。
    var allParts: Set<BackupPart> {
        var parts: Set<BackupPart> = [.home]
        for entry in miniApps {
            parts.insert(.miniApp(entry.fileID))
        }
        return parts
    }
}

/// ファイルの書き換え 1 つ。data が nil なら消す。
struct BackupFileChange: Hashable, Sendable {
    let path: String
    let data: Data?
}

/// 復元・消去で、保存先のファイルを書き換える。途中で失敗したら、書き換えたファイルを元に戻す。
enum BackupRestorer {
    /// 復元で書き換えるファイル。画像 → ミニアプリ → ホーム画面の順にし、ホーム画面を最後に書く。
    /// current は今の保存先（天気の通信の同意など、今の端末の状態を引き継ぐために読む）。
    static func changes(for contents: BackupContents, parts: Set<BackupPart>, current: any PackageFileSystem) throws -> [BackupFileChange] {
        var changes: [BackupFileChange] = []
        if parts.contains(.home) {
            for name in contents.images.keys.sorted() {
                changes.append(BackupFileChange(path: BackupPaths.image(name), data: contents.images[name]))
            }
        }
        for entry in contents.miniApps where parts.contains(.miniApp(entry.fileID)) {
            guard let kind = MiniAppDataCatalog.kind(path: entry.path) else { continue }
            let existing: Data? = current.exists(entry.path) ? try? current.read(entry.path) : nil
            let data: Data = try kind.prepareForRestore(entry.data, existing)
            changes.append(BackupFileChange(path: entry.path, data: data))
        }
        if parts.contains(.home) {
            var home: SavedHome = contents.home
            // 動いていたタイマーは止めて戻す（戻した直後に「終わりました」が続けて出ないように）
            home.timers = home.timers.stoppedForRestore()
            changes.append(BackupFileChange(path: BackupPaths.home, data: try HomeArchiveCodec.encode(home)))
        }
        return changes
    }

    /// すべてのデータを消す時に消すファイル（F0839、F0868）。ホーム画面・ミニアプリのデータ・画像と、読めずに退避したファイル。
    /// 端末内のバックアップ（Backups）とアップデートの記録は消さない。
    static func eraseChanges(in files: any PackageFileSystem) throws -> [BackupFileChange] {
        let paths: [String] = try files.listFiles().filter(isUserData)
        return paths.map { (path: String) -> BackupFileChange in BackupFileChange(path: path, data: nil) }
    }

    static func isUserData(_ path: String) -> Bool {
        if path.hasPrefix("Apps/") || path.hasPrefix(BackupPaths.imagesFolder + "/") {
            return true
        }
        // home.json と、読めずに退避した home.unreadable-….json
        return !path.contains("/") && path.hasPrefix("home") && path.hasSuffix(".json")
    }

    /// 書き換える。途中で失敗したら、それまでに書き換えたファイルを元に戻してから BackupError.writeFailed を投げる。
    static func apply(_ changes: [BackupFileChange], to files: any PackageFileSystem) throws {
        let previous: [BackupFileChange]
        do {
            previous = try changes.map { (change: BackupFileChange) -> BackupFileChange in
                let data: Data? = files.exists(change.path) ? try files.read(change.path) : nil
                return BackupFileChange(path: change.path, data: data)
            }
        } catch {
            // まだ何も書き換えていない
            throw BackupError.writeFailed(error.localizedDescription, rolledBack: true)
        }
        // 失敗した書き換え自体は戻さない（一時ファイルに書いてから置き換えるので、失敗したファイルは元のまま）
        var completed: Int = 0
        do {
            for change in changes {
                try perform(change, on: files)
                completed += 1
            }
        } catch {
            let restored: Bool = rollBack(previous.prefix(completed), on: files)
            throw BackupError.writeFailed(error.localizedDescription, rolledBack: restored)
        }
    }

    private static func rollBack(_ previous: ArraySlice<BackupFileChange>, on files: any PackageFileSystem) -> Bool {
        var restored: Bool = true
        for change in previous.reversed() {
            do {
                try perform(change, on: files)
            } catch {
                restored = false
            }
        }
        return restored
    }

    private static func perform(_ change: BackupFileChange, on files: any PackageFileSystem) throws {
        if let data = change.data {
            try files.write(data, to: change.path)
        } else {
            try files.delete(change.path)
        }
    }
}

extension TimerBoard {
    /// 復元した時のタイマー: カウントダウンは最初の時間に戻し、ストップウォッチは 0 に戻す（ラベルと時間の設定は残す）。
    func stoppedForRestore() -> TimerBoard {
        var board: TimerBoard = self
        for index in board.countdowns.indices {
            board.countdowns[index].reset()
        }
        board.stopwatch.reset()
        return board
    }
}
