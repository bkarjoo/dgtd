import SwiftUI

struct TagPickerView: View {
    @ObservedObject var store: ItemStore
    @Environment(\.dismiss) var dismiss

    let itemId: String

    @State private var searchText: String = ""
    @State private var showingTagEditor: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Tags")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .padding()

            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search tags...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Tags list
            if filteredTags.isEmpty && !searchText.isEmpty {
                VStack {
                    Spacer()
                    Text("No tags found")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if store.tags.isEmpty {
                VStack {
                    Spacer()
                    Text("No tags yet")
                        .foregroundColor(.secondary)
                    Text("Create your first tag below")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredTags) { tag in
                            TagRow(tag: tag, isSelected: isTagSelected(tag), onToggle: {
                                toggleTag(tag)
                            })
                        }
                    }
                }
            }

            Divider()

            // Create new tag button
            Button(action: { showingTagEditor = true }) {
                Label("Create New Tag", systemImage: "plus.circle")
            }
            .buttonStyle(.plain)
            .padding()
        }
        .frame(width: 300, height: 400)
        .sheet(isPresented: $showingTagEditor) {
            TagEditorView(store: store) { name, color in
                if let newTag = store.createTag(name: name, color: color) {
                    // Automatically add the new tag to the item
                    store.addTagToItem(itemId: itemId, tag: newTag)
                }
            }
        }
    }

    private var filteredTags: [Tag] {
        if searchText.isEmpty {
            return store.tags.sorted { $0.name < $1.name }
        } else {
            return store.tags
                .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
                .sorted { $0.name < $1.name }
        }
    }

    private func isTagSelected(_ tag: Tag) -> Bool {
        store.getTagsForItem(itemId: itemId).contains { $0.id == tag.id }
    }

    private func toggleTag(_ tag: Tag) {
        if isTagSelected(tag) {
            store.removeTagFromItem(itemId: itemId, tagId: tag.id)
        } else {
            store.addTagToItem(itemId: itemId, tag: tag)
        }
    }
}

struct TagRow: View {
    let tag: Tag
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .accentColor : .secondary)

                TagChip(tag: tag)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
