/// Core/BuildStamp.swift の中身を作る。コミットとブランチの文字は、Swift の文字列として安全な文字だけにする。
enum BuildStampWriter {
    static let path: String = "Core/BuildStamp.swift"

    static func source(commit: String, branch: String) -> String {
        """
        /// ソフトウェアアップデートで書き込んだコミット。アップデートの時にこのファイルだけは、取得したコミットの値で書き直す。
        /// リポジトリの中では空のまま（空なら、アップデート機能で入れた版ではない）。起動時に、書き込んだ記録と比べて
        /// 「新しい版でビルドし直されたか」を確かめる。
        enum BuildStamp {
            static let commit: String = "\(sanitized(commit))"
            static let branch: String = "\(sanitized(branch))"
        }

        """
    }

    static func sanitized(_ text: String) -> String {
        let allowed: Set<Character> = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._/-")
        let cleaned: String = String(text.map { (character: Character) -> Character in allowed.contains(character) ? character : "_" })
        return String(cleaned.prefix(200))
    }
}
