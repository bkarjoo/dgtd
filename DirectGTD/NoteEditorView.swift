import SwiftUI

enum NoteEditorMode {
    case edit
    case preview
}

struct NoteEditorView: View {
    @ObservedObject var store: ItemStore
    @Binding var showDetailView: Bool
    @State private var mode: NoteEditorMode = .edit
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
                        Image(systemName: mode == .edit ? "eye" : "pencil")
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

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
                        VStack(alignment: .leading, spacing: 16) {
                            if !editedText.isEmpty {
                                if let attributedString = try? AttributedString(markdown: editedText) {
                                    Text(attributedString)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    Text(editedText)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            } else {
                                Text("No notes")
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
    @Previewable @State var showDetail = false
    let settings = UserSettings()
    return NoteEditorView(store: ItemStore(settings: settings), showDetailView: $showDetail)
}
