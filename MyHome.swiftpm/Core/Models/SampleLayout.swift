/// 大量の項目で表示が破綻しないかを確かめる検証用レイアウト。起動引数で指定した時だけ使う（LaunchOptions）。
enum SampleLayout {
    /// 一度に作る項目数の上限（検証用でもメモリを使いすぎないようにする）。
    static let maximumItemCount: Int = 2000

    static func stress(itemCount: Int, itemsPerPage: Int) -> HomeLayout {
        let count: Int = min(max(itemCount, 0), maximumItemCount)
        let perPage: Int = max(itemsPerPage, 1)
        var pages: [HomePage] = []
        var current: [HomeItem] = []
        for index in 0..<count {
            current.append(sampleItem(index: index))
            if current.count == perPage {
                pages.append(page(number: pages.count + 1, items: current))
                current = []
            }
        }
        if !current.isEmpty {
            pages.append(page(number: pages.count + 1, items: current))
        }
        return HomeLayout(pages: pages, dock: DefaultLayout.dock()).normalized()
    }

    private static let tints: [UInt32] = [0x2563EB, 0x16A34A, 0xDC2626, 0x9333EA, 0xEA580C, 0x0891B2]

    private static func page(number: Int, items: [HomeItem]) -> HomePage {
        HomePage(id: "sample.page.\(number)", items: items)
    }

    private static func sampleItem(index: Int) -> HomeItem {
        let number: Int = index + 1
        let tint: UInt32 = tints[index % tints.count]
        return HomeItem(
            id: "sample.\(number)",
            title: "項目 \(number)",
            symbolName: "square.grid.2x2.fill",
            tint: RGBAColor(hex: tint),
            action: .openURL("https://example.com/\(number)")
        )
    }
}
