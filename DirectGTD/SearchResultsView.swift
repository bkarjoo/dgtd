import SwiftUI

struct SearchResultsView: View {
    @ObservedObject var store: ItemStore
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search items...", text: $store.searchText)
                    .textFieldStyle(.plain)
                    .focused($searchFieldFocused)
                    .onExitCommand {
                        // Escape pressed in text field - close search
                        store.isSearching = false
                        store.searchText = ""
                    }
                if !store.searchText.isEmpty {
                    Button(action: { store.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Results list
            if store.searchText.isEmpty {
                VStack {
                    Spacer()
                    Text("Type to search")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if store.searchResults.isEmpty {
                VStack {
                    Spacer()
                    Text("No results")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(store.searchResults, id: \.id) { item in
                            SearchResultRow(item: item, store: store)
                        }
                    }
                }
            }
        }
        .onAppear {
            searchFieldFocused = true
        }
    }
}

struct SearchResultRow: View {
    let item: Item
    @ObservedObject var store: ItemStore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // Show task checkbox or type icon
                if item.itemType == .task {
                    Image(systemName: isCompleted ? "checkmark.square.fill" : "square")
                        .font(.system(size: 14))
                        .foregroundColor(isCompleted ? .secondary : .primary)
                } else {
                    Image(systemName: item.itemType.defaultIcon)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Text(item.title ?? "Untitled")
                    .font(.system(size: 14))
                    .strikethrough(isCompleted)
                    .foregroundColor(isCompleted ? .secondary : .primary)
            }

            if !breadcrumb.isEmpty {
                Text(breadcrumb)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            selectAndJumpToItem()
        }
    }

    private var isSelected: Bool {
        store.selectedItemId == item.id
    }

    private var isCompleted: Bool {
        item.itemType == .task && item.completedAt != nil
    }

    private var breadcrumb: String {
        let path = store.getItemPath(itemId: item.id)
        // Remove the item itself from the path (last component)
        let components = path.components(separatedBy: " > ")
        return components.dropLast().joined(separator: " > ")
    }

    private func selectAndJumpToItem() {
        // Expand all ancestors so the item is visible
        expandAncestors()

        // If selecting a completed task while "hide completed" is off, turn it on
        if isCompleted && !store.settings.showCompletedTasks {
            store.settings.showCompletedTasks = true
        }

        // Select the item and close search
        store.selectedItemId = item.id
        store.isSearching = false
        store.searchText = ""
    }

    private func expandAncestors() {
        var currentId: String? = item.parentId

        while let parentId = currentId {
            store.settings.expandedItemIds.insert(parentId)
            // Find parent's parent
            if let parent = store.items.first(where: { $0.id == parentId }) {
                currentId = parent.parentId
            } else {
                break
            }
        }
    }
}

#Preview {
    let settings = UserSettings()
    SearchResultsView(store: ItemStore(settings: settings))
}
