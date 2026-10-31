/// 取得するコミットの CI の結果（iOS Simulator 向けのビルドと起動テスト）。
/// 成功していないコミットを書き込むと、Swift Playgrounds でビルドできず、アプリから「元に戻す」も使えなくなることがある。
enum CommitCheckStatus: Hashable, Sendable {
    /// アプリのビルドと起動テストがすべて成功した。
    case passed
    /// まだ実行中か、順番待ち。
    case pending
    /// 失敗したものがある。
    case failed
    /// 結果が見つからない（CI を通っていないコミット）。
    case unknown

    /// CI のアプリのジョブ名（.github/workflows/ci.yml の app-ios）の先頭。
    static let appJobPrefix: String = "App / iOS Simulator"

    static func evaluate(_ runs: [CheckRunSummary]) -> CommitCheckStatus {
        let app: [CheckRunSummary] = runs.filter { (run: CheckRunSummary) -> Bool in run.name.hasPrefix(appJobPrefix) }
        guard !app.isEmpty else { return .unknown }
        if app.contains(where: { (run: CheckRunSummary) -> Bool in run.status == "completed" && run.conclusion != "success" }) {
            return .failed
        }
        if app.contains(where: { (run: CheckRunSummary) -> Bool in run.status != "completed" }) {
            return .pending
        }
        return .passed
    }

    var message: String {
        switch self {
        case .passed:
            return "CI でビルドと起動テストに成功したコミットです（iOS 18 SDK・iOS 26 SDK）。"
        case .pending:
            return "CI がまだ終わっていないコミットです。終わってから書き込むことをおすすめします。"
        case .failed:
            return "CI でビルドか起動テストに失敗したコミットです。書き込むと Swift Playgrounds でビルドできない可能性があります。"
        case .unknown:
            return "CI の結果がないコミットです。ビルドできるか確かめられていません。"
        }
    }
}

struct CheckRunSummary: Hashable, Sendable, Decodable {
    let name: String
    let status: String
    let conclusion: String?
}
