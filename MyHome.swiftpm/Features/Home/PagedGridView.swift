import SwiftUI

/// 横スワイプで切り替えるページ（F0002、F0008）。ページ番号は PageIndicatorView と共有する（F0009）。
@MainActor
struct PagedGridView: View {
    let pages: [HomePage]
    @Binding var selection: Int

    var body: some View {
        TabView(selection: $selection) {
            ForEach(pages.indices, id: \.self) { index in
                HomePageGridView(page: pages[index], pageIndex: index)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}
