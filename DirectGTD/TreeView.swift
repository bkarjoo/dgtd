import SwiftUI

struct TreeView: View {
    @ObservedObject var store: ItemStore
    @FocusState private var isFocused: Bool
    @FocusState private var editFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Items list
            if store.items.isEmpty {
                VStack {
                    Text("No items")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture {
                    DispatchQueue.main.async {
                        isFocused = true
                    }
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(rootItems, id: \.id) { item in
                                ItemRow(item: item, allItems: store.items, store: store, editFieldFocused: $editFieldFocused)
                                    .id(item.id)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                .onTapGesture {
                    DispatchQueue.main.async {
                        isFocused = true
                    }
                }
                .onChange(of: store.editingItemId) { oldValue, newValue in
                    if let itemId = newValue {
                        DispatchQueue.main.async {
                            proxy.scrollTo(itemId, anchor: .center)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            editFieldFocused = true
                        }
                    } else {
                        DispatchQueue.main.async {
                            isFocused = true
                        }
                    }
                }
                .onAppear {
                    if let itemId = store.editingItemId {
                        DispatchQueue.main.async {
                            proxy.scrollTo(itemId, anchor: .center)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            editFieldFocused = true
                        }
                    }
                }
                }
            }
        }
        .focusable()
        .focused($isFocused)
        .onKeyPress { keyPress in
            guard store.editingItemId == nil else { return .ignored }
            switch keyPress.key {
            case .downArrow:
                DispatchQueue.main.async {
                    selectNext()
                }
                return .handled
            case .upArrow:
                DispatchQueue.main.async {
                    selectPrevious()
                }
                return .handled
            case KeyEquivalent("\u{7F}"), .delete:
                NSLog("delete pressed: modifiers=\(keyPress.modifiers)")
                DispatchQueue.main.async {
                    store.deleteSelectedItem()
                }
                return .handled
            case .return, KeyEquivalent("\r"):
                DispatchQueue.main.async {
                    store.createItemAfterSelected()
                }
                return .handled
            case .escape:
                DispatchQueue.main.async {
                    store.cancelEditing()
                }
                return .handled
            case .space, KeyEquivalent(" "):
                DispatchQueue.main.async {
                    if let selectedId = store.selectedItemId {
                        store.editingItemId = selectedId
                    }
                }
                return .handled
            case .tab:
                if keyPress.modifiers.contains(.shift) {
                    DispatchQueue.main.async {
                        store.outdentItem()
                    }
                } else {
                    DispatchQueue.main.async {
                        store.indentItem()
                    }
                }
                return .handled
            default:
                NSLog("unhandled key: \(String(describing: keyPress.key)) modifiers=\(keyPress.modifiers)")
                return .ignored
            }
        }
        .border(Color.blue)
        .onChange(of: isFocused) { oldValue, newValue in
            NSLog("TreeView focus changed: \(oldValue) -> \(newValue)")
        }
        .onAppear {
            DispatchQueue.main.async {
                store.loadItems()
            }

            DispatchQueue.main.async {
                isFocused = true
                NSLog("TreeView onAppear: setting isFocused to true")

                // Select first item if nothing is selected
                if store.selectedItemId == nil, let firstItem = visibleItems.first {
                    store.selectedItemId = firstItem.id
                    NSLog("TreeView onAppear: selected first item \(firstItem.id)")
                }
            }
        }
    }

    private var rootItems: [Item] {
        store.items.filter { $0.parentId == nil }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var visibleItems: [Item] {
        var result: [Item] = []

        func collectItems(_ items: [Item]) {
            for item in items {
                result.append(item)
                let children = store.items.filter { $0.parentId == item.id }.sorted { $0.sortOrder < $1.sortOrder }
                if !children.isEmpty && store.expandedItemIds.contains(item.id) {
                    collectItems(children)
                }
            }
        }

        collectItems(rootItems)
        return result
    }

    private func selectNext() {
        guard let currentId = store.selectedItemId,
              let currentIndex = visibleItems.firstIndex(where: { $0.id == currentId }),
              currentIndex < visibleItems.count - 1 else {
            return
        }
        store.selectedItemId = visibleItems[currentIndex + 1].id
    }

    private func selectPrevious() {
        guard let currentId = store.selectedItemId,
              let currentIndex = visibleItems.firstIndex(where: { $0.id == currentId }),
              currentIndex > 0 else {
            return
        }
        store.selectedItemId = visibleItems[currentIndex - 1].id
    }
}

struct ItemRow: View {
    let item: Item
    let allItems: [Item]
    @ObservedObject var store: ItemStore
    @FocusState.Binding var editFieldFocused: Bool
    @State private var editText: String = ""

    private var isExpanded: Binding<Bool> {
        Binding(
            get: { store.expandedItemIds.contains(item.id) },
            set: { newValue in
                if newValue {
                    store.expandedItemIds.insert(item.id)
                } else {
                    store.expandedItemIds.remove(item.id)
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if children.isEmpty {
                if isEditing {
                    TextField("", text: $editText)
                        .focused($editFieldFocused)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                        .onSubmit {
                            commitEdit()
                        }
                        .onAppear {
                            editText = item.title ?? ""
                        }
                        .onExitCommand {
                            cancelEdit()
                        }
                } else {
                    Text(item.title ?? "Untitled")
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            DispatchQueue.main.async {
                                store.selectedItemId = item.id
                            }
                        }
                }
            } else {
                DisclosureGroup(
                    isExpanded: isExpanded,
                    content: {
                        ForEach(children, id: \.id) { child in
                            ItemRow(item: child, allItems: allItems, store: store, editFieldFocused: $editFieldFocused)
                                .id(child.id)
                                .padding(.leading, 20)
                        }
                    },
                    label: {
                        if isEditing {
                            TextField("", text: $editText)
                                .focused($editFieldFocused)
                                .textFieldStyle(.plain)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                                .onSubmit {
                                    commitEdit()
                                }
                                .onAppear {
                                    editText = item.title ?? ""
                                }
                                .onExitCommand {
                                    cancelEdit()
                                }
                        } else {
                            Text(item.title ?? "Untitled")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                                .contentShape(Rectangle())
                        }
                    }
                )
                .onTapGesture {
                    DispatchQueue.main.async {
                        store.selectedItemId = item.id
                    }
                }
            }
        }
    }

    private var isEditing: Bool {
        store.editingItemId == item.id
    }

    private var isSelected: Bool {
        store.selectedItemId == item.id
    }

    private var children: [Item] {
        allItems.filter { $0.parentId == item.id }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func commitEdit() {
        if editText.isEmpty {
            store.cancelEditing()
        } else {
            store.updateItemTitle(id: item.id, title: editText)
            store.editingItemId = nil
        }
    }

    private func cancelEdit() {
        store.cancelEditing()
    }
}

#Preview {
    TreeView(store: ItemStore())
}
