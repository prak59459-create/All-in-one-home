import Foundation

/// URL 欄の下に出す説明の種類。
enum LinkHint: Hashable, Sendable {
    case info(String)
    case warning(String)
    case error(String)
}

/// 「項目を追加」で入力中の Web リンク / URL スキーム（F0068、F0069）。検証は URLPolicy に任せる。
struct LinkDraft: Hashable, Sendable {
    var title: String = ""
    var urlText: String = ""
    var symbolName: String = IconChoices.symbols[0]
    var tint: RGBAColor = IconChoices.colors[0]

    /// 新しく追加する項目の ID。
    static func newItemID() -> String {
        "user.\(UUID().uuidString.lowercased())"
    }

    /// 入力された URL。「:」を含まなければ https:// を補う（例: www.apple.com → https://www.apple.com）。
    var normalizedURL: String {
        let text: String = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(":") else { return text }
        return "https://" + text
    }

    var urlCheck: URLCheckResult {
        URLPolicy.check(normalizedURL)
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 名前の問題。空の時は行き先の名前を使うので問題にしない。
    var titleProblem: String? {
        guard trimmedTitle.count > LayoutLimits.maximumTitleLength else { return nil }
        return "名前は \(LayoutLimits.maximumTitleLength) 文字までです。"
    }

    /// 追加できる項目。入力に問題があれば nil。
    func makeItem(id: String) -> HomeItem? {
        guard titleProblem == nil, case .allowed(let checked) = urlCheck else { return nil }
        let fallback: String = String(checked.destination.prefix(LayoutLimits.maximumTitleLength))
        let name: String = trimmedTitle.isEmpty ? fallback : trimmedTitle
        return HomeItem(id: id, title: name, symbolName: symbolName, tint: tint, action: .openURL(normalizedURL))
    }

    /// URL 欄の下の説明。何も入力していなければ nil。
    var urlHint: LinkHint? {
        guard !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        switch urlCheck {
        case .rejected(let reason):
            return .error(reason.message)
        case .allowed(let checked):
            return LinkDraft.hint(for: checked)
        }
    }

    private static func hint(for checked: CheckedURL) -> LinkHint {
        switch checked.kind {
        case .secureWeb:
            return .info("「\(checked.destination)」を開きます。開く前に確認します。")
        case .insecureWeb:
            return .warning("暗号化されていない http の URL です（\(checked.destination)）。開く前に確認します。")
        case .appScheme:
            return .info("「\(checked.destination)」に対応するアプリで開きます。アプリが入っていない時は開けません。")
        }
    }
}
