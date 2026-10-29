/// 取得したコミットと手元のパッケージを比べた結果（何を書き込み、何を消すか）。
struct UpdatePlan: Hashable, Sendable {
    let snapshot: RemoteSnapshot
    /// 手元にないファイル。
    var additions: [RemoteFile]
    /// 手元と中身が違うファイル（Package.swift を除く）。
    var modifications: [RemoteFile]
    /// 前回の更新で入れた後に、手元で変更されたファイル（書き込むと、その変更は失われる。退避はする）。
    var locallyEdited: Set<String>
    /// 前回の更新で入れたが、新しいコミットにはないファイル（手元で変わっていないものだけ消す）。
    var deletions: [String]
    /// リポジトリにない手元のファイル（更新で入れた記録がないので消さない。ビルドの邪魔になる時は手動で消す）。
    var untracked: [String]
    /// Package.swift が違う時の新しい版。書き込むかは利用者が選ぶ（Swift Playgrounds の「App 設定」の変更が消えるため）。
    var manifestChange: RemoteFile?
    var manifestLocallyEdited: Bool
    var unchangedCount: Int

    var isUpToDate: Bool {
        additions.isEmpty && modifications.isEmpty && deletions.isEmpty && manifestChange == nil
    }
}

/// 比べ方: 手元のファイルの git ブロブのハッシュと、コミットの一覧のハッシュを比べる（同じなら書き込まない）。
/// 「手元で変更された」かは、前回の更新で入れた時のハッシュ（installed）と比べて判断する。
enum UpdatePlanner {
    static let manifestPath: String = "Package.swift"

    /// local: 手元のファイルのパス → ハッシュ。installed: 前回の更新で入れたファイルのパス → ハッシュ（初めてなら nil）。
    static func plan(snapshot: RemoteSnapshot, local: [String: String], installed: [String: String]?) -> UpdatePlan {
        var plan = UpdatePlan(
            snapshot: snapshot, additions: [], modifications: [], locallyEdited: [], deletions: [], untracked: [],
            manifestChange: nil, manifestLocallyEdited: false, unchangedCount: 0
        )
        var remotePaths: Set<String> = []
        for file in snapshot.files where file.path != BuildStampWriter.path {
            remotePaths.insert(file.path)
            classify(file, local: local, installed: installed, into: &plan)
        }
        for path in local.keys.sorted() where !remotePaths.contains(path) && path != BuildStampWriter.path {
            classifyMissing(path, local: local, installed: installed, into: &plan)
        }
        return plan
    }

    private static func classify(_ file: RemoteFile, local: [String: String], installed: [String: String]?, into plan: inout UpdatePlan) {
        guard let localHash = local[file.path] else {
            plan.additions.append(file)
            return
        }
        guard localHash != file.blobSHA else {
            plan.unchangedCount += 1
            return
        }
        let edited: Bool = isLocallyEdited(file.path, localHash: localHash, installed: installed)
        if file.path == manifestPath {
            plan.manifestChange = file
            plan.manifestLocallyEdited = edited
            return
        }
        plan.modifications.append(file)
        if edited {
            plan.locallyEdited.insert(file.path)
        }
    }

    private static func classifyMissing(_ path: String, local: [String: String], installed: [String: String]?, into plan: inout UpdatePlan) {
        guard let installed, let installedHash = installed[path] else {
            plan.untracked.append(path)
            return
        }
        if local[path] == installedHash {
            plan.deletions.append(path)
        } else {
            // 更新で入れた後に手元で変えたファイルは消さない
            plan.untracked.append(path)
        }
    }

    /// 前回の記録がなければ、手元で変えたかどうかは分からないので「変えていない」とみなす（上書き前に退避はする）。
    private static func isLocallyEdited(_ path: String, localHash: String, installed: [String: String]?) -> Bool {
        guard let installed, let installedHash = installed[path] else { return false }
        return installedHash != localHash
    }
}
