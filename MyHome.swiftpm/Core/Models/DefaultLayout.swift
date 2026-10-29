/// 初回起動時のレイアウト。外部リンクは公開 Web ページと、公開されている URL スキームだけを使う。
/// 型推論の負荷を抑えるため、配列リテラルは要素型を明示して小さく分ける。
enum DefaultLayout {
    static func make() -> HomeLayout {
        HomeLayout(pages: [homePage(), linksPage()], dock: dock())
    }

    static func homePage() -> HomePage {
        let items: [HomeItem] = [
            feature(.notes, symbol: "note.text", tint: 0xF5B700),
            feature(.calculator, symbol: "plus.forwardslash.minus", tint: 0xF97316),
            feature(.timer, symbol: "timer", tint: 0xEF4444),
            link("link.swift", "Swift", url: "https://www.swift.org", symbol: "swift", tint: 0xF05138),
            link("link.wikipedia", "Wikipedia", url: "https://ja.wikipedia.org", symbol: "book.closed.fill", tint: 0x4B5563),
            link("link.apple-support", "Apple サポート", url: "https://support.apple.com/ja-jp", symbol: "questionmark.circle.fill", tint: 0x0EA5E9)
        ]
        return HomePage(id: "page.home", items: items)
    }

    static func linksPage() -> HomePage {
        let items: [HomeItem] = [
            link("link.swiftui-docs", "SwiftUI 資料", url: "https://developer.apple.com/documentation/swiftui", symbol: "doc.text.fill", tint: 0x2563EB),
            link("link.github", "GitHub", url: "https://github.com", symbol: "chevron.left.forwardslash.chevron.right", tint: 0x24292F),
            link("link.swift-forums", "Swift Forums", url: "https://forums.swift.org", symbol: "bubble.left.and.bubble.right.fill", tint: 0xEA580C)
        ]
        return HomePage(id: "page.links", items: items)
    }

    static func dock() -> [HomeItem] {
        let items: [HomeItem] = [
            feature(.settings, symbol: "gearshape.fill", tint: 0x6B7280),
            feature(.featureStatus, symbol: "checklist", tint: 0x0D9488),
            feature(.aiAssistant, symbol: "sparkles", tint: 0x7C3AED),
            link("link.shortcuts", "ショートカット", url: "shortcuts://", symbol: "square.stack.3d.up.fill", tint: 0xDB2777)
        ]
        return items
    }

    private static func feature(_ feature: AppFeature, symbol: String, tint: UInt32) -> HomeItem {
        HomeItem(
            id: "feature.\(feature.rawValue)",
            title: feature.title,
            symbolName: symbol,
            tint: RGBAColor(hex: tint),
            action: .feature(feature)
        )
    }

    private static func link(_ id: String, _ title: String, url: String, symbol: String, tint: UInt32) -> HomeItem {
        HomeItem(id: id, title: title, symbolName: symbol, tint: RGBAColor(hex: tint), action: .openURL(url))
    }
}
