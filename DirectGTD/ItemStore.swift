import Foundation
import SwiftUI
import Combine
import GRDB

enum DropPosition {
    case above
    case into
    case below
}

class ItemStore: ObservableObject {
    @Published private(set) var items: [Item] = []
    @Published var selectedItemId: String?
    @Published var editingItemId: String?
    @Published var showingQuickCapture: Bool = false
    @Published var dropTargetId: String? = nil
    @Published var dropTargetPosition: DropPosition? = nil
    @Published var completionDidChange: Bool = false
    @Published var errorMessage: String?
    @Published var searchText: String = ""
    @Published var isSearching: Bool = false
    @Published private(set) var tags: [Tag] = []
    @Published private(set) var itemTags: [String: [Tag]] = [:] // Cache: itemId -> tags
    @Published var filteredByTag: Tag? = nil
    @Published var draggedItemId: String? = nil
    private let repository: ItemRepository
    let settings: UserSettings
    var undoManager: UndoManager?
    private var pendingCreatedItemIds: Set<String> = []
    private var databaseObserver: DatabaseCancellable?

    init(settings: UserSettings, repository: ItemRepository = ItemRepository()) {
        self.settings = settings
        self.repository = repository
        NSLog("ItemStore initialized - console is working!")
    }

    func loadItems() {
        do {
            items = try repository.getAllItems()
            loadTags()

            // Start observation after first successful load
            if databaseObserver == nil {
                startDatabaseObservation()
            }
        } catch {
            print("Error loading items: \(error)")
        }
    }

    func loadTags() {
        do {
            // Load all tags
            tags = try repository.getAllTags()

            // Populate itemTags cache using existing repository method
            let itemIds = items.map { $0.id }
            let allItemTags = try repository.getItemTagsForItems(itemIds: itemIds)

            // Build cache: itemId -> [Tag]
            var cache: [String: [Tag]] = [:]
            for itemTag in allItemTags {
                if let tag = tags.first(where: { $0.id == itemTag.tagId }) {
                    cache[itemTag.itemId, default: []].append(tag)
                }
            }
            itemTags = cache
        } catch {
            print("Error loading tags: \(error)")
        }
    }

    private func startDatabaseObservation() {
        do {
            databaseObserver = try repository.observeDatabaseChanges { [weak self] in
                // Reload data when database changes (e.g., from MCP functions)
                // Main queue dispatch already handled in repository
                self?.loadItems()
            }
        } catch {
            print("Error starting database observation: \(error)")
        }
    }

    func createItem(title: String) {
        guard !title.isEmpty else { return }

        do {
            let item = Item(title: title)
            try repository.create(item)
            registerCreationUndo(for: item.id)
            loadItems()
            selectedItemId = item.id
        } catch {
            print("Error creating item: \(error)")
        }
    }

    func createQuickCaptureItem(title: String) {
        guard !title.isEmpty else { return }

        do {
            // Get quick capture folder ID from settings
            let quickCaptureFolderId = try? repository.getSetting(key: "quick_capture_folder_id")

            var item = Item(title: title, itemType: .task)
            item.parentId = quickCaptureFolderId

            // If there's a parent folder, find the highest sort order among siblings
            if let parentId = item.parentId {
                let siblings = items.filter { $0.parentId == parentId }
                let maxSortOrder = siblings.map { $0.sortOrder }.max() ?? -1
                item.sortOrder = maxSortOrder + 1

                // Auto-expand the parent folder
                settings.expandedItemIds.insert(parentId)
            } else {
                // No quick capture folder set - add to root
                let rootItems = items.filter { $0.parentId == nil }
                let maxSortOrder = rootItems.map { $0.sortOrder }.max() ?? -1
                item.sortOrder = maxSortOrder + 1
            }

            try repository.create(item)
            registerCreationUndo(for: item.id)
            loadItems()
            selectedItemId = item.id
        } catch {
            print("Error creating quick capture item: \(error)")
        }
    }

    func updateItemTitle(id: String, title: String?) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }

        do {
            let oldTitle = items[index].title
            var item = items[index]
            item.title = title

            try repository.update(item)
            items[index] = item

            // Register undo only after successful update
            if pendingCreatedItemIds.contains(id) {
                // Creation already has an undo entry that deletes the item.
                pendingCreatedItemIds.remove(id)
            } else {
                // Normal title edit - undo should revert title (enables redo)
                undoManager?.registerUndo(withTarget: self) { store in
                    store.updateItemTitle(id: id, title: oldTitle)
                }
                undoManager?.setActionName("Edit Title")
            }
        } catch {
            print("Error updating item: \(error)")
        }
    }

    func updateItemType(id: String, itemType: ItemType) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }

        do {
            var item = items[index]
            item.itemType = itemType
            try repository.update(item)
            items[index] = item
        } catch {
            print("Error updating item type: \(error)")
        }
    }

    func updateDueDate(id: String, dueDate: Int?) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }

        do {
            let oldDueDate = items[index].dueDate
            var item = items[index]
            item.dueDate = dueDate
            item.modifiedAt = Int(Date().timeIntervalSince1970)
            try repository.update(item)
            items[index] = item

            // Register undo
            undoManager?.registerUndo(withTarget: self) { store in
                store.updateDueDate(id: id, dueDate: oldDueDate)
            }
            undoManager?.setActionName(dueDate == nil ? "Clear Due Date" : "Set Due Date")
        } catch {
            print("Error updating due date: \(error)")
        }
    }

    func updateEarliestStartTime(id: String, earliestStartTime: Int?) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }

        do {
            let oldEarliestStartTime = items[index].earliestStartTime
            var item = items[index]
            item.earliestStartTime = earliestStartTime
            item.modifiedAt = Int(Date().timeIntervalSince1970)
            try repository.update(item)
            items[index] = item

            // Register undo
            undoManager?.registerUndo(withTarget: self) { store in
                store.updateEarliestStartTime(id: id, earliestStartTime: oldEarliestStartTime)
            }
            undoManager?.setActionName(earliestStartTime == nil ? "Clear Start Date" : "Set Start Date")
        } catch {
            print("Error updating earliest start time: \(error)")
        }
    }

    func toggleTaskCompletion(id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }

        do {
            var item = items[index]
            let wasCompleted = item.completedAt != nil

            if item.completedAt == nil {
                // Mark as completed
                item.completedAt = Int(Date().timeIntervalSince1970)
            } else {
                // Mark as pending
                item.completedAt = nil
            }

            try repository.update(item)
            items[index] = item
            completionDidChange.toggle()

            // Register undo only after successful update
            undoManager?.registerUndo(withTarget: self) { store in
                store.toggleTaskCompletion(id: id)
            }
            undoManager?.setActionName(wasCompleted ? "Mark Incomplete" : "Mark Complete")
        } catch {
            print("Error toggling task completion: \(error)")
        }
    }

    func moveItemUp() {
        guard let selectedId = selectedItemId,
              let selectedItem = items.first(where: { $0.id == selectedId }) else { return }

        // Get all siblings (items with same parent)
        let siblings = items.filter { $0.parentId == selectedItem.parentId }
            .sorted { $0.sortOrder < $1.sortOrder }

        guard let currentIndex = siblings.firstIndex(where: { $0.id == selectedId }),
              currentIndex > 0 else { return }

        // Swap sort order with previous sibling
        var itemToMove = selectedItem
        var previousItem = siblings[currentIndex - 1]

        let tempOrder = itemToMove.sortOrder
        itemToMove.sortOrder = previousItem.sortOrder
        previousItem.sortOrder = tempOrder

        do {
            try repository.update(itemToMove)
            try repository.update(previousItem)
            loadItems()
        } catch {
            print("Error moving item up: \(error)")
        }
    }

    func moveItemDown() {
        guard let selectedId = selectedItemId,
              let selectedItem = items.first(where: { $0.id == selectedId }) else { return }

        // Get all siblings (items with same parent)
        let siblings = items.filter { $0.parentId == selectedItem.parentId }
            .sorted { $0.sortOrder < $1.sortOrder }

        guard let currentIndex = siblings.firstIndex(where: { $0.id == selectedId }),
              currentIndex < siblings.count - 1 else { return }

        // Swap sort order with next sibling
        var itemToMove = selectedItem
        var nextItem = siblings[currentIndex + 1]

        let tempOrder = itemToMove.sortOrder
        itemToMove.sortOrder = nextItem.sortOrder
        nextItem.sortOrder = tempOrder

        do {
            try repository.update(itemToMove)
            try repository.update(nextItem)
            loadItems()
        } catch {
            print("Error moving item down: \(error)")
        }
    }

    func canDropItem(draggedItemId: String?, onto targetItemId: String, position: DropPosition) -> Bool {
        guard let draggedId = draggedItemId else { return false }
        guard let draggedItem = items.first(where: { $0.id == draggedId }) else { return false }

        // Verify target exists
        guard items.contains(where: { $0.id == targetItemId }) else { return false }

        // Prevent dropping an item into itself
        if draggedId == targetItemId {
            return false
        }

        // For .into position, prevent dropping a parent into its own descendant
        if position == .into && isDescendant(of: draggedItem, itemId: targetItemId) {
            return false
        }

        // For .above/.below, we're inserting as a sibling, so descendant check doesn't apply to target
        // But we still need to check if the target's parent would create a circular reference
        if position == .above || position == .below {
            guard let targetItem = items.first(where: { $0.id == targetItemId }) else { return false }
            if let targetParentId = targetItem.parentId {
                // Check if dragged item is an ancestor of the target's parent
                if isDescendant(of: draggedItem, itemId: targetParentId) {
                    return false
                }
            }
        }

        return true
    }

    func moveItem(draggedItemId: String, targetItemId: String, position: DropPosition) {
        guard let draggedItem = items.first(where: { $0.id == draggedItemId }) else { return }
        guard let targetItem = items.first(where: { $0.id == targetItemId }) else { return }

        // Prevent dropping an item into itself
        if draggedItemId == targetItemId {
            return
        }

        // Store original state for undo
        let originalParentId = draggedItem.parentId
        let originalSortOrder = draggedItem.sortOrder

        var updatedItem = draggedItem

        switch position {
        case .into:
            // Prevent dropping a parent into its own descendant
            if isDescendant(of: draggedItem, itemId: targetItemId) {
                return
            }

            // Expand the target item so the drop result is visible
            settings.expandedItemIds.insert(targetItemId)

            // Update the dragged item to become a child of the target
            updatedItem.parentId = targetItemId

            // Find the highest sortOrder among existing children of the target
            let existingChildren = items.filter { $0.parentId == targetItemId }
            let maxSortOrder = existingChildren.map { $0.sortOrder }.max() ?? -1
            updatedItem.sortOrder = maxSortOrder + 1

        case .above, .below:
            // Insert as sibling - same parent as target
            updatedItem.parentId = targetItem.parentId

            // Get all siblings (items with same parent as target)
            let siblings = items.filter { $0.parentId == targetItem.parentId && $0.id != draggedItemId }
                .sorted { $0.sortOrder < $1.sortOrder }

            // Find target's position in sibling list
            guard let targetIndex = siblings.firstIndex(where: { $0.id == targetItemId }) else { return }

            // Calculate new sort order
            if position == .above {
                // Insert before target
                if targetIndex == 0 {
                    // Insert at beginning
                    updatedItem.sortOrder = (siblings.first?.sortOrder ?? 0) - 1
                } else {
                    // Insert between previous and target
                    let prevSortOrder = siblings[targetIndex - 1].sortOrder
                    let targetSortOrder = siblings[targetIndex].sortOrder
                    updatedItem.sortOrder = (prevSortOrder + targetSortOrder) / 2
                }
            } else { // .below
                // Insert after target
                if targetIndex == siblings.count - 1 {
                    // Insert at end
                    updatedItem.sortOrder = (siblings.last?.sortOrder ?? 0) + 1
                } else {
                    // Insert between target and next
                    let targetSortOrder = siblings[targetIndex].sortOrder
                    let nextSortOrder = siblings[targetIndex + 1].sortOrder
                    updatedItem.sortOrder = (targetSortOrder + nextSortOrder) / 2
                }
            }

            // If parent is expanded, keep it that way
            if let parentId = updatedItem.parentId {
                if settings.expandedItemIds.contains(parentId) {
                    // Parent already expanded, no change needed
                }
            }
        }

        do {
            try repository.update(updatedItem)
            loadItems()

            // Register undo
            undoManager?.registerUndo(withTarget: self) { store in
                store.undoMoveItem(
                    itemId: draggedItemId,
                    toParentId: originalParentId,
                    sortOrder: originalSortOrder
                )
            }
            undoManager?.setActionName("Move Item")
        } catch {
            print("Error moving item: \(error)")
        }
    }

    private func undoMoveItem(itemId: String, toParentId: String?, sortOrder: Int) {
        guard var item = items.first(where: { $0.id == itemId }) else { return }

        let currentParentId = item.parentId
        let currentSortOrder = item.sortOrder

        item.parentId = toParentId
        item.sortOrder = sortOrder

        do {
            try repository.update(item)
            loadItems()

            // Register redo
            undoManager?.registerUndo(withTarget: self) { store in
                store.undoMoveItem(
                    itemId: itemId,
                    toParentId: currentParentId,
                    sortOrder: currentSortOrder
                )
            }
        } catch {
            print("Error undoing move: \(error)")
        }
    }

    private func isDescendant(of parent: Item, itemId: String) -> Bool {
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

    func createItemAfterSelected(withType itemType: ItemType = .unknown) {
        let newItem = Item(title: "", itemType: itemType)

        // Find selected item to determine positioning
        if let selectedId = selectedItemId,
           let selectedItem = items.first(where: { $0.id == selectedId }) {

            // New item gets same parent as selected item
            var itemToCreate = newItem
            itemToCreate.parentId = selectedItem.parentId
            itemToCreate.sortOrder = selectedItem.sortOrder + 1

            // Shift following siblings' sortOrder
            let siblings = items.filter { $0.parentId == selectedItem.parentId && $0.sortOrder > selectedItem.sortOrder }
            for var sibling in siblings {
                sibling.sortOrder += 1
                try? repository.update(sibling)
            }

            do {
                try repository.create(itemToCreate)
                registerCreationUndo(for: itemToCreate.id, coalesceWithFirstTitleEdit: true)
                loadItems()
                selectedItemId = itemToCreate.id
                editingItemId = itemToCreate.id
            } catch {
                print("Error creating item after selected: \(error)")
            }
        } else {
            // No selection - create as first root item
            var itemToCreate = newItem
            itemToCreate.sortOrder = 0

            // Shift all root items
            let rootItems = items.filter { $0.parentId == nil }
            for var root in rootItems {
                root.sortOrder += 1
                try? repository.update(root)
            }

            do {
                try repository.create(itemToCreate)
                registerCreationUndo(for: itemToCreate.id, coalesceWithFirstTitleEdit: true)
                loadItems()
                selectedItemId = itemToCreate.id
                editingItemId = itemToCreate.id
            } catch {
                print("Error creating first item: \(error)")
            }
        }
    }

    func cancelEditing() {
        guard let editId = editingItemId else { return }

        // If item has empty title, delete it
        if let item = items.first(where: { $0.id == editId }),
           item.title?.isEmpty ?? true {
            // Get all items in order before deletion
            let orderedItems = getAllItemsInOrder()
            guard let currentIndex = orderedItems.firstIndex(where: { $0.id == editId }) else {
                editingItemId = nil
                return
            }

            do {
                pendingCreatedItemIds.remove(editId)
                try repository.delete(itemId: editId)
                loadItems()

                // Select previous item, or next item, or nil
                let newOrderedItems = getAllItemsInOrder()
                if currentIndex > 0 && currentIndex - 1 < newOrderedItems.count {
                    selectedItemId = newOrderedItems[currentIndex - 1].id
                } else if !newOrderedItems.isEmpty {
                    selectedItemId = newOrderedItems[0].id
                } else {
                    selectedItemId = nil
                }
            } catch {
                print("Error deleting empty item: \(error)")
            }
        }

        editingItemId = nil
    }

    func indentItem() {
        guard let selectedId = selectedItemId,
              let selectedItem = items.first(where: { $0.id == selectedId }) else { return }

        let orderedItems = getAllItemsInOrder()
        guard let currentIndex = orderedItems.firstIndex(where: { $0.id == selectedId }),
              currentIndex > 0 else { return }

        // Get current item's level (depth)
        func getLevel(_ item: Item) -> Int {
            var level = 0
            var currentParentId = item.parentId
            while let parentId = currentParentId {
                level += 1
                currentParentId = items.first(where: { $0.id == parentId })?.parentId
            }
            return level
        }

        let currentLevel = getLevel(selectedItem)

        // Find the first item above that has the same level
        var newParent: Item?
        for i in stride(from: currentIndex - 1, through: 0, by: -1) {
            let itemAbove = orderedItems[i]
            if getLevel(itemAbove) == currentLevel {
                newParent = itemAbove
                break
            }
        }

        guard let parent = newParent else { return }

        // Make selected item a child of that item
        var updatedItem = selectedItem
        updatedItem.parentId = parent.id

        // Auto-expand the parent so the indented item stays visible
        settings.expandedItemIds.insert(parent.id)

        // Find the highest sortOrder among existing children of the new parent
        let existingChildren = items.filter { $0.parentId == parent.id }
        let maxSortOrder = existingChildren.map { $0.sortOrder }.max() ?? -1
        updatedItem.sortOrder = maxSortOrder + 1

        do {
            try repository.update(updatedItem)
            // Update in-memory
            if let index = items.firstIndex(where: { $0.id == selectedId }) {
                items[index] = updatedItem
            }
        } catch {
            print("Error indenting item: \(error)")
        }
    }

    func outdentItem() {
        NSLog("outdentItem() called")
        NSLog("selectedItemId: \(selectedItemId ?? "nil")")

        guard let selectedId = selectedItemId else {
            NSLog("outdentItem: no selected item")
            return
        }

        guard let selectedItem = items.first(where: { $0.id == selectedId }) else {
            NSLog("outdentItem: selected item not found in items")
            return
        }

        NSLog("selectedItem.parentId: \(selectedItem.parentId ?? "nil")")

        guard let parentId = selectedItem.parentId else {
            NSLog("outdentItem: item has no parent (already at root level)")
            return
        }

        guard let parent = items.first(where: { $0.id == parentId }) else {
            NSLog("outdentItem: parent item not found")
            return
        }

        NSLog("outdentItem: promoting item to sibling of parent")

        // Promote item to be sibling of its parent
        var updatedItem = selectedItem
        updatedItem.parentId = parent.parentId
        updatedItem.sortOrder = parent.sortOrder + 1

        // Shift siblings of parent that come after it
        let siblings = items.filter { $0.parentId == parent.parentId && $0.sortOrder > parent.sortOrder }
        for var sibling in siblings {
            sibling.sortOrder += 1
            try? repository.update(sibling)
        }

        do {
            try repository.update(updatedItem)
            // Update in-memory
            if let index = items.firstIndex(where: { $0.id == selectedId }) {
                items[index] = updatedItem
            }
        } catch {
            print("Error outdenting item: \(error)")
        }
    }

    func expandSelectedItem() {
        guard let selectedId = selectedItemId else { return }
        settings.expandedItemIds.insert(selectedId)
    }

    func collapseSelectedItem() {
        guard let selectedId = selectedItemId else { return }
        settings.expandedItemIds.remove(selectedId)
    }

    func deleteSelectedItem() {
        guard let itemId = selectedItemId else { return }
        deleteItem(itemId: itemId)
    }

    private func registerCreationUndo(for itemId: String, coalesceWithFirstTitleEdit: Bool = false) {
        if coalesceWithFirstTitleEdit {
            pendingCreatedItemIds.insert(itemId)
        }
        undoManager?.registerUndo(withTarget: self) { store in
            store.deleteItem(itemId: itemId)
        }
        undoManager?.setActionName("Create Item")
    }

    private func deleteItem(itemId: String) {
        pendingCreatedItemIds.remove(itemId)
        // Get all items in order before deletion
        let orderedItems = getAllItemsInOrder()
        guard let currentIndex = orderedItems.firstIndex(where: { $0.id == itemId }) else { return }

        // Save entire subtree for undo (descendants will be cascade deleted)
        guard let itemToDelete = items.first(where: { $0.id == itemId }) else { return }
        let subtree = collectSubtree(itemId: itemId)

        // Save tag relationships for all items in subtree - propagate errors
        let itemIds = subtree.map { $0.id }
        guard let itemTags = try? repository.getItemTagsForItems(itemIds: itemIds) else {
            errorMessage = "Failed to retrieve tag relationships. Delete aborted to prevent data loss."
            return
        }

        do {
            try repository.delete(itemId: itemId)

            // Register undo only after successful delete - call restore to enable redo
            undoManager?.registerUndo(withTarget: self) { store in
                store.restoreSubtree(subtree: subtree, itemTags: itemTags, selectItemId: itemToDelete.id)
            }
            undoManager?.setActionName("Delete Item")

            loadItems()

            // Select previous item, or next item, or nil
            let newOrderedItems = getAllItemsInOrder()
            if currentIndex > 0 && currentIndex - 1 < newOrderedItems.count {
                selectedItemId = newOrderedItems[currentIndex - 1].id
            } else if !newOrderedItems.isEmpty {
                selectedItemId = newOrderedItems[0].id
            } else {
                selectedItemId = nil
            }
        } catch {
            print("Error deleting item: \(error)")
        }
    }

    private func getAllItemsInOrder() -> [Item] {
        var result: [Item] = []
        let rootItems = items.filter { $0.parentId == nil }.sorted { $0.sortOrder < $1.sortOrder }

        func collectItems(_ items: [Item]) {
            for item in items {
                result.append(item)
                let children = self.items.filter { $0.parentId == item.id }.sorted { $0.sortOrder < $1.sortOrder }
                if !children.isEmpty {
                    collectItems(children)
                }
            }
        }

        collectItems(rootItems)
        return result
    }

    private func collectSubtree(itemId: String) -> [Item] {
        var result: [Item] = []

        func collectDescendants(_ id: String) {
            guard let item = items.first(where: { $0.id == id }) else { return }
            result.append(item)

            let children = items.filter { $0.parentId == id }.sorted { $0.sortOrder < $1.sortOrder }
            for child in children {
                collectDescendants(child.id)
            }
        }

        collectDescendants(itemId)
        return result
    }

    private func restoreSubtree(subtree: [Item], itemTags: [ItemTag], selectItemId: String) {
        do {
            pendingCreatedItemIds.subtract(subtree.map { $0.id })
            // Recreate all items and their tag relationships in a transaction
            try repository.createItemsWithTags(items: subtree, itemTags: itemTags)
            loadItems()
            selectedItemId = selectItemId

            // Register undo (which becomes redo) - delete the root item again
            undoManager?.registerUndo(withTarget: self) { store in
                store.deleteItem(itemId: selectItemId)
            }
            undoManager?.setActionName("Restore Item")
        } catch {
            print("Error restoring subtree: \(error)")
        }
    }

    // MARK: - Tag Management

    func getTagsForItem(itemId: String) -> [Tag] {
        return itemTags[itemId] ?? []
    }

    func matchesTagFilter(_ item: Item) -> Bool {
        guard let filterTag = filteredByTag else {
            return true // No filter active
        }

        // Check if this item has the filter tag
        let itemHasTag = getTagsForItem(itemId: item.id).contains { $0.id == filterTag.id }
        if itemHasTag {
            return true
        }

        // Check if any descendant has the filter tag (show parents of matching items)
        if hasDescendantWithTag(item, tagId: filterTag.id, allItems: items) {
            return true
        }

        return false
    }

    func hasDescendantWithTag(_ item: Item, tagId: String, allItems: [Item]) -> Bool {
        let children = allItems.filter { $0.parentId == item.id }
        for child in children {
            let childHasTag = getTagsForItem(itemId: child.id).contains { $0.id == tagId }
            if childHasTag || hasDescendantWithTag(child, tagId: tagId, allItems: allItems) {
                return true
            }
        }
        return false
    }

    func createTag(name: String, color: String) -> Tag? {
        guard !name.isEmpty else { return nil }

        let tag = Tag(name: name, color: color)
        do {
            try repository.createTag(tag)
            loadTags()

            // Register undo
            undoManager?.registerUndo(withTarget: self) { store in
                store.deleteTag(tagId: tag.id)
            }
            undoManager?.setActionName("Create Tag")

            return tag
        } catch {
            print("Error creating tag: \(error)")
            return nil
        }
    }

    func updateTag(tag: Tag) {
        do {
            let oldTag = tags.first(where: { $0.id == tag.id })
            try repository.updateTag(tag)
            loadTags()

            // Register undo
            if let old = oldTag {
                undoManager?.registerUndo(withTarget: self) { store in
                    store.updateTag(tag: old)
                }
                undoManager?.setActionName("Edit Tag")
            }
        } catch {
            print("Error updating tag: \(error)")
        }
    }

    func deleteTag(tagId: String) {
        guard let tag = tags.first(where: { $0.id == tagId }) else { return }

        do {
            // Get all items that use this tag for undo
            let affectedItemIds = itemTags.filter { $0.value.contains(where: { $0.id == tagId }) }.keys.map { $0 }

            // Clear filter if deleting the active filter tag
            let wasFilteredByThisTag = filteredByTag?.id == tagId
            if wasFilteredByThisTag {
                filteredByTag = nil
            }

            try repository.deleteTag(tagId: tagId)
            loadTags()

            // Register undo - preserve original tag with same ID and restore filter if needed
            undoManager?.registerUndo(withTarget: self) { store in
                store.restoreTag(tag: tag, itemIds: affectedItemIds, restoreAsFilter: wasFilteredByThisTag)
            }
            undoManager?.setActionName("Delete Tag")
        } catch {
            print("Error deleting tag: \(error)")
        }
    }

    private func restoreTag(tag: Tag, itemIds: [String], restoreAsFilter: Bool = false) {
        do {
            // Recreate tag with original ID (no undo recording)
            try repository.createTag(tag)

            // Re-associate with items (no undo recording)
            for itemId in itemIds {
                try repository.addTagToItem(itemId: itemId, tagId: tag.id)
            }

            loadTags()

            // Restore as filter if it was the active filter when deleted
            if restoreAsFilter {
                filteredByTag = tag
            }

            // Register undo (which becomes redo) - delete the tag again
            undoManager?.registerUndo(withTarget: self) { store in
                store.deleteTag(tagId: tag.id)
            }
            undoManager?.setActionName("Restore Tag")
        } catch {
            print("Error restoring tag: \(error)")
        }
    }

    func addTagToItem(itemId: String, tag: Tag) {
        do {
            try repository.addTagToItem(itemId: itemId, tagId: tag.id)
            loadTags()

            // Register undo
            undoManager?.registerUndo(withTarget: self) { store in
                store.removeTagFromItem(itemId: itemId, tagId: tag.id)
            }
            undoManager?.setActionName("Add Tag")
        } catch {
            print("Error adding tag to item: \(error)")
        }
    }

    func removeTagFromItem(itemId: String, tagId: String) {
        guard let tag = tags.first(where: { $0.id == tagId }) else { return }

        do {
            try repository.removeTagFromItem(itemId: itemId, tagId: tagId)
            loadTags()

            // Register undo
            undoManager?.registerUndo(withTarget: self) { store in
                store.addTagToItem(itemId: itemId, tag: tag)
            }
            undoManager?.setActionName("Remove Tag")
        } catch {
            print("Error removing tag from item: \(error)")
        }
    }

    // MARK: - Search

    var searchResults: [Item] {
        guard !searchText.isEmpty else { return [] }
        return items.filter { item in
            item.title?.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }

    func getItemPath(itemId: String) -> String {
        var path: [String] = []
        var currentId: String? = itemId

        while let id = currentId {
            if let item = items.first(where: { $0.id == id }) {
                if let title = item.title, !title.isEmpty {
                    path.insert(title, at: 0)
                }
                currentId = item.parentId
            } else {
                break
            }
        }

        return path.joined(separator: " > ")
    }
}
