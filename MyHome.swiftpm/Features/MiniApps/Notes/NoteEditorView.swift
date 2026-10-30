import SwiftUI

/// メモを書く画面（F0322、F0324、F0326、F0327、F0333–F0335）。打つたびに保存を予約し、まとめて保存する。
/// 何も書かずに戻った新しいメモは残さない（F0357）。
@MainActor
struct NoteEditorView: View {
    let document: MiniAppDocument<NoteBook>
    let noteID: String
    @State private var title: String = ""
    @State private var text: String = ""
    @State private var isLoaded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            TextField("タイトル", text: $title)
                .font(.title3.weight(.semibold))
                .padding(.horizontal, DesignTokens.Spacing.medium)
                .padding(.vertical, DesignTokens.Spacing.small)
            Divider()
            TextEditor(text: $text)
                .padding(.horizontal, DesignTokens.Spacing.small)
                .accessibilityLabel("本文")
            NoteEditorFooter(note: document.content.note(id: noteID), characterCount: text.count)
        }
        .navigationTitle("メモ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    togglePin()
                } label: {
                    Label(isPinned ? "ピンを外す" : "ピン留め", systemImage: isPinned ? "pin.slash" : "pin")
                }
            }
        }
        .onAppear {
            load()
        }
        .onChange(of: title) { _, newValue in
            if newValue.count > NoteLimits.maximumTitleLength {
                title = String(newValue.prefix(NoteLimits.maximumTitleLength))
            }
            save()
        }
        .onChange(of: text) { _, newValue in
            if newValue.count > NoteLimits.maximumBodyLength {
                text = String(newValue.prefix(NoteLimits.maximumBodyLength))
            }
            save()
        }
        .onDisappear {
            let id: String = noteID
            document.update { (book: inout NoteBook) in
                book.removeIfEmpty(id: id)
            }
        }
    }

    private var isPinned: Bool {
        document.content.note(id: noteID)?.isPinned ?? false
    }

    private func load() {
        guard !isLoaded, let note = document.content.note(id: noteID) else { return }
        title = note.title
        text = note.body
        isLoaded = true
    }

    private func save() {
        guard isLoaded else { return }
        let id: String = noteID
        let newTitle: String = title
        let newBody: String = text
        document.update { (book: inout NoteBook) in
            book.updateNote(id: id, title: newTitle, body: newBody, now: Date())
        }
    }

    private func togglePin() {
        let id: String = noteID
        let pinned: Bool = !isPinned
        document.update { (book: inout NoteBook) in
            book.setPinned(id: id, pinned)
        }
    }
}

/// 文字数と、作成・更新の日時。
@MainActor
struct NoteEditorFooter: View {
    let note: Note?
    let characterCount: Int

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Text("\(characterCount) / \(NoteLimits.maximumBodyLength) 文字")
            Spacer()
            if let note {
                Text("作成 \(note.createdAt.formatted(date: .numeric, time: .shortened))")
                Text("更新 \(note.updatedAt.formatted(date: .numeric, time: .shortened))")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .monospacedDigit()
        .padding(.horizontal, DesignTokens.Spacing.medium)
        .padding(.vertical, DesignTokens.Spacing.small)
        .background(.bar)
    }
}
