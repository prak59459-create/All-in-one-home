import SwiftUI

/// タスクの編集（名前・期限・優先度・削除）。「保存」を押すまで変更しない。
@MainActor
struct TodoEditorView: View {
    let document: MiniAppDocument<TodoList>
    let item: TodoItem
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var hasDue: Bool = false
    @State private var dueDate: Date = Date()
    @State private var priority: TodoPriority = .none
    @State private var isLoaded: Bool = false
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名前", text: $title)
                }
                Section {
                    Toggle("期限", isOn: $hasDue)
                    if hasDue {
                        DatePicker("日付", selection: $dueDate, displayedComponents: .date)
                    }
                }
                Section("優先度") {
                    Picker("優先度", selection: $priority) {
                        ForEach(TodoPriority.allCases, id: \.self) { (value: TodoPriority) in
                            Text(value.title).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Button("削除", role: .destructive) {
                        remove()
                    }
                }
                if let failure {
                    Text(failure)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("タスク")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                }
            }
            .onAppear {
                load()
            }
        }
    }

    private func load() {
        guard !isLoaded else { return }
        title = item.title
        priority = item.priority
        if let due = item.due, let date = due.date(in: .current) {
            hasDue = true
            dueDate = date
        }
        isLoaded = true
    }

    private func save() {
        let id: String = item.id
        let newTitle: String = title
        let newPriority: TodoPriority = priority
        let due: DayStamp? = hasDue ? DayStamp(dueDate, calendar: .current) : nil
        do {
            try document.perform { (list: inout TodoList) in
                try list.update(id: id, title: newTitle, due: due, priority: newPriority)
            }
            dismiss()
        } catch let error as TodoEditError {
            failure = error.message
        } catch {
            failure = "保存できませんでした。"
        }
    }

    private func remove() {
        let id: String = item.id
        document.update { (list: inout TodoList) in
            list.remove(id: id)
        }
        dismiss()
    }
}
