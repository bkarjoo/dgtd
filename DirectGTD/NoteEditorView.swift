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

    var body: some View {
        VStack(spacing: 0) {
            if let selectedId = store.selectedItemId {

                // Toolbar
                HStack {
                    Spacer()

                    // Edit/Preview toggle button
                    Button(action: {
                        // Save when switching from edit to preview
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

                Divider()

                // Content area
                if mode == .edit {
                    // Edit mode - TextEditor
                    TextEditor(text: $editedText)
                        .font(.body)
                        .padding(16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Preview mode - Markdown rendering
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

            } else {
                Text("No item selected")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadNotes()
        }
        .onChange(of: store.selectedItemId) { _, _ in
            loadNotes()
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
}

#Preview {
    let settings = UserSettings()
    return NoteEditorView(store: ItemStore(settings: settings))
}
