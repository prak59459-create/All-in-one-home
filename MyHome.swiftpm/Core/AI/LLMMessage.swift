import Foundation

/// AI 画面の会話の1件。
struct LLMMessage: Identifiable, Hashable, Sendable {
    enum Role: Hashable, Sendable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    var text: String
    /// スタブが返した文か（画面で「スタブ」と表示する）。
    let isStub: Bool

    init(role: Role, text: String, isStub: Bool) {
        self.id = UUID()
        self.role = role
        self.text = text
        self.isStub = isStub
    }
}
