import SwiftUI

/// ウィジェットの設定（F0165、F0179）。大きさ、時計の表示、メモの内容、並べ替え、削除。
@MainActor
struct WidgetEditorView: View {
    let widgetID: String
    @Environment(HomeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var size: WidgetSize = .small
    @State private var isAnalog: Bool = false
    @State private var showsSeconds: Bool = false
    @State private var note: String = ""
    @State private var isLoaded: Bool = false
    @State private var isConfirmingRemoval: Bool = false
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("ウィジェット")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") { save() }
                    }
                }
        }
        .onAppear {
            load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let widget = store.layout.widget(id: widgetID) {
            Form {
                Section(widget.kind.title) {
                    Picker("大きさ", selection: $size) {
                        ForEach(WidgetSize.allCases, id: \.self) { size in
                            Text(size.title).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                kindSection(widget.kind)
                Section {
                    Button("前に移動") { move(by: -1) }
                    Button("後ろに移動") { move(by: 1) }
                    Button("削除", role: .destructive) { isConfirmingRemoval = true }
                }
                if let failure {
                    Text(failure).foregroundStyle(.red)
                }
            }
            .confirmationDialog("ウィジェットを削除しますか？", isPresented: $isConfirmingRemoval, titleVisibility: .visible) {
                Button("削除", role: .destructive) { remove() }
            }
        } else {
            ContentUnavailableView("ウィジェットが見つかりません", systemImage: "questionmark.square.dashed")
        }
    }

    @ViewBuilder
    private func kindSection(_ kind: WidgetKind) -> some View {
        switch kind {
        case .clock:
            Section("時計") {
                Toggle("アナログ", isOn: $isAnalog)
                Toggle("秒を表示", isOn: $showsSeconds)
            }
        case .note:
            Section {
                TextEditor(text: $note)
                    .frame(minHeight: 160)
            } header: {
                Text("付箋")
            } footer: {
                Text("\(note.count) / \(WidgetLimits.maximumNoteLength) 文字")
            }
        case .calendar, .timer, .app:
            EmptyView()
        }
    }

    private func load() {
        guard !isLoaded, let widget = store.layout.widget(id: widgetID) else { return }
        size = widget.size
        if case .clock(let style) = widget.kind {
            isAnalog = style.isAnalog
            showsSeconds = style.showsSeconds
        }
        if case .note(let text) = widget.kind {
            note = text
        }
        isLoaded = true
    }

    private func updatedKind(_ kind: WidgetKind) -> WidgetKind {
        switch kind {
        case .clock:
            return .clock(ClockWidgetStyle(isAnalog: isAnalog, showsSeconds: showsSeconds))
        case .note:
            return .note(note)
        case .calendar, .timer, .app:
            return kind
        }
    }

    private func save() {
        guard let widget = store.layout.widget(id: widgetID) else { return dismiss() }
        perform { try store.updateWidget(id: widgetID, kind: updatedKind(widget.kind), size: size) }
    }

    private func move(by offset: Int) {
        do {
            try store.moveWidget(id: widgetID, by: offset)
        } catch let error as LayoutEditError {
            failure = error.message
        } catch {
            failure = "移動できませんでした。"
        }
    }

    private func remove() {
        perform { try store.removeWidget(id: widgetID) }
    }

    private func perform(_ change: () throws -> Void) {
        do {
            try change()
            dismiss()
        } catch let error as LayoutEditError {
            failure = error.message
        } catch {
            failure = "変更できませんでした。"
        }
    }
}
