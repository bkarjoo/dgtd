import SwiftUI
import MarkdownUI

enum NoteEditorMode {
    case edit
    case preview
}

struct NoteEditorView: View {
    @ObservedObject var store: ItemStore
    @State private var mode: NoteEditorMode = .preview
    @State private var editedText: String = ""
    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let selectedId = store.selectedItemId {
                toolbarSection(selectedId: selectedId)
                Divider()

                if mode == .edit {
                    TextEditor(text: $editedText)
                        .font(.body)
                        .padding(16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .focused($editorFocused)
                } else {
                    previewSection
                }
            } else {
                Text("No item selected")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            mode = .preview
            loadNotes()
        }
        .onChange(of: store.selectedItemId) { _, _ in
            mode = .preview
            loadNotes()
        }
        .onReceive(store.$noteEditorShouldToggleEditMode) { _ in handleToggleShortcut() }
    }

    private func toolbarSection(selectedId: String) -> some View {
        HStack {
            Spacer()
            Button(action: {
                if mode == .edit {
                    saveNotes(for: selectedId)
                }
                mode = mode == .edit ? .preview : .edit
            }) {
                Image(systemName: "pencil")
                    .foregroundColor(mode == .edit ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(mode == .edit ? Color.accentColor : Color.clear)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var previewSection: some View {
        ScrollView {
            if !editedText.isEmpty {
                Markdown(editedText)
                    .padding(16)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack {
                    Spacer()
                    Text("No notes")
                        .foregroundColor(.secondary)
                        .italic()
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleToggleShortcut() {
        if case .edit = mode {
            saveCurrentNoteIfNeeded()
            mode = .preview
            store.noteEditorIsInEditMode = false
            editorFocused = false
            DispatchQueue.main.async { store.focusTreeView() }
        } else {
            mode = .edit
            store.noteEditorIsInEditMode = true
            editorFocused = true
        }
    }

    private func loadNotes() {
        guard let selectedId = store.selectedItemId,
              let selectedItem = store.items.first(where: { $0.id == selectedId }) else {
            editedText = ""
            return
        }
        editedText = selectedItem.notes ?? ""
    }

    private func saveNotes(for itemId: String) {
        let notesToSave = editedText.isEmpty ? nil : editedText
        store.updateNotes(id: itemId, notes: notesToSave)
    }

    private func saveCurrentNoteIfNeeded() {
        guard let selectedId = store.selectedItemId else { return }
        saveNotes(for: selectedId)
    }
}

#Preview {
    let settings = UserSettings()
    return NoteEditorView(store: ItemStore(settings: settings))
}
