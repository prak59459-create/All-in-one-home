/// ウィジェットの追加・削除・並べ替え・大きさと内容の変更（F0162–F0165、F0189）。
extension HomeLayout {
    func widget(id: String) -> HomeWidget? {
        for page in pages {
            if let widget = page.widgets.first(where: { (widget: HomeWidget) -> Bool in widget.id == id }) {
                return widget
            }
        }
        return nil
    }

    /// ウィジェットのあるページの番号と、ページの中の位置。
    func widgetLocation(id: String) -> (page: Int, index: Int)? {
        for (pageIndex, page) in pages.enumerated() {
            if let index = page.widgets.firstIndex(where: { (widget: HomeWidget) -> Bool in widget.id == id }) {
                return (pageIndex, index)
            }
        }
        return nil
    }

    mutating func addWidget(_ widget: HomeWidget, toPage pageIndex: Int) throws {
        guard pages.indices.contains(pageIndex) else { throw LayoutEditError.pageNotFound }
        guard self.widget(id: widget.id) == nil, location(ofItem: widget.id) == nil else { throw LayoutEditError.duplicateID }
        guard pages[pageIndex].widgets.count < WidgetLimits.maximumPerPage else { throw LayoutEditError.widgetLimitReached }
        pages[pageIndex].widgets.append(HomeLayout.sanitized(widget))
    }

    /// ウィジェット型のホーム画面のおすすめ（初めて起動した時と同じ組み合わせ。追加フェーズ A）のうち、
    /// まだどのページにもない種類を、上限まで足す。足した数を返す。
    @discardableResult
    mutating func addRecommendedWidgets(toPage pageIndex: Int, makeID: () -> String) throws -> Int {
        guard pages.indices.contains(pageIndex) else { throw LayoutEditError.pageNotFound }
        var added: Int = 0
        for template in DefaultLayout.homeWidgets() {
            guard pages[pageIndex].widgets.count < WidgetLimits.maximumPerPage else { break }
            if hasWidget(of: template.kind) {
                continue
            }
            try addWidget(HomeWidget(id: makeID(), kind: template.kind, size: template.size), toPage: pageIndex)
            added += 1
        }
        return added
    }

    /// その種類のウィジェットが、どこかのページにあるか（メモは中身が違っても同じ種類とみなす）。
    func hasWidget(of kind: WidgetKind) -> Bool {
        pages.contains { (page: HomePage) -> Bool in
            page.widgets.contains { (widget: HomeWidget) -> Bool in HomeLayout.sameKind(widget.kind, kind) }
        }
    }

    /// アプリのウィジェットが 1 つでもあるか（ウィジェット型のホーム画面で、おすすめを出すかの判断）。
    var hasAppWidgets: Bool {
        pages.contains { (page: HomePage) -> Bool in
            page.widgets.contains { (widget: HomeWidget) -> Bool in widget.kind.feature != nil }
        }
    }

    private static func sameKind(_ left: WidgetKind, _ right: WidgetKind) -> Bool {
        switch (left, right) {
        case (.clock, .clock), (.calendar, .calendar), (.note, .note), (.timer, .timer):
            return true
        case (.app(let a), .app(let b)):
            return a == b
        default:
            return false
        }
    }

    mutating func removeWidget(id: String) throws {
        guard let found = widgetLocation(id: id) else { throw LayoutEditError.itemNotFound }
        pages[found.page].widgets.remove(at: found.index)
    }

    /// ページの中で offset だけ前後に動かす（端で止める）。
    mutating func moveWidget(id: String, by offset: Int) throws {
        guard let found = widgetLocation(id: id) else { throw LayoutEditError.itemNotFound }
        var widgets: [HomeWidget] = pages[found.page].widgets
        let destination: Int = min(max(found.index + offset, 0), widgets.count - 1)
        guard destination != found.index else { return }
        let moving: HomeWidget = widgets.remove(at: found.index)
        widgets.insert(moving, at: destination)
        pages[found.page].widgets = widgets
    }

    mutating func updateWidget(id: String, kind: WidgetKind, size: WidgetSize) throws {
        guard let found = widgetLocation(id: id) else { throw LayoutEditError.itemNotFound }
        let current: HomeWidget = pages[found.page].widgets[found.index]
        pages[found.page].widgets[found.index] = HomeLayout.sanitized(HomeWidget(id: current.id, kind: kind, size: size))
    }

    /// メモの長さを上限に収める。
    static func sanitized(_ widget: HomeWidget) -> HomeWidget {
        guard case .note(let text) = widget.kind, text.count > WidgetLimits.maximumNoteLength else { return widget }
        let trimmed: String = String(text.prefix(WidgetLimits.maximumNoteLength))
        return HomeWidget(id: widget.id, kind: .note(trimmed), size: widget.size)
    }

    /// 項目（フォルダの中を含む）が参照している画像ファイル名。
    var referencedImageNames: Set<String> {
        var names: Set<String> = []
        let topLevel: [HomeItem] = pages.flatMap { (page: HomePage) -> [HomeItem] in page.items } + dock
        for item in topLevel {
            if let name = item.imageName {
                names.insert(name)
            }
            for child in item.folderItems ?? [] {
                if let name = child.imageName {
                    names.insert(name)
                }
            }
        }
        return names
    }
}
