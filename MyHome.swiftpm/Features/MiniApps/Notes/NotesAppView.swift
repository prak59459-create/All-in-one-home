import SwiftUI

/// メモ（F0506、F0321–F0339）。一覧から開いて書き、書いた内容は自動で保存する。
@MainActor
struct NotesAppView: View {
    @Environment(MiniAppLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var path: [String] = []

    var body: some View {
        let document: MiniAppDocument<NoteBook> = library.document(NoteBook.self)
        NavigationStack(path: $path) {
            MiniAppHost(document: document) {
                NotesListView(document: document, path: $path)
            }
            .navigationTitle("メモ")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { (noteID: String) in
                NoteEditorView(document: document, noteID: noteID)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

@MainActor
struct NotesListView: View {
    let document: MiniAppDocument<NoteBook>
    @Binding var path: [String]
    @State private var query: String = ""
    @State private var pendingRemoval: Note?
    @State private var failure: String?

    var body: some View {
        List {
            NotesListContent(
                notes: document.content.search(query),
                isSearching: !query.isEmpty,
                onPin: togglePin,
                onRemove: { (note: Note) in pendingRemoval = note }
            )
        }
        .searchable(text: $query, prompt: "メモを検索")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    addNote()
                } label: {
                    Label("新しいメモ", systemImage: "square.and.pencil")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .confirmationDialog(removalTitle, isPresented: isConfirmingRemoval, titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                remove()
            }
        } message: {
            Text("削除したメモは元に戻せません。")
        }
        .alert("メモ", isPresented: isShowingFailure) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
    }

    private var removalTitle: String {
        "「\(pendingRemoval?.displayTitle ?? "")」を削除しますか？"
    }

    private var isConfirmingRemoval: Binding<Bool> {
        Binding<Bool>(
            get: { pendingRemoval != nil },
            set: { (isShown: Bool) in
                if !isShown {
                    pendingRemoval = nil
                }
            }
        )
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

    private func addNote() {
        let id: String = NoteBook.newID()
        do {
            try document.perform { (book: inout NoteBook) in
                try book.addNote(id: id, now: Date())
            }
            query = ""
            path.append(id)
        } catch let error as NoteEditError {
            failure = error.message
        } catch {
            failure = "メモを作れませんでした。"
        }
    }

    private func togglePin(_ note: Note) {
        document.update { (book: inout NoteBook) in
            book.setPinned(id: note.id, !note.isPinned)
        }
    }

    private func remove() {
        guard let note = pendingRemoval else { return }
        document.update { (book: inout NoteBook) in
            book.removeNote(id: note.id)
        }
        pendingRemoval = nil
    }
}

@MainActor
struct NotesListContent: View {
    let notes: [Note]
    let isSearching: Bool
    let onPin: @MainActor (Note) -> Void
    let onRemove: @MainActor (Note) -> Void

    var body: some View {
        if notes.isEmpty {
            Text(isSearching ? "見つかりませんでした。" : "メモはまだありません。右上のボタンで作れます。")
                .foregroundStyle(.secondary)
        }
        ForEach(notes) { (note: Note) in
            NavigationLink(value: note.id) {
                NoteRow(note: note)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button("削除", role: .destructive) {
                    onRemove(note)
                }
            }
            .swipeActions(edge: .leading) {
                Button(note.isPinned ? "ピンを外す" : "ピン留め") {
                    onPin(note)
                }
                .tint(.orange)
            }
            .contextMenu {
                Button(note.isPinned ? "ピンを外す" : "ピン留め", systemImage: "pin") {
                    onPin(note)
                }
                Button("削除", systemImage: "trash", role: .destructive) {
                    onRemove(note)
                }
            }
        }
    }
}

/// 一覧の1行（タイトル、更新日時、本文の最初の行）。
@MainActor
struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: DesignTokens.Spacing.xSmall) {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(Color.orange)
                        .accessibilityLabel("ピン留め")
                }
                Text(note.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
            }
            HStack(spacing: DesignTokens.Spacing.small) {
                Text(note.updatedAt, format: .dateTime.month().day().hour().minute())
                Text(note.preview)
                    .lineLimit(1)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
}
