import Foundation

/// タスクの一覧の区切り（F0271、F0272）。
enum TodoSection: String, CaseIterable, Sendable {
    case overdue
    case today
    case upcoming
    case someday
    case done

    var title: String {
        switch self {
        case .overdue: return "期限切れ"
        case .today: return "今日"
        case .upcoming: return "これから"
        case .someday: return "期限なし"
        case .done: return "完了"
        }
    }
}

struct TodoGroup: Identifiable, Hashable, Sendable {
    let section: TodoSection
    let items: [TodoItem]

    var id: String { section.rawValue }
}

extension TodoList {
    /// 区切りごとのタスク（空の区切りは含めない）。query があれば名前で絞り込む（F0273）。
    /// 期限のあるものは期限の近い順、同じなら優先度の高い順（F0270）。完了は新しく完了した順。
    func groups(today: DayStamp, query: String = "") -> [TodoGroup] {
        let terms: [String] = TextSearch.terms(in: query)
        let matched: [TodoItem] = items.filter { (item: TodoItem) -> Bool in
            terms.isEmpty || TextSearch.matches(terms, in: [item.title])
        }
        var buckets: [TodoSection: [TodoItem]] = [:]
        for item in matched {
            buckets[TodoList.section(of: item, today: today), default: []].append(item)
        }
        return TodoSection.allCases.compactMap { (section: TodoSection) -> TodoGroup? in
            guard let bucket = buckets[section], !bucket.isEmpty else { return nil }
            return TodoGroup(section: section, items: TodoList.sorted(bucket, in: section))
        }
    }

    /// 期限切れの未完了のタスクの数（F0271）。
    func overdueCount(today: DayStamp) -> Int {
        items.filter { (item: TodoItem) -> Bool in TodoList.section(of: item, today: today) == .overdue }.count
    }

    var pendingCount: Int {
        items.filter { (item: TodoItem) -> Bool in !item.isDone }.count
    }

    static func section(of item: TodoItem, today: DayStamp) -> TodoSection {
        if item.isDone {
            return .done
        }
        guard let due = item.due else { return .someday }
        if due < today {
            return .overdue
        }
        return due == today ? .today : .upcoming
    }

    private static func sorted(_ items: [TodoItem], in section: TodoSection) -> [TodoItem] {
        items.sorted { (left: TodoItem, right: TodoItem) -> Bool in
            if section == .done {
                let leftDone: Date = left.completedAt ?? left.createdAt
                let rightDone: Date = right.completedAt ?? right.createdAt
                if leftDone != rightDone {
                    return leftDone > rightDone
                }
                return left.id < right.id
            }
            if let leftDue = left.due, let rightDue = right.due, leftDue != rightDue {
                return leftDue < rightDue
            }
            if left.priority != right.priority {
                return left.priority > right.priority
            }
            if left.createdAt != right.createdAt {
                return left.createdAt < right.createdAt
            }
            return left.id < right.id
        }
    }
}
