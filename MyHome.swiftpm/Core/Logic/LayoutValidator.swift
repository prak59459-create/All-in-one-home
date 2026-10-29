/// 読み込んだ配置の構造の問題。
enum LayoutProblem: Hashable, Sendable {
    case tooManyItems(Int)
    case tooManyPages(Int)
    case invalidPageID(String)
    case duplicatePageID(String)
    case invalidItemID(String)
    case duplicateItemID(String)
    /// 名前・記号名・URL のどれかが長すぎる。
    case textTooLong(itemID: String)
    /// フォルダの中にフォルダがある（階層は1段まで。F0156、F0157）。
    case nestedFolder(itemID: String)
    /// ウィジェットの ID が不正・重複、またはメモが長すぎる・1ページの数が多すぎる。
    case invalidWidget(String)
}

/// 読み込んだ配置の構造を確かめる（F0821、F0824）。
/// URL の中身はここでは判定せず、開く時に URLPolicy で判定する。URLPolicy を将来厳しくしても、
/// 保存済みの配置全体が読めなくなることを避けるため（長さだけはメモリを守るためにここで確かめる）。
enum LayoutValidator {
    /// 一度に報告する問題の数の上限（壊れたファイルで説明が長くなりすぎないようにする）。
    static let maximumReportedProblems: Int = 10

    static func problems(in layout: HomeLayout) -> [LayoutProblem] {
        var problems: [LayoutProblem] = []
        let itemCount: Int = layout.itemCount
        if itemCount > LayoutLimits.maximumItems {
            problems.append(.tooManyItems(itemCount))
        }
        if layout.pages.count > LayoutLimits.maximumPages {
            problems.append(.tooManyPages(layout.pages.count))
        }
        problems.append(contentsOf: pageProblems(in: layout.pages))
        problems.append(contentsOf: itemProblems(in: layout))
        problems.append(contentsOf: widgetProblems(in: layout))
        return Array(problems.prefix(maximumReportedProblems))
    }

    private static func widgetProblems(in layout: HomeLayout) -> [LayoutProblem] {
        var problems: [LayoutProblem] = []
        var seen: Set<String> = []
        for page in layout.pages {
            if page.widgets.count > WidgetLimits.maximumPerPage {
                problems.append(.invalidWidget(page.id))
            }
            for widget in page.widgets {
                let duplicate: Bool = !seen.insert(widget.id).inserted || layout.location(ofItem: widget.id) != nil
                if !isValidID(widget.id) || duplicate || hasTooLongNote(widget) {
                    problems.append(.invalidWidget(widget.id))
                }
            }
        }
        return problems
    }

    private static func hasTooLongNote(_ widget: HomeWidget) -> Bool {
        if case .note(let text) = widget.kind {
            return text.count > WidgetLimits.maximumNoteLength
        }
        return false
    }

    private static func pageProblems(in pages: [HomePage]) -> [LayoutProblem] {
        var problems: [LayoutProblem] = []
        var seen: Set<String> = []
        for page in pages {
            if !isValidID(page.id) {
                problems.append(.invalidPageID(page.id))
            } else if !seen.insert(page.id).inserted {
                problems.append(.duplicatePageID(page.id))
            }
        }
        return problems
    }

    private static func itemProblems(in layout: HomeLayout) -> [LayoutProblem] {
        var problems: [LayoutProblem] = []
        var seen: Set<String> = []
        let pageItems: [HomeItem] = layout.pages.flatMap { (page: HomePage) -> [HomeItem] in page.items }
        let topLevel: [HomeItem] = pageItems + layout.dock
        problems.append(contentsOf: nestingProblems(in: topLevel))
        for item in flattened(topLevel) {
            if !isValidID(item.id) {
                problems.append(.invalidItemID(item.id))
            } else if !seen.insert(item.id).inserted {
                problems.append(.duplicateItemID(item.id))
            }
            if hasTooLongText(item) {
                problems.append(.textTooLong(itemID: item.id))
            }
            if problems.count >= maximumReportedProblems {
                break
            }
        }
        return problems
    }

    /// フォルダの中身も含めた一覧（ID の重複はフォルダの内外をまたいで調べる）。
    private static func flattened(_ items: [HomeItem]) -> [HomeItem] {
        var result: [HomeItem] = []
        for item in items {
            result.append(item)
            result.append(contentsOf: item.folderItems ?? [])
        }
        return result
    }

    private static func nestingProblems(in topLevel: [HomeItem]) -> [LayoutProblem] {
        var problems: [LayoutProblem] = []
        for folder in topLevel {
            for child in folder.folderItems ?? [] where child.isFolder {
                problems.append(.nestedFolder(itemID: child.id))
            }
        }
        return problems
    }

    private static func isValidID(_ id: String) -> Bool {
        !id.isEmpty && id.count <= LayoutLimits.maximumIDLength
    }

    private static func hasTooLongText(_ item: HomeItem) -> Bool {
        if item.title.count > LayoutLimits.maximumTitleLength {
            return true
        }
        if item.symbolName.count > LayoutLimits.maximumSymbolNameLength {
            return true
        }
        if let imageName = item.imageName, imageName.count > LayoutLimits.maximumIDLength {
            return true
        }
        if case .openURL(let url) = item.action, url.count > LayoutLimits.maximumURLLength {
            return true
        }
        return false
    }
}
