/// 初回起動時のレイアウト。外部リンクは公開 Web ページと、公開されている URL スキームだけを使う。
/// 型推論の負荷を抑えるため、配列リテラルは要素型を明示して小さく分ける。
enum DefaultLayout {
    static func make() -> HomeLayout {
        HomeLayout(pages: [homePage(), linksPage()], dock: dock())
    }

    static func homePage() -> HomePage {
        let items: [HomeItem] = [
            item(for: .notes),
            item(for: .tasks),
            item(for: .calculator),
            item(for: .unitConverter),
            item(for: .textTools),
            item(for: .timer),
            link("link.swift", "Swift", url: "https://www.swift.org", symbol: "swift", tint: 0xF05138),
            link("link.wikipedia", "Wikipedia", url: "https://ja.wikipedia.org", symbol: "book.closed.fill", tint: 0x4B5563),
            link("link.apple-support", "Apple サポート", url: "https://support.apple.com/ja-jp", symbol: "questionmark.circle.fill", tint: 0x0EA5E9)
        ]
        return HomePage(id: "page.home", items: items, widgets: homeWidgets())
    }

    /// 初めて起動した時のウィジェット（追加フェーズ A: ホーム画面はウィジェットが基本）。時計は画面の上部にあるので入れない。
    /// 小を 1 マス、中を 2 マスとして、横 4 マス（縦向きの iPad）でも 6 マス（横向き）でも、行の途中に隙間ができない順に並べる。
    static func homeWidgets() -> [HomeWidget] {
        let widgets: [HomeWidget] = [
            HomeWidget(id: "widget.weather", kind: .app(.weather), size: .medium),
            HomeWidget(id: "widget.calendar", kind: .calendar, size: .small),
            HomeWidget(id: "widget.tasks", kind: .app(.tasks), size: .small),
            HomeWidget(id: "widget.notes", kind: .app(.notes), size: .medium),
            HomeWidget(id: "widget.ai", kind: .app(.aiAssistant), size: .small),
            HomeWidget(id: "widget.timer", kind: .timer, size: .small),
            HomeWidget(id: "widget.calculator", kind: .app(.calculator), size: .small),
            HomeWidget(id: "widget.converter", kind: .app(.unitConverter), size: .small),
            HomeWidget(id: "widget.texttools", kind: .app(.textTools), size: .small),
            HomeWidget(id: "widget.settings", kind: .app(.settings), size: .small)
        ]
        return widgets
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
            item(for: .settings),
            item(for: .featureStatus),
            item(for: .aiAssistant),
            link("link.shortcuts", "ショートカット", url: "shortcuts://", symbol: "square.stack.3d.up.fill", tint: 0xDB2777)
        ]
        return items
    }

    /// アプリ内の機能の項目。初期配置と「項目を追加」で同じ ID・見た目にする（ID が同じなので二重には追加されない）。
    static func item(for feature: AppFeature) -> HomeItem {
        let style: FeatureIconStyle = FeatureIconStyle.of(feature)
        return HomeItem(
            id: "feature.\(feature.rawValue)",
            title: feature.title,
            symbolName: style.symbol,
            tint: RGBAColor(hex: style.tint),
            action: .feature(feature)
        )
    }

    private static func link(_ id: String, _ title: String, url: String, symbol: String, tint: UInt32) -> HomeItem {
        HomeItem(id: id, title: title, symbolName: symbol, tint: RGBAColor(hex: tint), action: .openURL(url))
    }
}

/// 機能の記号と色（アイコンとアプリのウィジェットで同じものを使う）。
struct FeatureIconStyle: Hashable, Sendable {
    let symbol: String
    let tint: UInt32

    static func of(_ feature: AppFeature) -> FeatureIconStyle {
        switch feature {
        case .settings: return FeatureIconStyle(symbol: "gearshape.fill", tint: 0x6B7280)
        case .featureStatus: return FeatureIconStyle(symbol: "checklist", tint: 0x0D9488)
        case .aiAssistant: return FeatureIconStyle(symbol: "sparkles", tint: 0x7C3AED)
        case .notes: return FeatureIconStyle(symbol: "note.text", tint: 0xF5B700)
        case .tasks: return FeatureIconStyle(symbol: "checkmark.square.fill", tint: 0x2563EB)
        case .calculator: return FeatureIconStyle(symbol: "plus.forwardslash.minus", tint: 0xF97316)
        case .unitConverter: return FeatureIconStyle(symbol: "arrow.left.arrow.right", tint: 0x059669)
        case .textTools: return FeatureIconStyle(symbol: "textformat", tint: 0x0891B2)
        case .timer: return FeatureIconStyle(symbol: "timer", tint: 0xEF4444)
        case .weather: return FeatureIconStyle(symbol: "cloud.sun.fill", tint: 0x0284C7)
        }
    }
}
