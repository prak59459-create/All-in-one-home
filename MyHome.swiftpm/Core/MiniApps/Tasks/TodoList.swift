import Foundation

/// タスクの優先度（F0268）。
enum TodoPriority: Int, CaseIterable, Codable, Comparable, Sendable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3

    var title: String {
        switch self {
        case .none: return "なし"
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }

    static func < (left: TodoPriority, right: TodoPriority) -> Bool {
        left.rawValue < right.rawValue
    }
}

/// タスク1件（F0265–F0268）。
struct TodoItem: Identifiable, Hashable, Codable, Sendable {
    let id: String
    var title: String
    var isDone: Bool
    /// 期限（日付だけ）。
    var due: DayStamp?
    var priority: TodoPriority
    let createdAt: Date
    var completedAt: Date?
}

enum TodoLimits {
    static let maximumCount: Int = 1000
    static let maximumTitleLength: Int = 200
}

enum TodoEditError: Error, Hashable, Sendable {
    case emptyTitle
    case tooMany

    var message: String {
        switch self {
        case .emptyTitle: return "タスクの名前を入力してください。"
        case .tooMany: return "タスクは \(TodoLimits.maximumCount) 件までです。完了したタスクを削除してください。"
        }
    }
}

/// タスクの一覧（Apps/tasks.json）。
struct TodoList: MiniAppContent {
    static let fileID: String = "tasks"
    static let formatVersion: Int = 1
    static let maximumByteCount: Int = 4_000_000
    static let initial: TodoList = TodoList(items: [])

    var items: [TodoItem]

    var problems: [String] {
        var found: [String] = []
        if items.count > TodoLimits.maximumCount {
            found.append("タスクが \(TodoLimits.maximumCount) 件を超えています。")
        }
        if Set(items.map(\.id)).count != items.count {
            found.append("同じ ID のタスクがあります。")
        }
        if items.contains(where: { (item: TodoItem) -> Bool in item.title.count > TodoLimits.maximumTitleLength }) {
            found.append("名前が長すぎるタスクがあります。")
        }
        return found
    }

    static func newID() -> String {
        "task.\(UUID().uuidString.lowercased())"
    }

    func item(id: String) -> TodoItem? {
        items.first { (item: TodoItem) -> Bool in item.id == id }
    }

    /// タスクを作る（F0265）。名前の前後の空白は取り除き、長すぎる分は切り詰める。
    @discardableResult
    mutating func add(title: String, due: DayStamp?, priority: TodoPriority, id: String, now: Date) throws -> TodoItem {
        let cleaned: String = TodoList.clean(title)
        guard !cleaned.isEmpty else { throw TodoEditError.emptyTitle }
        guard items.count < TodoLimits.maximumCount else { throw TodoEditError.tooMany }
        let item = TodoItem(id: id, title: cleaned, isDone: false, due: due, priority: priority, createdAt: now, completedAt: nil)
        items.append(item)
        return item
    }

    /// 完了・未完了を切り替える（F0266）。
    mutating func toggle(id: String, now: Date) {
        guard let index = index(of: id) else { return }
        items[index].isDone.toggle()
        items[index].completedAt = items[index].isDone ? now : nil
    }

    mutating func update(id: String, title: String, due: DayStamp?, priority: TodoPriority) throws {
        guard let index = index(of: id) else { return }
        let cleaned: String = TodoList.clean(title)
        guard !cleaned.isEmpty else { throw TodoEditError.emptyTitle }
        items[index].title = cleaned
        items[index].due = due
        items[index].priority = priority
    }

    mutating func remove(id: String) {
        items.removeAll { (item: TodoItem) -> Bool in item.id == id }
    }

    /// 完了したタスクをまとめて削除し、消した数を返す。
    @discardableResult
    mutating func removeCompleted() -> Int {
        let before: Int = items.count
        items.removeAll { (item: TodoItem) -> Bool in item.isDone }
        return before - items.count
    }

    /// 期限が今日までの未完了のタスクをまとめて完了にする（F0275）。
    @discardableResult
    mutating func completeAll(dueBy today: DayStamp, now: Date) -> Int {
        var count: Int = 0
        for index in items.indices where !items[index].isDone {
            guard let due = items[index].due, due <= today else { continue }
            items[index].isDone = true
            items[index].completedAt = now
            count += 1
        }
        return count
    }

    private func index(of id: String) -> Int? {
        items.firstIndex { (item: TodoItem) -> Bool in item.id == id }
    }

    private static func clean(_ title: String) -> String {
        let trimmed: String = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(TodoLimits.maximumTitleLength))
    }
}
