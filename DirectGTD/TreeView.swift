import SwiftUI
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
                                ItemRow(item: item, allItems: store.items, store: store, settings: settings, editFieldFocused: $editFieldFocused, fontSize: settings.fontSize, onCompletionToggled: { updateSelectionIfInvalid() })
                                    .id(item.id)
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

    private func shouldShowItem(_ item: Item) -> Bool {
        // Filter by tag if active (takes precedence over completed check)
        if store.filteredByTag != nil {
            return store.matchesTagFilter(item)
        }

        // Hide completed tasks if showCompletedTasks is false
        if !settings.showCompletedTasks && item.itemType == .task && item.completedAt != nil {
            return false
        }

        return true
    }

    private var rootItems: [Item] {
        store.items
            .filter { $0.parentId == nil }
            .filter { shouldShowItem($0) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var visibleItems: [Item] {
        var result: [Item] = []

        func collectItems(_ items: [Item]) {
            for item in items {
                result.append(item)
                let children = store.items
                    .filter { $0.parentId == item.id }
                    .filter { shouldShowItem($0) }
                    .sorted { $0.sortOrder < $1.sortOrder }
                if !children.isEmpty && store.settings.expandedItemIds.contains(item.id) {
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
                if shouldShowItem(sibling) {
                    store.selectedItemId = sibling.id
                    return
                }
            }

            // 2. Try next sibling with status not complete
            for i in (currentIndex + 1)..<siblings.count {
                let sibling = siblings[i]
                if shouldShowItem(sibling) {
                    store.selectedItemId = sibling.id
                    return
                }
            }
        }

        // 3. Walk up parents until finding one that should be shown
        var parentId = currentItem.parentId
        while let pid = parentId {
            if let parent = store.items.first(where: { $0.id == pid }) {
                if shouldShowItem(parent) {
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

struct ItemRow: View {
    let item: Item
    let allItems: [Item]
    @ObservedObject var store: ItemStore
    @ObservedObject var settings: UserSettings
    @FocusState.Binding var editFieldFocused: Bool
    let fontSize: CGFloat
    let onCompletionToggled: () -> Void
    @State private var editText: String = ""
    @State private var rowHeight: CGFloat = 0

    private var isExpanded: Binding<Bool> {
        Binding(
            get: { settings.expandedItemIds.contains(item.id) },
            set: { newValue in
                if newValue {
                    settings.expandedItemIds.insert(item.id)
                } else {
                    // Collapsing: check if any descendant is selected
                    if hasSelectedDescendant(item: item) {
                        store.selectedItemId = item.id
                    }
                    settings.expandedItemIds.remove(item.id)
                }
            }
        )
    }

    private func hasSelectedDescendant(item: Item) -> Bool {
        guard let selectedId = store.selectedItemId else { return false }
        return isDescendant(of: item, itemId: selectedId, in: allItems)
    }

    private func isDescendant(of parent: Item, itemId: String, in items: [Item]) -> Bool {
        if itemId == parent.id { return false }

        guard let item = items.first(where: { $0.id == itemId }) else { return false }

        var current = item
        while let parentId = current.parentId {
            if parentId == parent.id {
                return true
            }
            guard let parentItem = items.first(where: { $0.id == parentId }) else {
                break
            }
            current = parentItem
        }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                // Fixed-width chevron area
                Button(action: {
                    if !children.isEmpty {
                        isExpanded.wrappedValue.toggle()
                    }
                }) {
                    if !children.isEmpty {
                        Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                            .font(.system(size: fontSize * 0.8))
                            .frame(width: fontSize, height: fontSize)
                            .contentShape(Rectangle())
                    } else {
                        Color.clear
                            .frame(width: fontSize, height: fontSize)
                    }
                }
                .buttonStyle(.plain)

                if isEditing {
                    TextField("", text: $editText)
                        .focused($editFieldFocused)
                        .textFieldStyle(.plain)
                        .font(.system(size: fontSize))
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
                    // Icon
                    if item.itemType == .task {
                        Image(systemName: item.completedAt == nil ? "square" : "checkmark.square.fill")
                            .font(.system(size: fontSize))
                            .onTapGesture {
                                DispatchQueue.main.async {
                                    store.toggleTaskCompletion(id: item.id)
                                    onCompletionToggled()
                                }
                            }
                    } else {
                        Image(systemName: item.itemType.defaultIcon)
                            .font(.system(size: fontSize))
                    }

                    Text(item.title ?? "Untitled")
                        .font(.system(size: fontSize))

                    Spacer()

                    // Date badges
                    if let dueDate = item.dueDate {
                        let dueDateObj = Date(timeIntervalSince1970: TimeInterval(dueDate))
                        let isOverdue = dueDateObj < Date()
                        let isToday = Calendar.current.isDateInToday(dueDateObj)
                        let isTomorrow = Calendar.current.isDateInTomorrow(dueDateObj)

                        Text(isToday ? "Today" : isTomorrow ? "Tomorrow" : formatDate(dueDateObj))
                            .font(.system(size: fontSize * 0.8))
                            .foregroundColor(isOverdue ? .red : isToday ? .orange : .secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background((isOverdue ? Color.red : isToday ? Color.orange : Color.secondary).opacity(0.1))
                            .cornerRadius(4)
                    }

                    if let startTime = item.earliestStartTime {
                        let startDateObj = Date(timeIntervalSince1970: TimeInterval(startTime))
                        let isDeferred = startDateObj > Date()

                        if isDeferred {
                            Text(formatDate(startDateObj))
                                .font(.system(size: fontSize * 0.8))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }

                    // Tag count badge
                    if tagCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "tag.fill")
                                .font(.system(size: fontSize * 0.7))
                            Text("\(tagCount)")
                                .font(.system(size: fontSize * 0.8))
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                    }

                    // Children count
                    if !children.isEmpty {
                        Text("\(children.count)")
                            .font(.system(size: fontSize * 0.9))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .overlay(alignment: .top) {
                if store.dropTargetId == item.id && store.dropTargetPosition == .above {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(height: 2)
                }
            }
            .overlay(alignment: .bottom) {
                if store.dropTargetId == item.id && store.dropTargetPosition == .below {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(height: 2)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                DispatchQueue.main.async {
                    store.selectedItemId = item.id
                }
            }
            .onDrag {
                store.draggedItemId = item.id
                let provider = NSItemProvider()
                provider.registerDataRepresentation(forTypeIdentifier: UTType.directGTDItem.identifier, visibility: .all) { completion in
                    let data = item.id.data(using: .utf8)
                    completion(data, nil)
                    return nil
                }
                return provider
            }
            .background(GeometryReader { geometry in
                Color.clear.preference(key: ItemHeightPreferenceKey.self, value: geometry.size.height)
            })
            .onPreferenceChange(ItemHeightPreferenceKey.self) { height in
                rowHeight = height
            }
            .onDrop(of: [.directGTDItem], delegate: ItemDropDelegate(
                item: item,
                allItems: allItems,
                store: store,
                rowHeight: rowHeight > 0 ? rowHeight : fontSize * 2.5 // Use measured height, fallback to estimate
            ))

            // Children (if expanded)
            if !children.isEmpty && isExpanded.wrappedValue {
                VStack(alignment: .leading, spacing: settings.lineSpacing) {
                    ForEach(children, id: \.id) { child in
                        ItemRow(item: child, allItems: allItems, store: store, settings: settings, editFieldFocused: $editFieldFocused, fontSize: fontSize, onCompletionToggled: onCompletionToggled)
                            .id(child.id)
                            .padding(.leading, 20)
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
        allItems
            .filter { $0.parentId == item.id }
            .filter { child in
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

    private var tagCount: Int {
        store.getTagsForItem(itemId: item.id).count
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
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

struct ItemHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ItemDropDelegate: DropDelegate {
    let item: Item
    let allItems: [Item]
    let store: ItemStore
    let rowHeight: CGFloat

    func performDrop(info: DropInfo) -> Bool {
        defer {
            store.draggedItemId = nil
            store.dropTargetId = nil
            store.dropTargetPosition = nil
        }

        guard let itemProvider = info.itemProviders(for: [.directGTDItem]).first else {
            return false
        }

        itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.directGTDItem.identifier) { data, error in
            guard let data = data,
                  let draggedItemId = String(data: data, encoding: .utf8) else {
                return
            }

            DispatchQueue.main.async {
                let position = getDropPosition(info: info)
                store.moveItem(draggedItemId: draggedItemId, targetItemId: item.id, position: position)
                store.selectedItemId = draggedItemId
            }
        }

        return true
    }

    func validateDrop(info: DropInfo) -> Bool {
        // Only accept drops with our custom type (rejects external drags automatically)
        guard info.itemProviders(for: [.directGTDItem]).first != nil else {
            return false
        }

        // Validate using tracked draggedItemId (synchronous)
        // Custom UTType ensures this is always a real in-app drag, never spoofed
        let position = getDropPosition(info: info)
        return store.canDropItem(draggedItemId: store.draggedItemId, onto: item.id, position: position)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let position = getDropPosition(info: info)
        store.dropTargetId = item.id
        store.dropTargetPosition = position
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if store.dropTargetId == item.id {
            store.dropTargetId = nil
            store.dropTargetPosition = nil
        }
    }

    private func getDropPosition(info: DropInfo) -> DropPosition {
        // Divide the item into three zones: top 25%, middle 50%, bottom 25%
        let y = info.location.y

        // Calculate relative position within the row (0-1)
        // DropInfo.location gives us coordinates within the drop target view
        let relativeY = y / rowHeight

        if relativeY < 0.25 {
            return .above
        } else if relativeY > 0.75 {
            return .below
        } else {
            return .into
        }
    }
}

#Preview {
    let settings = UserSettings()
    TreeView(store: ItemStore(settings: settings), settings: settings)
}
