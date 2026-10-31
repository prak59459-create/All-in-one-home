import SwiftUI

/// タスクの1行。左の丸で完了を切り替え、名前をタップすると編集する。
@MainActor
struct TodoRow: View {
    let item: TodoItem
    let today: DayStamp
    let onToggle: @MainActor () -> Void
    let onEdit: @MainActor () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Button {
                onToggle()
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isDone ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(toggleLabel)
            Button {
                onEdit()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .strikethrough(item.isDone)
                        .foregroundStyle(item.isDone ? Color.secondary : Color.primary)
                    TodoDetailText(item: item, today: today)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("編集します")
        }
    }

    private var toggleLabel: String {
        let action: String = item.isDone ? "未完了に戻す" : "完了にする"
        return "「\(item.title)」を" + action
    }
}

/// 期限と優先度。期限切れは赤で示し、文字でも「期限切れ」と書く（色だけに頼らない。F0980）。
@MainActor
struct TodoDetailText: View {
    let item: TodoItem
    let today: DayStamp

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            if let due = item.due {
                Label(dueText(due), systemImage: "calendar")
                    .foregroundStyle(isOverdue(due) ? Color.red : Color.secondary)
            }
            if item.priority != .none {
                Text("優先度 \(item.priority.title)")
                    .foregroundStyle(item.priority == .high ? Color.orange : Color.secondary)
            }
        }
        .font(.caption)
    }

    private func isOverdue(_ due: DayStamp) -> Bool {
        !item.isDone && due < today
    }

    private func dueText(_ due: DayStamp) -> String {
        let calendar: Calendar = .current
        let name: String = due.relativeName(today: today, calendar: calendar)
            ?? due.date(in: calendar).map { (date: Date) -> String in date.formatted(dateStyle(for: due)) }
            ?? due.text
        return isOverdue(due) ? "期限切れ・\(name)" : name
    }

    /// 今年でない期限は年も出す（Simulator の確認で、2020 年の期限が「1月1日」とだけ表示されて紛らわしかった）。
    private func dateStyle(for due: DayStamp) -> Date.FormatStyle {
        let sameYear: Date.FormatStyle = Date.FormatStyle.dateTime.month().day().weekday(.abbreviated)
        return due.year == today.year ? sameYear : sameYear.year()
    }
}

/// 新しいタスクの入力欄。期限はよく使うものから選ぶ（細かい日付は編集画面で）。
@MainActor
struct NewTodoRow: View {
    enum DueChoice: String, CaseIterable, Identifiable {
        case none = "期限なし"
        case today = "今日"
        case tomorrow = "明日"
        case nextWeek = "1週間後"

        var id: String { rawValue }

        func day(from today: DayStamp) -> DayStamp? {
            switch self {
            case .none: return nil
            case .today: return today
            case .tomorrow: return today.adding(days: 1, calendar: .current)
            case .nextWeek: return today.adding(days: 7, calendar: .current)
            }
        }
    }

    let document: MiniAppDocument<TodoList>
    let today: DayStamp
    let onFailure: @MainActor (String) -> Void
    @State private var title: String = ""
    @State private var dueChoice: DueChoice = .none
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            TextField("新しいタスク", text: $title)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit {
                    add()
                }
            Picker("期限", selection: $dueChoice) {
                ForEach(DueChoice.allCases) { (choice: DueChoice) in
                    Text(choice.rawValue).tag(choice)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
            Button("追加") {
                add()
            }
            .buttonStyle(.borderedProminent)
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func add() {
        let text: String = title
        let due: DayStamp? = dueChoice.day(from: today)
        do {
            try document.perform { (list: inout TodoList) in
                try list.add(title: text, due: due, priority: .none, id: TodoList.newID(), now: Date())
            }
            title = ""
            isFocused = true
        } catch let error as TodoEditError {
            onFailure(error.message)
        } catch {
            onFailure("追加できませんでした。")
        }
    }
}
