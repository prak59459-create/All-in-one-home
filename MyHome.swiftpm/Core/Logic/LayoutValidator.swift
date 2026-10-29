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
        return Array(problems.prefix(maximumReportedProblems))
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
        let pageItems: [HomeItem] = layout.pages.flatMap { page in page.items }
        for item in pageItems + layout.dock {
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
        if case .openURL(let url) = item.action, url.count > LayoutLimits.maximumURLLength {
            return true
        }
        return false
    }
}
