import SwiftUI

struct DetailView: View {
    @ObservedObject var store: ItemStore

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
                }
                .formStyle(.grouped)
                .padding()
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
