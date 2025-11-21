import SwiftUI

struct DetailView: View {
    @ObservedObject var store: ItemStore
    @State private var showingTagPicker: Bool = false

    var body: some View {
        VStack {
            if let selectedId = store.selectedItemId,
               let selectedItem = store.items.first(where: { $0.id == selectedId }) {
                Form {
                    Section {
                        Text(selectedItem.title ?? "Untitled")
                            .font(.title)
                    }

                    Section {
                        Picker("Item Type", selection: Binding(
                            get: { selectedItem.itemType },
                            set: { newType in
                                store.updateItemType(id: selectedId, itemType: newType)
                            }
                        )) {
                            ForEach(ItemType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Section("Tags") {
                        FlowLayout(spacing: 8) {
                            ForEach(store.getTagsForItem(itemId: selectedId)) { tag in
                                TagChip(tag: tag, showRemove: true) {
                                    store.removeTagFromItem(itemId: selectedId, tagId: tag.id)
                                }
                            }

                            Button(action: { showingTagPicker = true }) {
                                Label("Add Tag", systemImage: "plus")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(4)
                        }
                        .frame(minHeight: 32)
                    }

                    if selectedItem.itemType == .task {
                        Section {
                            Toggle("Completed", isOn: Binding(
                                get: { selectedItem.completedAt != nil },
                                set: { _ in
                                    store.toggleTaskCompletion(id: selectedId)
                                }
                            ))
                        }
                    }

                    Section("Debug (Temporary)") {
                        HStack {
                            Text("Item ID:")
                            Spacer()
                            Text(selectedId)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .formStyle(.grouped)
                .padding()
                .sheet(isPresented: $showingTagPicker) {
                    if let selectedId = store.selectedItemId {
                        TagPickerView(store: store, itemId: selectedId)
                    }
                }
                Spacer()
            } else {
                Text("No item selected")
                    .foregroundColor(.secondary)
                    .padding()
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    let settings = UserSettings()
    DetailView(store: ItemStore(settings: settings))
}
