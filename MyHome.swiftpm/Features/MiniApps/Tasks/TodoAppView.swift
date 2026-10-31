import SwiftUI

/// タスク（F0265–F0276）。期限で「期限切れ・今日・これから・期限なし・完了」に分けて表示する。
@MainActor
struct TodoAppView: View {
    @Environment(MiniAppLibrary.self) private var library

    var body: some View {
        let document: MiniAppDocument<TodoList> = library.document(TodoList.self)
        MiniAppScaffold(title: "タスク") {
            MiniAppHost(document: document) {
                TodoListView(document: document)
            }
        }
    }
}

@MainActor
struct TodoListView: View {
    let document: MiniAppDocument<TodoList>
    @State private var query: String = ""
    @State private var editing: TodoItem?
    @State private var failure: String?
    @State private var isConfirmingCleanup: Bool = false

    var body: some View {
        let today: DayStamp = DayStamp(Date(), calendar: .current)
        List {
            Section {
                NewTodoRow(document: document, today: today) { (message: String) in
                    failure = message
                }
            }
            TodoGroupsContent(
                groups: document.content.groups(today: today, query: query),
                today: today,
                onToggle: toggle,
                onEdit: { (item: TodoItem) in editing = item },
                onRemove: remove
            )
        }
        .searchable(text: $query, prompt: "タスクを検索")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                TodoBulkMenu(document: document, today: today) {
                    isConfirmingCleanup = true
                }
            }
        }
        .sheet(item: $editing) { (item: TodoItem) in
            TodoEditorView(document: document, item: item)
        }
        .confirmationDialog("完了したタスクを削除しますか？", isPresented: $isConfirmingCleanup, titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                document.update { (list: inout TodoList) in
                    _ = list.removeCompleted()
                }
            }
        } message: {
            Text("削除したタスクは元に戻せません。")
        }
        .alert("タスク", isPresented: isShowingFailure) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
    }

    private var isShowingFailure: Binding<Bool> {
        Binding<Bool>(
            get: { failure != nil },
            set: { (isShown: Bool) in
                if !isShown {
                    failure = nil
                }
            }
        )
    }

    private func toggle(_ item: TodoItem) {
        document.update { (list: inout TodoList) in
            list.toggle(id: item.id, now: Date())
        }
    }

    private func remove(_ item: TodoItem) {
        document.update { (list: inout TodoList) in
            list.remove(id: item.id)
        }
    }
}

@MainActor
struct TodoGroupsContent: View {
    let groups: [TodoGroup]
    let today: DayStamp
    let onToggle: @MainActor (TodoItem) -> Void
    let onEdit: @MainActor (TodoItem) -> Void
    let onRemove: @MainActor (TodoItem) -> Void

    var body: some View {
        if groups.isEmpty {
            Text("タスクはありません。")
                .foregroundStyle(.secondary)
        }
        ForEach(groups) { (group: TodoGroup) in
            Section {
                ForEach(group.items) { (item: TodoItem) in
                    TodoRow(item: item, today: today, onToggle: { onToggle(item) }, onEdit: { onEdit(item) })
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("削除", role: .destructive) {
                                onRemove(item)
                            }
                        }
                }
            } header: {
                Text("\(group.section.title)（\(group.items.count)）")
            }
        }
    }
}

/// まとめての操作（F0275）。
@MainActor
struct TodoBulkMenu: View {
    let document: MiniAppDocument<TodoList>
    let today: DayStamp
    let onCleanup: @MainActor () -> Void

    var body: some View {
        Menu {
            Button("今日までのタスクをすべて完了", systemImage: "checkmark.circle") {
                document.update { (list: inout TodoList) in
                    _ = list.completeAll(dueBy: today, now: Date())
                }
            }
            Button("完了したタスクを削除…", systemImage: "trash", role: .destructive) {
                onCleanup()
            }
            .disabled(!document.content.items.contains { (item: TodoItem) -> Bool in item.isDone })
        } label: {
            Label("まとめて操作", systemImage: "ellipsis.circle")
        }
    }
}
