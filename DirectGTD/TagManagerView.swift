import SwiftUI

struct TagManagerView: View {
    @ObservedObject var store: ItemStore
    @Environment(\.dismiss) var dismiss

    @State private var showingTagEditor: Bool = false
    @State private var tagToEdit: Tag? = nil
    @State private var showingDeleteConfirmation: Bool = false
    @State private var tagToDelete: Tag? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Manage Tags")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            // Tags list
            if store.tags.isEmpty {
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
                List {
                    ForEach(sortedTags) { tag in
                        TagManagerRow(
                            tag: tag,
                            usageCount: getUsageCount(for: tag),
                            onEdit: {
                                tagToEdit = tag
                                showingTagEditor = true
                            },
                            onDelete: {
                                tagToDelete = tag
                                showingDeleteConfirmation = true
                            }
                        )
                    }
                }
            }

            Divider()

            // Create new tag button
            Button(action: {
                tagToEdit = nil
                showingTagEditor = true
            }) {
                Label("New Tag", systemImage: "plus.circle")
            }
            .buttonStyle(.plain)
            .padding()
        }
        .frame(width: 400, height: 500)
        .sheet(isPresented: $showingTagEditor) {
            if let tag = tagToEdit {
                // Edit existing tag
                TagEditorView(store: store, tagToEdit: tag) { name, color in
                    var updatedTag = tag
                    updatedTag.name = name
                    updatedTag.color = color
                    store.updateTag(tag: updatedTag)
                }
            } else {
                // Create new tag
                TagEditorView(store: store) { name, color in
                    _ = store.createTag(name: name, color: color)
                }
            }
        }
        .alert("Delete Tag?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let tag = tagToDelete {
                    store.deleteTag(tagId: tag.id)
                }
            }
        } message: {
            if let tag = tagToDelete {
                let count = getUsageCount(for: tag)
                if count > 0 {
                    Text("This tag is used by \(count) item(s). Deleting it will remove it from all items.")
                } else {
                    Text("Are you sure you want to delete this tag?")
                }
            }
        }
    }

    private var sortedTags: [Tag] {
        store.tags.sorted { $0.name < $1.name }
    }

    private func getUsageCount(for tag: Tag) -> Int {
        store.itemTags.values.filter { tags in
            tags.contains(where: { $0.id == tag.id })
        }.count
    }
}

struct TagManagerRow: View {
    let tag: Tag
    let usageCount: Int
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TagChip(tag: tag)

            Spacer()

            Text("\(usageCount) item\(usageCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
