import SwiftUI

struct TagFilterPickerView: View {
    @ObservedObject var store: ItemStore
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Filter by Tag")
                    .font(.headline)
                Spacer()
                if store.filteredByTag != nil {
                    Button("Clear") {
                        store.filteredByTag = nil
                        onDismiss()
                    }
                }
            }
            .padding()

            Divider()

            // Tags list
            if store.tags.isEmpty {
                VStack {
                    Spacer()
                    Text("No tags")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 150)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(sortedTags) { tag in
                            Button(action: {
                                store.filteredByTag = tag
                                onDismiss()
                            }) {
                                HStack(spacing: 12) {
                                    TagChip(tag: tag)

                                    Spacer()

                                    if store.filteredByTag?.id == tag.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .frame(width: 250)
    }

    private var sortedTags: [Tag] {
        store.tags.sorted { $0.name < $1.name }
    }
}
