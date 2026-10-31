extension HomeArchiveError {
    var message: String {
        switch self {
        case .tooLarge(let byteCount):
            return "保存ファイルが大きすぎます（\(byteCount / 1_000_000)MB）。"
        case .malformed(let detail):
            return "保存ファイルの形式が正しくありません（\(detail)）。"
        case .newerVersion(let version):
            return "新しい版のアプリで保存されたデータです（形式の版 \(version)。この版のアプリが読めるのは \(SavedHome.currentSchemaVersion) まで）。"
        case .invalid(let problems):
            let lines: [String] = problems.map { problem in problem.message }
            return "保存データに問題があります。" + lines.joined(separator: " ")
        }
    }
}
