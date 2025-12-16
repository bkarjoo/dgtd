import DirectGTDCore
import SwiftUI
import Combine
import UniformTypeIdentifiers

extension UTType {
    static let directGTDItem = UTType(exportedAs: "com.directgtd.item-id")
}

struct TreeView: View {
    @ObservedObject var store: ItemStore
    @ObservedObject var settings: UserSettings
    @FocusState private var isFocused: Bool
    @FocusState private var editFieldFocused: Bool
    @State private var quickCaptureText: String = ""

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
                        VStack(alignment: .leading, spacing: settings.lineSpacing) {
                            ForEach(rootItems, id: \.id) { item in
                                renderItemAndChildren(item: item, depth: 0)
                            }
                        }
                        .padding(.horizontal, settings.horizontalMargin)
                        .padding(.vertical, settings.verticalMargin)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture {
                    DispatchQueue.main.async {
                        isFocused = true
                    }
                }
                .onChange(of: store.selectedItemId) { oldValue, newValue in
                    if let itemId = newValue {
                        DispatchQueue.main.async {
                            proxy.scrollTo(itemId, anchor: .center)
                        }
                    }
                }
                .onChange(of: store.isSearching) { oldValue, newValue in
                    // When returning from search, scroll to selected item
                    if oldValue == true && newValue == false {
                        if let itemId = store.selectedItemId {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                proxy.scrollTo(itemId, anchor: .center)
                            }
                        }
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
        .focusEffectDisabled()
        .focused($isFocused)
        .onChange(of: isFocused) { newValue in
            store.treeHasKeyboardFocus = newValue
        }
        .onDisappear {
            store.treeHasKeyboardFocus = false
        }
        .onKeyPress { keyPress in
            guard store.editingItemId == nil else { return .ignored }
            switch keyPress.key {
            case .downArrow:
                if keyPress.modifiers.contains(.command) {
                    DispatchQueue.main.async {
                        store.moveItemDown()
                    }
                    return .handled
                }
                DispatchQueue.main.async {
                    selectNext()
                }
                return .handled
            case .upArrow:
                if keyPress.modifiers.contains(.command) {
                    DispatchQueue.main.async {
                        store.moveItemUp()
                    }
                    return .handled
                }
                DispatchQueue.main.async {
                    selectPrevious()
                }
                return .handled
            case .rightArrow:
                DispatchQueue.main.async {
                    store.expandSelectedItem()
                }
                return .handled
            case .leftArrow:
                DispatchQueue.main.async {
                    store.collapseSelectedItem()
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
                NSLog("Tab detected - calling indentItem()")
                DispatchQueue.main.async {
                    store.indentItem()
                }
                return .handled
            case KeyEquivalent("\u{19}"):
                NSLog("Shift+Tab (backtab) detected - calling outdentItem()")
                DispatchQueue.main.async {
                    store.outdentItem()
                }
                return .handled
            case KeyEquivalent("+"), KeyEquivalent("="):
                if keyPress.modifiers.contains(.command) {
                    settings.fontSize = min(settings.fontSize + 2, 48)
                    return .handled
                }
                return .ignored
            case KeyEquivalent("-"):
                if keyPress.modifiers.contains(.command) {
                    settings.fontSize = max(settings.fontSize - 2, 8)
                    return .handled
                }
                return .ignored
            case KeyEquivalent("0"):
                if keyPress.modifiers.contains(.command) {
                    settings.fontSize = 13
                    return .handled
                }
                return .ignored
            case KeyEquivalent("t"), KeyEquivalent("T"):
                DispatchQueue.main.async {
                    store.createItemAfterSelected(withType: .task)
                }
                return .handled
            case KeyEquivalent("n"), KeyEquivalent("N"):
                DispatchQueue.main.async {
                    store.createItemAfterSelected(withType: .note)
                }
                return .handled
            case KeyEquivalent("f"), KeyEquivalent("F"):
                // Only create folder if no command modifier is pressed
                // (let Cmd+F and Cmd+Shift+F pass through to ContentView)
                if keyPress.modifiers.contains(.command) {
                    return .ignored
                }
                DispatchQueue.main.async {
                    store.createItemAfterSelected(withType: .folder)
                }
                return .handled
            case KeyEquivalent("p"), KeyEquivalent("P"):
                DispatchQueue.main.async {
                    store.createItemAfterSelected(withType: .project)
                }
                return .handled
            case KeyEquivalent("e"), KeyEquivalent("E"):
                // Cmd+E is handled globally for note editing
                if keyPress.modifiers.contains(.command) {
                    return .ignored
                }
                DispatchQueue.main.async {
                    store.createItemAfterSelected(withType: .event)
                }
                return .handled
            case KeyEquivalent("i"), KeyEquivalent("I"):
                DispatchQueue.main.async {
                    store.showingQuickCapture = true
                }
                return .handled
            case KeyEquivalent("."):
                DispatchQueue.main.async {
                    if let selectedId = store.selectedItemId,
                       let item = store.items.first(where: { $0.id == selectedId }),
                       item.itemType == .task {
                        store.toggleTaskCompletion(id: selectedId)
                        updateSelectionIfInvalid()
                    }
                }
                return .handled
            case KeyEquivalent("c"), KeyEquivalent("C"):
                if keyPress.modifiers.contains(.command) {
                    if keyPress.modifiers.contains(.shift) {
                        // Cmd+Shift+C: Deep copy (entire subtree)
                        DispatchQueue.main.async {
                            store.duplicateItemDeep()
                        }
                    } else {
                        // Cmd+C: Shallow copy (item + immediate children)
                        DispatchQueue.main.async {
                            store.duplicateItemShallow()
                        }
                    }
                    return .handled
                }
                return .ignored
            default:
                NSLog("unhandled key: \(String(describing: keyPress.key)) modifiers=\(keyPress.modifiers)")
                return .ignored
            }
        }
        .onChange(of: isFocused) { oldValue, newValue in
            NSLog("TreeView focus changed: \(oldValue) -> \(newValue)")
        }
        .onChange(of: settings.showCompletedTasks) { oldValue, newValue in
            DispatchQueue.main.async {
                updateSelectionIfInvalid()
            }
        }
        .onChange(of: store.completionDidChange) { oldValue, newValue in
            DispatchQueue.main.async {
                updateSelectionIfInvalid()
            }
        }
        .onChange(of: store.filteredByTag) { oldValue, newValue in
            DispatchQueue.main.async {
                updateSelectionIfInvalid()
            }
        }
        .onChange(of: store.sqlSearchActive) { oldValue, newValue in
            DispatchQueue.main.async {
                updateSelectionIfInvalid()
            }
        }
        .onChange(of: store.sqlSearchResults) { oldValue, newValue in
            // Update selection when SQL results change (e.g., user runs new query)
            DispatchQueue.main.async {
                updateSelectionIfInvalid()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusTreeView)) { _ in
            DispatchQueue.main.async {
                isFocused = true
            }
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
        .sheet(isPresented: $store.showingQuickCapture) {
            QuickCaptureView(
                text: $quickCaptureText,
                onSubmit: {
                    store.createQuickCaptureItem(title: quickCaptureText)
                    quickCaptureText = ""
                    store.showingQuickCapture = false
                },
                onCancel: {
                    quickCaptureText = ""
                    store.showingQuickCapture = false
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Phase 3 Adapter Layer

    private func computeChildren(for item: Item) -> [Item] {
        store.items
            .filter { $0.parentId == item.id }
            .filter { child in
                // Filter by SQL search if active (takes precedence)
                if store.sqlSearchActive {
                    return store.matchesSQLSearch(child)
                }

                // Filter by tag if active (takes precedence over completed check)
                if store.filteredByTag != nil {
                    return store.matchesTagFilter(child)
                }

                // Hide completed tasks if showCompletedTasks is false
                if !settings.showCompletedTasks && child.itemType == .task && child.completedAt != nil {
                    return false
                }

                return true
            }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private func makeRowProps(for item: Item) -> RowProps {
        let children = computeChildren(for: item)
        let isDropTarget = store.dropTargetId == item.id
        return RowProps(
            item: item,
            isSelected: store.selectedItemId == item.id,
            isExpanded: settings.expandedItemIds.contains(item.id),
            isFocusedItem: store.focusedItemId == item.id,
            fontSize: settings.fontSize,
            children: children,
            childCount: children.count,
            tagCount: store.getTagsForItem(itemId: item.id).count,
            isDropTargetInto: isDropTarget && store.dropTargetPosition == .into,
            isDropTargetAbove: isDropTarget && store.dropTargetPosition == .above,
            isDropTargetBelow: isDropTarget && store.dropTargetPosition == .below
        )
    }

    /// Phase 8: Recursively render item and its children from TreeView
    private func renderItemAndChildren(item: Item, depth: Int) -> AnyView {
        let props = makeRowProps(for: item)
        let callbacks = makeRowCallbacks()

        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                ItemRowView(
                    item: item,
                    store: store,
                    editFieldFocused: $editFieldFocused,
                    fontSize: settings.fontSize,
                    rowProps: props,
                    callbacks: callbacks
                )
                .id(item.id)

                // Render children if expanded (or focused item)
                if props.childCount > 0 && (props.isExpanded || props.isFocusedItem) {
                    VStack(alignment: .leading, spacing: settings.lineSpacing) {
                        ForEach(props.children, id: \.id) { child in
                            renderItemAndChildren(item: child, depth: depth + 1)
                                .padding(.leading, 20)
                        }
                    }
                }
            }
        )
    }

    private func makeRowCallbacks() -> ItemRowCallbacks {
        // Phase 4-5-6-7: Centralized tap, chevron, completion, and DnD handling
        ItemRowCallbacks(
            onTap: { [self] itemId in
                DispatchQueue.main.async {
                    // Set keyboard focus to TreeView
                    isFocused = true

                    if store.selectedItemId == itemId {
                        // Already selected: focus and expand
                        store.focusedItemId = itemId
                        settings.expandedItemIds.insert(itemId)
                    } else {
                        // Not selected: select only
                        store.selectedItemId = itemId
                    }
                }
            },
            onChevronTap: { [self] itemId in
                let children = computeChildren(for: store.items.first { $0.id == itemId } ?? Item(id: itemId, title: ""))
                let result = TreeViewInteraction.toggleExpansion(
                    itemId: itemId,
                    isFocusedItem: store.focusedItemId == itemId,
                    hasChildren: !children.isEmpty,
                    selectedId: store.selectedItemId,
                    expanded: settings.expandedItemIds,
                    isDescendant: { childId, parentId in
                        isDescendantOf(childId: childId, parentId: parentId)
                    }
                )
                settings.expandedItemIds = result.expanded
                if let newSelectedId = result.selectedId, newSelectedId != store.selectedItemId {
                    store.selectedItemId = newSelectedId
                }
            },
            onToggleComplete: { [self] itemId in
                // Look up item to check if it's a task
                guard let item = store.items.first(where: { $0.id == itemId }),
                      item.itemType == .task else { return }

                DispatchQueue.main.async {
                    // Toggle completion
                    store.toggleTaskCompletion(id: itemId)

                    // Update selection if the item became hidden due to filters
                    updateSelectionIfInvalid()
                }
            },
            // Phase 7: Drag-and-drop callbacks
            onDragStart: { [store] itemId in
                store.draggedItemId = itemId
            },
            onDropValidate: { [store] draggedId, targetId, position in
                store.canDropItem(draggedItemId: draggedId, onto: targetId, position: position)
            },
            onDropPerform: { [store] draggedId, targetId, position in
                DispatchQueue.main.async {
                    store.moveItem(draggedItemId: draggedId, targetItemId: targetId, position: position)
                    store.selectedItemId = draggedId
                    // Clear drop indicators
                    store.draggedItemId = nil
                    store.dropTargetId = nil
                    store.dropTargetPosition = nil
                }
            },
            onDropUpdated: { [store] targetId, position in
                store.dropTargetId = targetId
                store.dropTargetPosition = position
            },
            onDropExited: { [store] targetId in
                if store.dropTargetId == targetId {
                    store.dropTargetId = nil
                    store.dropTargetPosition = nil
                }
            },
            onDragEnd: { [store] in
                store.draggedItemId = nil
                store.dropTargetId = nil
                store.dropTargetPosition = nil
            }
        )
    }

    /// Check if childId is a descendant of parentId
    private func isDescendantOf(childId: String, parentId: String) -> Bool {
        if childId == parentId { return false }
        guard let child = store.items.first(where: { $0.id == childId }) else { return false }

        var current = child
        while let pid = current.parentId {
            if pid == parentId { return true }
            guard let parent = store.items.first(where: { $0.id == pid }) else { break }
            current = parent
        }
        return false
    }

    // MARK: - Computed Properties

    private var rootItems: [Item] {
        // In focus mode, the focused item is the only root
        if let focusedId = store.focusedItemId,
           let focusedItem = store.items.first(where: { $0.id == focusedId }) {
            return [focusedItem]
        }

        // Normal mode: show all root items
        return store.items
            .filter { $0.parentId == nil }
            .filter { store.shouldShowItem($0) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var visibleItems: [Item] {
        var result: [Item] = []

        func collectItems(_ items: [Item]) {
            for item in items {
                result.append(item)
                let children = store.items
                    .filter { $0.parentId == item.id }
                    .filter { store.shouldShowItem($0) }
                    .sorted { $0.sortOrder < $1.sortOrder }
                // In focus mode, show all descendants regardless of expansion state
                let shouldShowChildren = !children.isEmpty && (store.focusedItemId != nil || store.settings.expandedItemIds.contains(item.id))
                if shouldShowChildren {
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

    private func updateSelectionIfInvalid() {
        guard let currentId = store.selectedItemId else {
            // No selection, select first visible item if any
            store.selectedItemId = visibleItems.first?.id
            return
        }

        // Check if current selection is still visible
        if visibleItems.contains(where: { $0.id == currentId }) {
            return // Still valid
        }

        guard let currentItem = store.items.first(where: { $0.id == currentId }) else {
            // Item deleted, select first visible
            store.selectedItemId = visibleItems.first?.id
            return
        }

        // 1. Try previous sibling with status not complete
        let siblings = store.items
            .filter { $0.parentId == currentItem.parentId }
            .sorted { $0.sortOrder < $1.sortOrder }

        if let currentIndex = siblings.firstIndex(where: { $0.id == currentId }) {
            // Look backwards for visible sibling
            for i in stride(from: currentIndex - 1, through: 0, by: -1) {
                let sibling = siblings[i]
                if store.shouldShowItem(sibling) {
                    store.selectedItemId = sibling.id
                    return
                }
            }

            // 2. Try next sibling with status not complete
            for i in (currentIndex + 1)..<siblings.count {
                let sibling = siblings[i]
                if store.shouldShowItem(sibling) {
                    store.selectedItemId = sibling.id
                    return
                }
            }
        }

        // 3. Walk up parents until finding one that should be shown
        var parentId = currentItem.parentId
        while let pid = parentId {
            if let parent = store.items.first(where: { $0.id == pid }) {
                if store.shouldShowItem(parent) {
                    store.selectedItemId = parent.id
                    return
                }
                // Parent is hidden (completed task), go to its parent
                parentId = parent.parentId
            } else {
                break
            }
        }

        // 4. No valid relative found, select first visible item in tree
        if let firstVisible = visibleItems.first {
            store.selectedItemId = firstVisible.id
        } else {
            // 5. No visible items at all
            store.selectedItemId = nil
        }
    }
}

struct QuickCaptureView: View {
    @Binding var text: String
    let onSubmit: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Quick Capture")
                .font(.headline)

            TextField("What do you need to do?", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 16))
                .onSubmit {
                    onSubmit()
                }

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    onSubmit()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 400, height: 150)
    }
}

#Preview {
    let settings = UserSettings()
    TreeView(store: ItemStore(settings: settings), settings: settings)
}
