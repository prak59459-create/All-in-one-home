import SwiftUI

/// ウィジェットの一覧（ギャラリー。F0161）。選ぶと、編集を始めたページの上部に追加する（F0162）。
@MainActor
struct AddWidgetList: View {
    let pageIndex: Int
    let onDone: @MainActor () -> Void
    @Environment(HomeStore.self) private var store
    @State private var failure: String?

    var body: some View {
        Section {
            ForEach(WidgetKind.galleryKinds.indices, id: \.self) { index in
                AddWidgetRow(kind: WidgetKind.galleryKinds[index]) {
                    add(WidgetKind.galleryKinds[index])
                }
            }
            if let failure {
                Text(failure).foregroundStyle(.red)
            }
        } header: {
            Text("ウィジェット")
        } footer: {
            Text("MyHome の中のウィジェットです（iPadOS のホーム画面には置けません）。1ページに \(WidgetLimits.maximumPerPage) 個まで。")
        }
    }

    private func add(_ kind: WidgetKind) {
        let widget = HomeWidget(id: "widget.\(UUID().uuidString.lowercased())", kind: kind, size: .small)
        do {
            try store.addWidget(widget, toPage: pageIndex)
            onDone()
        } catch let error as LayoutEditError {
            failure = error.message
        } catch {
            failure = "追加できませんでした。"
        }
    }
}

@MainActor
struct AddWidgetRow: View {
    let kind: WidgetKind
    let onAdd: @MainActor () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Label(kind.title, systemImage: kind.symbolName)
            Spacer()
            Button("追加") {
                onAdd()
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("\(kind.title)を追加")
        }
    }
}
