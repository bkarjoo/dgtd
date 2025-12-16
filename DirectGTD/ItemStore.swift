import DirectGTDCore
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
    @Published var focusedItemId: String? = nil
    @Published var sqlSearchActive: Bool = false
    @Published var sqlSearchQuery: String = ""
    @Published var sqlSearchResults: [String] = [] // Item IDs from SQL query
    @Published var noteEditorShouldToggleEditMode: Bool = false
    @Published var noteEditorIsInEditMode: Bool = false
    @Published var showingSQLSearch: Bool = false
    @Published var treeHasKeyboardFocus: Bool = false
    @Published private(set) var savedSearches: [SavedSearch] = []

    // Time tracking state
    @Published private(set) var activeTimeEntries: [TimeEntry] = []  // All running timers
    @Published private(set) var itemTimeTotals: [String: Int] = [:]  // Cache: itemId -> total seconds

    private let repository: ItemRepository
    private let softDeleteService: SoftDeleteService
    let settings: UserSettings
    var undoManager: UndoManager?
    private var pendingCreatedItemIds: Set<String> = []
    private var databaseObserver: DirectGTDCore.DatabaseCancellable?

    init(settings: UserSettings, repository: ItemRepository = ItemRepository(), database: DatabaseProvider = Database.shared) {
        self.settings = settings
        self.repository = repository
        // Initialize SoftDeleteService with the same database provider as the repository
        self.softDeleteService = SoftDeleteService(database: database)
        NSLog("ItemStore initialized - console is working!")
    }

    func loadItems() {
        do {
            items = try repository.getAllItems()
            loadTags()
            loadTimeTracking()

            // Validate focusedItemId - clear if the item no longer exists
            if let focusedId = focusedItemId, !items.contains(where: { $0.id == focusedId }) {
                focusedItemId = nil
            }

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

    /// Creates an item with full control over all fields (used by API server)
    /// Returns the created item, or nil if creation failed
    @discardableResult
    func createItemWithDetails(
        title: String,
        parentId: String? = nil,
        itemType: ItemType = .task,
        notes: String? = nil
    ) -> Item? {
        let now = Int(Date().timeIntervalSince1970)

        // Calculate sort order based on siblings
        let siblings = items.filter { $0.parentId == parentId }
        let maxSortOrder = siblings.map { $0.sortOrder }.max() ?? -1

        let item = Item(
            title: title,
            itemType: itemType,
            notes: notes,
            parentId: parentId,
            sortOrder: maxSortOrder + 1,
            createdAt: now,
            modifiedAt: now
        )

        do {
            try repository.create(item)
            registerCreationUndo(for: item.id)
            loadItems()
            selectedItemId = item.id
            return items.first { $0.id == item.id } ?? item
        } catch {
            print("Error creating item: \(error)")
            return nil
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

    func updateNotes(id: String, notes: String?) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }

        do {
            let oldNotes = items[index].notes
            var item = items[index]
            item.notes = notes
            item.modifiedAt = Int(Date().timeIntervalSince1970)
            try repository.update(item)
            loadItems()

            // Register undo
            undoManager?.registerUndo(withTarget: self) { store in
                store.updateNotes(id: id, notes: oldNotes)
            }
            undoManager?.setActionName("Edit Notes")
        } catch {
            print("Error updating notes: \(error)")
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

            // Get all siblings (items with same parent as target, excluding dragged item)
            var siblings = items.filter { $0.parentId == targetItem.parentId && $0.id != draggedItemId }
                .sorted { $0.sortOrder < $1.sortOrder }

            // Find target's position in sibling list
            guard let targetIndex = siblings.firstIndex(where: { $0.id == targetItemId }) else { return }

            // Determine insertion point
            let insertionIndex = position == .above ? targetIndex : targetIndex + 1

            // Check if we have room to insert (need gap of at least 2 for integer division)
            var needsRenumbering = false
            if insertionIndex == 0 {
                // Inserting at beginning - check if we have room below first item
                if siblings.first!.sortOrder <= 0 {
                    needsRenumbering = true
                }
            } else if insertionIndex >= siblings.count {
                // Inserting at end - always have room
                needsRenumbering = false
            } else {
                // Inserting between two items - check if gap is large enough
                let prevSortOrder = siblings[insertionIndex - 1].sortOrder
                let nextSortOrder = siblings[insertionIndex].sortOrder
                if nextSortOrder - prevSortOrder < 2 {
                    needsRenumbering = true
                }
            }

            if needsRenumbering {
                // Renumber all siblings to create space
                // Use spacing of 1000 to allow many future insertions
                for (index, sibling) in siblings.enumerated() {
                    var updatedSibling = sibling
                    updatedSibling.sortOrder = index * 1000
                    do {
                        try repository.update(updatedSibling)
                    } catch {
                        print("Error renumbering sibling: \(error)")
                        return
                    }
                }
                // Reload siblings with new sort orders
                loadItems()
                siblings = items.filter { $0.parentId == targetItem.parentId && $0.id != draggedItemId }
                    .sorted { $0.sortOrder < $1.sortOrder }
            }

            // Calculate new sort order with guaranteed space
            if insertionIndex == 0 {
                updatedItem.sortOrder = siblings.first!.sortOrder - 1
            } else if insertionIndex >= siblings.count {
                updatedItem.sortOrder = siblings.last!.sortOrder + 1
            } else {
                let prevSortOrder = siblings[insertionIndex - 1].sortOrder
                let nextSortOrder = siblings[insertionIndex].sortOrder
                updatedItem.sortOrder = (prevSortOrder + nextSortOrder) / 2
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
        // Find selected item to determine positioning
        if let selectedId = selectedItemId,
           let selectedItem = items.first(where: { $0.id == selectedId }) {

            // If no type specified, use the same type as the selected item
            let typeToCreate = itemType == .unknown ? selectedItem.itemType : itemType
            let newItem = Item(title: "", itemType: typeToCreate)

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
            // No selection - create as first root item with unknown type
            let newItem = Item(title: "", itemType: itemType)
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

                // Select previous visible item, or next visible item, or nil
                let newOrderedItems = getAllItemsInOrder()

                // Try to find a visible item going backwards from the deleted position
                var newSelection: String? = nil
                for i in stride(from: currentIndex - 1, through: 0, by: -1) {
                    if i < newOrderedItems.count && isItemVisible(itemId: newOrderedItems[i].id) {
                        newSelection = newOrderedItems[i].id
                        break
                    }
                }

                // If no visible item found backwards, try forwards
                if newSelection == nil {
                    for i in currentIndex..<newOrderedItems.count {
                        if isItemVisible(itemId: newOrderedItems[i].id) {
                            newSelection = newOrderedItems[i].id
                            break
                        }
                    }
                }

                selectedItemId = newSelection
            } catch {
                print("Error deleting empty item: \(error)")
            }
        }

        editingItemId = nil
    }

    func indentItem() {
        NSLog("=== indentItem() called ===")
        guard let selectedId = selectedItemId,
              let selectedItem = items.first(where: { $0.id == selectedId }) else {
            NSLog("indentItem: no selected item")
            return
        }

        NSLog("indentItem: selectedItem.id=\(selectedItem.id), title='\(selectedItem.title ?? "untitled")', parentId=\(selectedItem.parentId ?? "nil")")

        let orderedItems = getAllItemsInOrder()
        NSLog("indentItem: getAllItemsInOrder returned \(orderedItems.count) items")

        guard let currentIndex = orderedItems.firstIndex(where: { $0.id == selectedId }),
              currentIndex > 0 else {
            NSLog("indentItem: item not found in ordered list or is first item - returning")
            return
        }

        NSLog("indentItem: currentIndex=\(currentIndex)")

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
        NSLog("indentItem: currentLevel=\(currentLevel)")

        // Find the first item above that is an actual sibling (same parent)
        var newParent: Item?
        for i in stride(from: currentIndex - 1, through: 0, by: -1) {
            let itemAbove = orderedItems[i]
            // Check if this item is an actual sibling (same parent)
            if itemAbove.parentId == selectedItem.parentId {
                newParent = itemAbove
                NSLog("indentItem: found actual sibling at index \(i): '\(itemAbove.title ?? "untitled")' (same parent)")
                break
            }
        }

        guard let parent = newParent else {
            NSLog("indentItem: NO sibling with same parent found - returning without changes")
            return
        }

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
            loadItems()
        } catch {
            print("Error indenting item: \(error)")
        }
    }

    // MARK: - Duplicate Item

    /// Shallow copy: duplicates the selected item and its immediate children only
    func duplicateItemShallow() {
        guard let selectedId = selectedItemId,
              let selectedItem = items.first(where: { $0.id == selectedId }) else { return }

        let now = Int(Date().timeIntervalSince1970)

        // Prepare siblings to update (shift sort order)
        var siblingsToUpdate: [Item] = []
        for sibling in items.filter({ $0.parentId == selectedItem.parentId && $0.sortOrder > selectedItem.sortOrder }) {
            var updated = sibling
            updated.sortOrder += 1
            siblingsToUpdate.append(updated)
        }

        // Create the new parent item
        let newItem = Item(
            title: selectedItem.title,
            itemType: selectedItem.itemType,
            notes: selectedItem.notes,
            parentId: selectedItem.parentId,
            sortOrder: selectedItem.sortOrder + 1,
            createdAt: now,
            modifiedAt: now,
            completedAt: nil,
            dueDate: selectedItem.dueDate,
            earliestStartTime: selectedItem.earliestStartTime
        )

        // Prepare all new items (parent + children)
        var newItems: [Item] = [newItem]
        var newItemTags: [ItemTag] = []

        // Copy immediate children (one level deep)
        let children = items.filter { $0.parentId == selectedId }.sorted { $0.sortOrder < $1.sortOrder }
        for child in children {
            let newChildId = UUID().uuidString

            let childCopy = Item(
                id: newChildId,
                title: child.title,
                itemType: child.itemType,
                notes: child.notes,
                parentId: newItem.id,
                sortOrder: child.sortOrder,
                createdAt: now,
                modifiedAt: now,
                completedAt: nil,
                dueDate: child.dueDate,
                earliestStartTime: child.earliestStartTime
            )
            newItems.append(childCopy)

            // Copy tags for this child
            let childTags = getTagsForItem(itemId: child.id)
            for tag in childTags {
                newItemTags.append(ItemTag(itemId: newChildId, tagId: tag.id))
            }
        }

        // Copy tags for the parent item
        let parentTags = getTagsForItem(itemId: selectedId)
        for tag in parentTags {
            newItemTags.append(ItemTag(itemId: newItem.id, tagId: tag.id))
        }

        // Execute everything in a single transaction
        do {
            try repository.duplicateItems(siblingsToUpdate: siblingsToUpdate, newItems: newItems, itemTags: newItemTags)

            registerCreationUndo(for: newItem.id)
            loadItems()
            selectedItemId = newItem.id

            // Expand the new item if it has children
            if !children.isEmpty {
                settings.expandedItemIds.insert(newItem.id)
            }
        } catch {
            print("Error duplicating item (shallow): \(error)")
        }
    }

    /// Deep copy: duplicates the selected item and all descendants recursively
    func duplicateItemDeep() {
        guard let selectedId = selectedItemId,
              let selectedItem = items.first(where: { $0.id == selectedId }) else { return }

        let now = Int(Date().timeIntervalSince1970)

        // Prepare siblings to update (shift sort order)
        var siblingsToUpdate: [Item] = []
        for sibling in items.filter({ $0.parentId == selectedItem.parentId && $0.sortOrder > selectedItem.sortOrder }) {
            var updated = sibling
            updated.sortOrder += 1
            siblingsToUpdate.append(updated)
        }

        // Map from old ID to new ID for maintaining parent-child relationships
        var idMapping: [String: String] = [:]

        // Collect entire subtree
        let subtree = collectSubtree(itemId: selectedId)

        // Prepare all new items and tags
        var newItems: [Item] = []
        var newItemTags: [ItemTag] = []
        var expandedNewIds: Set<String> = []

        for originalItem in subtree {
            let newId = UUID().uuidString
            idMapping[originalItem.id] = newId

            // Determine new parent ID
            let newParentId: String?
            if originalItem.id == selectedId {
                // Root of subtree keeps original parent
                newParentId = selectedItem.parentId
            } else if let oldParentId = originalItem.parentId, let mappedParentId = idMapping[oldParentId] {
                newParentId = mappedParentId
            } else {
                newParentId = originalItem.parentId
            }

            let newItem = Item(
                id: newId,
                title: originalItem.title,
                itemType: originalItem.itemType,
                notes: originalItem.notes,
                parentId: newParentId,
                sortOrder: originalItem.id == selectedId ? selectedItem.sortOrder + 1 : originalItem.sortOrder,
                createdAt: now,
                modifiedAt: now,
                completedAt: nil,
                dueDate: originalItem.dueDate,
                earliestStartTime: originalItem.earliestStartTime
            )
            newItems.append(newItem)

            // Copy tags for this item
            let originalTags = getTagsForItem(itemId: originalItem.id)
            for tag in originalTags {
                newItemTags.append(ItemTag(itemId: newId, tagId: tag.id))
            }

            // Track which items should be expanded
            if settings.expandedItemIds.contains(originalItem.id) {
                expandedNewIds.insert(newId)
            }
        }

        // Execute everything in a single transaction
        do {
            try repository.duplicateItems(siblingsToUpdate: siblingsToUpdate, newItems: newItems, itemTags: newItemTags)

            let newRootId = idMapping[selectedId]!
            registerCreationUndo(for: newRootId)
            loadItems()
            selectedItemId = newRootId

            // Apply expansion state after successful commit
            for id in expandedNewIds {
                settings.expandedItemIds.insert(id)
            }
        } catch {
            print("Error duplicating item (deep): \(error)")
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
            loadItems()
        } catch {
            print("Error outdenting item: \(error)")
        }
    }

    func expandSelectedItem() {
        guard let selectedId = selectedItemId else { return }
        let hasChildren = items.contains { $0.parentId == selectedId }

        // If already expanded, focus the item
        if settings.expandedItemIds.contains(selectedId) {
            focusedItemId = selectedId
        } else {
            settings.expandedItemIds.insert(selectedId)
            // If no children, immediately focus
            if !hasChildren {
                focusedItemId = selectedId
            }
        }
    }

    func collapseSelectedItem() {
        guard let selectedId = selectedItemId else { return }
        let hasChildren = items.contains { $0.parentId == selectedId }

        // If this is the focused item, go to parent (unfocus)
        if focusedItemId == selectedId {
            goToParent()
            return
        }

        // If expanded, collapse it
        if settings.expandedItemIds.contains(selectedId) {
            settings.expandedItemIds.remove(selectedId)
            // If no children, immediately select parent
            if !hasChildren {
                if let item = items.first(where: { $0.id == selectedId }),
                   let parentId = item.parentId {
                    selectedItemId = parentId
                }
            }
        } else {
            // If already collapsed, select parent
            if let item = items.first(where: { $0.id == selectedId }),
               let parentId = item.parentId {
                selectedItemId = parentId
            }
        }
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

        // Save entire subtree for undo (descendants will be cascade soft-deleted)
        guard let itemToDelete = items.first(where: { $0.id == itemId }) else { return }
        let subtree = collectSubtree(itemId: itemId)

        // Save tag relationships for all items in subtree - propagate errors
        let itemIds = subtree.map { $0.id }
        guard let itemTags = try? repository.getItemTagsForItems(itemIds: itemIds) else {
            errorMessage = "Failed to retrieve tag relationships. Delete aborted to prevent data loss."
            return
        }

        // BEFORE deleting: determine what to select next (while item still exists)
        let visibleItems = getVisibleItemsInOrder()
        NSLog("deleteItem: visibleItems.count = \(visibleItems.count)")
        NSLog("deleteItem: itemToDelete.parentId = \(itemToDelete.parentId ?? "nil")")
        NSLog("deleteItem: focusedItemId = \(focusedItemId ?? "nil")")

        let visibleSiblings = visibleItems
            .filter { $0.parentId == itemToDelete.parentId && $0.id != itemId }
            .sorted { $0.sortOrder < $1.sortOrder }
        NSLog("deleteItem: visibleSiblings.count = \(visibleSiblings.count)")

        var newSelection: String? = nil

        // Previous visible sibling, then next visible sibling
        if let previous = visibleSiblings.last(where: { $0.sortOrder < itemToDelete.sortOrder }) {
            newSelection = previous.id
        } else if let next = visibleSiblings.first(where: { $0.sortOrder > itemToDelete.sortOrder }) {
            newSelection = next.id
        }

        // Fall back to parent if visible
        if newSelection == nil, let parentId = itemToDelete.parentId {
            if isItemVisible(itemId: parentId) {
                newSelection = parentId
            }
        }

        // Focus-aware fallback: prefer focused item or first visible in focus subtree
        if newSelection == nil, let focusedId = focusedItemId {
            // In focus mode: select focused item itself, or first visible item in subtree
            if isItemVisible(itemId: focusedId) {
                newSelection = focusedId
            }
            if newSelection == nil {
                newSelection = visibleItems.first { $0.id != itemId }?.id
            }
        }

        // Deleting a root item with no siblings - select nearest visible root
        if newSelection == nil {
            let visibleRoots = visibleItems
                .filter { $0.parentId == nil && $0.id != itemId }
                .sorted { $0.sortOrder < $1.sortOrder }

            if let previous = visibleRoots.last(where: { $0.sortOrder < itemToDelete.sortOrder }) {
                newSelection = previous.id
            } else if let next = visibleRoots.first(where: { $0.sortOrder > itemToDelete.sortOrder }) {
                newSelection = next.id
            }
        }

        // Ultimate fallback: first visible item
        if newSelection == nil {
            newSelection = visibleItems.first { $0.id != itemId }?.id
        }

        do {
            // Use soft-delete service instead of hard delete
            try softDeleteService.softDeleteItem(id: itemId)

            // Register undo only after successful delete - call restore to enable redo
            undoManager?.registerUndo(withTarget: self) { store in
                store.restoreSubtree(subtree: subtree, itemTags: itemTags, selectItemId: itemToDelete.id)
            }
            undoManager?.setActionName("Delete Item")

            loadItems()
            NSLog("deleteItem: newSelection = \(newSelection ?? "nil")")
            selectedItemId = newSelection
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

    private func getVisibleItemsInOrder() -> [Item] {
        getAllItemsInOrder().filter { isItemVisible(itemId: $0.id) }
    }

    func shouldShowItem(_ item: Item) -> Bool {
        // Filter by SQL search if active (takes precedence)
        if sqlSearchActive {
            return matchesSQLSearch(item)
        }

        // Filter by tag if active (takes precedence over completed check)
        if filteredByTag != nil {
            return matchesTagFilter(item)
        }

        // Hide completed tasks if showCompletedTasks is false
        if !settings.showCompletedTasks && item.itemType == .task && item.completedAt != nil {
            return false
        }

        return true
    }

    private func isItemVisible(itemId: String) -> Bool {
        guard let item = items.first(where: { $0.id == itemId }) else { return false }

        // Check if item passes filter/visibility rules
        guard shouldShowItem(item) else { return false }

        // Check if item is in focus subtree (when focus mode is active)
        guard isInFocusSubtree(itemId: itemId) else { return false }

        // Root items are visible if they pass shouldShowItem
        guard let parentId = item.parentId else { return true }

        // In focus mode: if parent is the focused item, this item is visible
        if let focusedId = focusedItemId, parentId == focusedId {
            return true
        }

        // When not in focus mode, parent must be expanded to see children
        if focusedItemId == nil {
            guard settings.expandedItemIds.contains(parentId) else { return false }
        }

        // Recursively check if parent is visible
        return isItemVisible(itemId: parentId)
    }

    // MARK: - Focus Navigation

    /// Whether the tree is currently in focus mode
    var isFocused: Bool {
        focusedItemId != nil
    }

    /// The title of the parent of the focused item (for back button display)
    var focusedItemParentTitle: String? {
        guard let focusedId = focusedItemId,
              let focusedItem = items.first(where: { $0.id == focusedId }),
              let parentId = focusedItem.parentId,
              let parent = items.first(where: { $0.id == parentId }) else {
            return nil
        }
        return parent.title
    }

    /// Navigate to parent of focused item (or back to root)
    func goToParent() {
        guard let focusedId = focusedItemId,
              let focusedItem = items.first(where: { $0.id == focusedId }) else {
            focusedItemId = nil
            return
        }
        focusedItemId = focusedItem.parentId
    }

    private func isInFocusSubtree(itemId: String) -> Bool {
        guard let focusedId = focusedItemId else { return true }

        // The focused item itself is always in the focus subtree
        if itemId == focusedId { return true }

        // Check if this item is a descendant of the focused item
        guard let focusedItem = items.first(where: { $0.id == focusedId }) else { return true }
        return isDescendant(of: focusedItem, itemId: itemId)
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
            // Undelete all items and their tag relationships (soft-deleted records still exist)
            let itemIds = subtree.map { $0.id }
            let itemTagKeys = itemTags.map { ($0.itemId, $0.tagId) }
            try repository.undeleteItemsWithTags(itemIds: itemIds, itemTagKeys: itemTagKeys)
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

    func matchesSQLSearch(_ item: Item) -> Bool {
        guard sqlSearchActive else {
            return true // No SQL search active
        }

        // Check if this item is in the SQL search results
        if sqlSearchResults.contains(item.id) {
            return true
        }

        // Check if any descendant is in the SQL search results (show parents of matching items)
        if hasDescendantInSQLResults(item, allItems: items) {
            return true
        }

        // Check if any ancestor is in the SQL search results (show descendants of matching items)
        if hasAncestorInSQLResults(item, allItems: items) {
            return true
        }

        return false
    }

    func hasDescendantInSQLResults(_ item: Item, allItems: [Item]) -> Bool {
        let children = allItems.filter { $0.parentId == item.id }
        for child in children {
            if sqlSearchResults.contains(child.id) || hasDescendantInSQLResults(child, allItems: allItems) {
                return true
            }
        }
        return false
    }

    func hasAncestorInSQLResults(_ item: Item, allItems: [Item]) -> Bool {
        var currentParentId = item.parentId

        while let parentId = currentParentId {
            if sqlSearchResults.contains(parentId) {
                return true
            }

            currentParentId = allItems.first(where: { $0.id == parentId })?.parentId
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

            // Use soft-delete service instead of hard delete
            try softDeleteService.softDeleteTag(id: tagId)
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
            // Undelete the tag and its item_tag associations (soft-deleted records still exist)
            try repository.undeleteTag(tagId: tag.id, itemIds: itemIds)

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

    // MARK: - SQL Search

    func loadSavedSearches() {
        do {
            savedSearches = try repository.getAllSavedSearches()
        } catch {
            print("Error loading saved searches: \(error)")
        }
    }

    func executeSQLSearch(query: String) async throws {
        // Execute query asynchronously (runs off main thread with timeout)
        let itemIds = try await repository.executeSQLQuery(query)

        // Update state on main actor
        await MainActor.run {
            sqlSearchQuery = query
            sqlSearchResults = itemIds
            sqlSearchActive = true

            // Clear tag filter (mutual exclusivity)
            filteredByTag = nil
        }
    }

    func clearSQLSearch() {
        sqlSearchActive = false
        sqlSearchQuery = ""
        sqlSearchResults = []
    }

    func requestNoteEditorToggleEditMode() {
        noteEditorShouldToggleEditMode.toggle()
    }

    func focusTreeView() {
        NotificationCenter.default.post(name: .focusTreeView, object: nil)
    }

    func saveSQLSearch(name: String, sql: String) throws {
        let search = SavedSearch(name: name, sql: sql)
        try repository.createSavedSearch(search)
        loadSavedSearches()
    }

    // MARK: - Time Tracking

    /// Loads active time entries and time totals for all items
    func loadTimeTracking() {
        do {
            // Load all active (running) time entries
            activeTimeEntries = try repository.getActiveTimeEntries()

            // Load time totals for all items in batch
            let itemIds = items.map { $0.id }
            itemTimeTotals = try repository.getTotalTimesForItems(itemIds: itemIds)
        } catch {
            print("Error loading time tracking data: \(error)")
        }
    }

    /// Starts a new timer for the specified item
    /// - Returns: The created TimeEntry, or nil if creation failed
    @discardableResult
    func startTimer(for itemId: String) -> TimeEntry? {
        let entry = TimeEntry(itemId: itemId)

        do {
            try repository.createTimeEntry(entry)
            activeTimeEntries.append(entry)
            return entry
        } catch {
            print("Error starting timer: \(error)")
            return nil
        }
    }

    /// Stops a running timer by entry ID
    /// - Returns: The stopped TimeEntry with duration, or nil if not found/failed
    @discardableResult
    func stopTimer(entryId: String) -> TimeEntry? {
        do {
            guard let stoppedEntry = try repository.stopTimeEntry(id: entryId) else {
                return nil
            }

            // Remove from active entries
            activeTimeEntries.removeAll { $0.id == entryId }

            // Update the cached total for this item
            if let duration = stoppedEntry.duration {
                itemTimeTotals[stoppedEntry.itemId, default: 0] += duration
            }

            return stoppedEntry
        } catch {
            print("Error stopping timer: \(error)")
            return nil
        }
    }

    /// Stops all running timers for a specific item
    func stopAllTimers(for itemId: String) {
        let entriesToStop = activeTimeEntries.filter { $0.itemId == itemId }
        for entry in entriesToStop {
            stopTimer(entryId: entry.id)
        }
    }

    /// Returns the active time entry for an item, if any
    func activeTimeEntry(for itemId: String) -> TimeEntry? {
        return activeTimeEntries.first { $0.itemId == itemId }
    }

    /// Returns all active time entries for an item (supports multiple concurrent timers)
    func activeTimeEntries(for itemId: String) -> [TimeEntry] {
        return activeTimeEntries.filter { $0.itemId == itemId }
    }

    /// Returns true if there's at least one running timer for the item
    func hasActiveTimer(for itemId: String) -> Bool {
        return activeTimeEntries.contains { $0.itemId == itemId }
    }

    /// Gets the total tracked time (in seconds) for an item (from cache)
    func totalTime(for itemId: String) -> Int {
        return itemTimeTotals[itemId] ?? 0
    }

    /// Gets all time entries for an item (for displaying history)
    func getTimeEntries(for itemId: String) -> [TimeEntry] {
        do {
            return try repository.getTimeEntriesForItem(itemId: itemId)
        } catch {
            print("Error fetching time entries: \(error)")
            return []
        }
    }

    /// Deletes a time entry by ID (soft-delete)
    func deleteTimeEntry(id: String) {
        do {
            // Get the entry first to update cache
            if let entry = try repository.getTimeEntry(id: id) {
                // Use soft-delete service instead of hard delete
                try softDeleteService.softDeleteTimeEntry(id: id)

                // Remove from active entries if it was running
                activeTimeEntries.removeAll { $0.id == id }

                // Update cached total if it had a duration
                if let duration = entry.duration {
                    let currentTotal = itemTimeTotals[entry.itemId] ?? 0
                    itemTimeTotals[entry.itemId] = max(0, currentTotal - duration)
                }
            }
        } catch {
            print("Error deleting time entry: \(error)")
        }
    }

    /// Toggles timer state for an item: starts if no active timer, stops if running
    /// - Returns: The affected TimeEntry (newly started or just stopped)
    @discardableResult
    func toggleTimer(for itemId: String) -> TimeEntry? {
        if let activeEntry = activeTimeEntry(for: itemId) {
            return stopTimer(entryId: activeEntry.id)
        } else {
            return startTimer(for: itemId)
        }
    }

    // MARK: - Query Functions

    /// Dashboard view: Returns combined data for Next-tagged items, urgent items, and overdue items
    struct DashboardData {
        let nextTaggedItems: [Item]
        let urgentItems: [Item]    // Due within 24 hours
        let overdueItems: [Item]
    }

    func getDashboard() -> DashboardData {
        let now = Int(Date().timeIntervalSince1970)
        let tomorrow = now + 86400

        // Get items with "Next" tag
        let nextTag = tags.first { $0.name.lowercased() == "next" }
        var nextTaggedItems: [Item] = []
        if let nextTag = nextTag {
            nextTaggedItems = items.filter { item in
                guard item.itemType == .task && item.completedAt == nil else { return false }
                return itemTags[item.id]?.contains { $0.id == nextTag.id } ?? false
            }
        }

        // Overdue items (past due date, not completed)
        let overdueItems = items.filter { item in
            guard item.itemType == .task && item.completedAt == nil else { return false }
            guard let dueDate = item.dueDate else { return false }
            return dueDate < now
        }.sorted { ($0.dueDate ?? 0) < ($1.dueDate ?? 0) }

        // Urgent items (due within 24 hours, not overdue, not completed)
        let urgentItems = items.filter { item in
            guard item.itemType == .task && item.completedAt == nil else { return false }
            guard let dueDate = item.dueDate else { return false }
            return dueDate >= now && dueDate < tomorrow
        }.sorted { ($0.dueDate ?? 0) < ($1.dueDate ?? 0) }

        return DashboardData(
            nextTaggedItems: nextTaggedItems,
            urgentItems: urgentItems,
            overdueItems: overdueItems
        )
    }

    /// Returns items that are past their due date
    func getOverdueItems() -> [Item] {
        let now = Int(Date().timeIntervalSince1970)
        return items.filter { item in
            guard item.itemType == .task && item.completedAt == nil else { return false }
            guard let dueDate = item.dueDate else { return false }
            return dueDate < now
        }.sorted { ($0.dueDate ?? 0) < ($1.dueDate ?? 0) }
    }

    /// Returns items due today
    func getItemsDueToday() -> [Item] {
        let calendar = Calendar.current
        let startOfDay = Int(calendar.startOfDay(for: Date()).timeIntervalSince1970)
        let endOfDay = startOfDay + 86400

        return items.filter { item in
            guard item.itemType == .task && item.completedAt == nil else { return false }
            guard let dueDate = item.dueDate else { return false }
            return dueDate >= startOfDay && dueDate < endOfDay
        }.sorted { ($0.dueDate ?? 0) < ($1.dueDate ?? 0) }
    }

    /// Returns items due tomorrow
    func getItemsDueTomorrow() -> [Item] {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let startOfTomorrow = Int(calendar.startOfDay(for: tomorrow).timeIntervalSince1970)
        let endOfTomorrow = startOfTomorrow + 86400

        return items.filter { item in
            guard item.itemType == .task && item.completedAt == nil else { return false }
            guard let dueDate = item.dueDate else { return false }
            return dueDate >= startOfTomorrow && dueDate < endOfTomorrow
        }.sorted { ($0.dueDate ?? 0) < ($1.dueDate ?? 0) }
    }

    /// Returns items due this week (from now until end of week)
    func getItemsDueThisWeek() -> [Item] {
        let calendar = Calendar.current
        let now = Int(Date().timeIntervalSince1970)

        // Get end of week (Sunday night or Saturday night depending on locale)
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        components.weekday = calendar.firstWeekday + 6  // End of week
        let endOfWeek = calendar.date(from: components)!
        let endOfWeekTimestamp = Int(calendar.startOfDay(for: endOfWeek).timeIntervalSince1970) + 86400

        return items.filter { item in
            guard item.itemType == .task && item.completedAt == nil else { return false }
            guard let dueDate = item.dueDate else { return false }
            return dueDate >= now && dueDate < endOfWeekTimestamp
        }.sorted { ($0.dueDate ?? 0) < ($1.dueDate ?? 0) }
    }

    /// Returns actionable tasks (not deferred, not completed)
    func getAvailableTasks() -> [Item] {
        let now = Int(Date().timeIntervalSince1970)

        return items.filter { item in
            guard item.itemType == .task && item.completedAt == nil else { return false }
            // Not deferred (no earliest start time or earliest start time has passed)
            if let earliestStart = item.earliestStartTime, earliestStart > now {
                return false
            }
            return true
        }.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Returns deferred tasks (earliest_start_time in the future)
    func getDeferredTasks() -> [Item] {
        let now = Int(Date().timeIntervalSince1970)

        return items.filter { item in
            guard item.itemType == .task && item.completedAt == nil else { return false }
            guard let earliestStart = item.earliestStartTime else { return false }
            return earliestStart > now
        }.sorted { ($0.earliestStartTime ?? 0) < ($1.earliestStartTime ?? 0) }
    }

    /// Returns completed tasks, optionally filtered by completion time
    /// - Parameter since: Optional timestamp. If provided, only returns tasks completed after this time
    func getCompletedTasks(since: Int? = nil) -> [Item] {
        return items.filter { item in
            guard item.itemType == .task else { return false }
            guard let completedAt = item.completedAt else { return false }
            if let since = since {
                return completedAt >= since
            }
            return true
        }.sorted { ($0.completedAt ?? 0) > ($1.completedAt ?? 0) }  // Most recently completed first
    }

    /// Returns oldest incomplete tasks (for finding neglected items)
    /// - Parameter limit: Maximum number of items to return
    func getOldestTasks(limit: Int = 20) -> [Item] {
        return items.filter { item in
            item.itemType == .task && item.completedAt == nil
        }
        .sorted { $0.createdAt < $1.createdAt }
        .prefix(limit)
        .map { $0 }
    }

    /// Returns projects that have no "Next" tagged items (stuck projects)
    /// A project is stuck if:
    /// - It has no "Next" tagged incomplete tasks
    /// - It is not tagged as "on-hold"
    func getStuckProjects() -> [Item] {
        let nextTag = tags.first { $0.name.lowercased() == "next" }
        let onHoldTagIds = Set(tags.filter { $0.name.lowercased() == "on-hold" }.map { $0.id })

        return items.filter { project in
            guard project.itemType == .project else { return false }

            // Exclude on-hold projects
            if let projectTags = itemTags[project.id],
               projectTags.contains(where: { onHoldTagIds.contains($0.id) }) {
                return false
            }

            // If no Next tag exists in the system, all non-on-hold projects are stuck
            guard let nextTag = nextTag else { return true }

            // Get all descendant tasks of this project
            let descendants = getDescendants(of: project.id)
            let incompleteTasks = descendants.filter { $0.itemType == .task && $0.completedAt == nil }

            // Check if any incomplete task has the "Next" tag
            let hasNextTaggedTask = incompleteTasks.contains { task in
                itemTags[task.id]?.contains { $0.id == nextTag.id } ?? false
            }

            // Stuck if no Next-tagged incomplete tasks
            return !hasNextTaggedTask
        }
    }

    /// Returns all descendants (children, grandchildren, etc.) of an item
    func getDescendants(of itemId: String) -> [Item] {
        var descendants: [Item] = []
        var queue = items.filter { $0.parentId == itemId }

        while !queue.isEmpty {
            let item = queue.removeFirst()
            descendants.append(item)
            queue.append(contentsOf: items.filter { $0.parentId == item.id })
        }

        return descendants
    }

    /// Returns items that have all of the specified tag names
    /// - Parameter tagNames: Array of tag names to filter by
    func getItemsByTagNames(_ tagNames: [String]) -> [Item] {
        let lowercasedNames = Set(tagNames.map { $0.lowercased() })
        let matchingTags = tags.filter { lowercasedNames.contains($0.name.lowercased()) }

        guard !matchingTags.isEmpty else { return [] }

        let matchingTagIds = Set(matchingTags.map { $0.id })

        return items.filter { item in
            guard let tags = itemTags[item.id] else { return false }
            let tagIds = Set(tags.map { $0.id })
            return matchingTagIds.allSatisfy { tagIds.contains($0) }
        }
    }

    // MARK: - Action Functions

    /// Archives an item by moving it to the Archive folder
    /// Creates the Archive folder if it doesn't exist
    /// - Returns: true if successful, false otherwise
    @discardableResult
    func archiveItem(id: String) -> Bool {
        guard var item = items.first(where: { $0.id == id }) else { return false }

        // Find or create Archive folder
        var archiveFolder = items.first { $0.title == "Archive" && $0.itemType == .folder && $0.parentId == nil }

        if archiveFolder == nil {
            // Create Archive folder at root level
            let now = Int(Date().timeIntervalSince1970)
            let rootItems = items.filter { $0.parentId == nil }
            let maxSortOrder = rootItems.map { $0.sortOrder }.max() ?? -1

            let newArchive = Item(
                title: "Archive",
                itemType: .folder,
                parentId: nil,
                sortOrder: maxSortOrder + 1,
                createdAt: now,
                modifiedAt: now
            )

            do {
                try repository.create(newArchive)
                loadItems()
                archiveFolder = items.first { $0.id == newArchive.id }
            } catch {
                print("Error creating Archive folder: \(error)")
                return false
            }
        }

        guard let archive = archiveFolder else { return false }

        // Move item to Archive
        let siblings = items.filter { $0.parentId == archive.id }
        let maxSortOrder = siblings.map { $0.sortOrder }.max() ?? -1

        item.parentId = archive.id
        item.sortOrder = maxSortOrder + 1
        item.modifiedAt = Int(Date().timeIntervalSince1970)

        do {
            try repository.update(item)
            loadItems()
            return true
        } catch {
            print("Error archiving item: \(error)")
            return false
        }
    }

    /// Completes multiple tasks at once
    /// - Parameter ids: Array of item IDs to complete
    /// - Returns: Number of items successfully completed
    @discardableResult
    func completeMultiple(ids: [String]) -> Int {
        var completedCount = 0
        let now = Int(Date().timeIntervalSince1970)

        for id in ids {
            guard var item = items.first(where: { $0.id == id }) else { continue }
            guard item.itemType == .task && item.completedAt == nil else { continue }

            item.completedAt = now
            item.modifiedAt = now

            do {
                try repository.update(item)
                completedCount += 1
            } catch {
                print("Error completing item \(id): \(error)")
            }
        }

        if completedCount > 0 {
            loadItems()
        }

        return completedCount
    }

    /// Creates an instance from a template
    /// Copies the template and all its children, removing template markers
    /// - Parameters:
    ///   - templateId: ID of the template to instantiate
    ///   - parentId: Optional parent ID for the new instance (nil = same parent as template)
    /// - Returns: The root item of the new instance, or nil on failure
    @discardableResult
    func instantiateTemplate(templateId: String, parentId: String? = nil) -> Item? {
        guard let template = items.first(where: { $0.id == templateId && $0.itemType == .template }) else {
            return nil
        }

        let now = Int(Date().timeIntervalSince1970)

        // Determine parent for new instance
        let targetParentId = parentId ?? template.parentId
        let siblings = items.filter { $0.parentId == targetParentId }
        let maxSortOrder = siblings.map { $0.sortOrder }.max() ?? -1

        // Create the root item (convert template to project)
        var rootItem = Item(
            title: template.title,
            itemType: .project,
            notes: template.notes,
            parentId: targetParentId,
            sortOrder: maxSortOrder + 1,
            createdAt: now,
            modifiedAt: now
        )

        do {
            try repository.create(rootItem)

            // Recursively copy children
            copyChildren(from: template.id, to: rootItem.id, now: now)

            // Copy tags from template to new root
            if let templateTags = itemTags[template.id] {
                for tag in templateTags {
                    try? repository.addTagToItem(itemId: rootItem.id, tagId: tag.id)
                }
            }

            loadItems()
            return items.first { $0.id == rootItem.id }
        } catch {
            print("Error instantiating template: \(error)")
            return nil
        }
    }

    /// Helper: Recursively copies children from one parent to another
    private func copyChildren(from sourceParentId: String, to targetParentId: String, now: Int) {
        let children = items.filter { $0.parentId == sourceParentId }.sorted { $0.sortOrder < $1.sortOrder }

        for (index, child) in children.enumerated() {
            // Convert template children to appropriate types
            let newType: ItemType
            switch child.itemType {
            case .template:
                newType = .project
            default:
                newType = child.itemType
            }

            let newChild = Item(
                title: child.title,
                itemType: newType,
                notes: child.notes,
                parentId: targetParentId,
                sortOrder: index,
                createdAt: now,
                modifiedAt: now,
                dueDate: child.dueDate,
                earliestStartTime: child.earliestStartTime
            )

            do {
                try repository.create(newChild)

                // Copy tags
                if let childTags = itemTags[child.id] {
                    for tag in childTags {
                        try? repository.addTagToItem(itemId: newChild.id, tagId: tag.id)
                    }
                }

                // Recursively copy grandchildren
                copyChildren(from: child.id, to: newChild.id, now: now)
            } catch {
                print("Error copying child \(child.id): \(error)")
            }
        }
    }

    /// Empties the trash by permanently deleting soft-deleted items
    /// - Parameter keepSince: Optional timestamp. Items deleted after this time are kept.
    /// - Returns: Number of items permanently deleted
    @discardableResult
    func emptyTrash(keepSince: Int? = nil) -> Int {
        do {
            let cutoff = keepSince ?? Int.max
            let deletedCount = try softDeleteService.permanentlyDeleteItemsOlderThan(cutoff)
            return deletedCount
        } catch {
            print("Error emptying trash: \(error)")
            return 0
        }
    }

    // MARK: - Ordering Functions

    /// Swaps the sort order of two items
    /// - Parameters:
    ///   - id1: First item ID
    ///   - id2: Second item ID
    /// - Returns: true if successful
    @discardableResult
    func swapItemOrder(id1: String, id2: String) -> Bool {
        guard var item1 = items.first(where: { $0.id == id1 }),
              var item2 = items.first(where: { $0.id == id2 }) else {
            return false
        }

        guard item1.parentId == item2.parentId else {
            return false
        }

        // Swap sort orders
        let temp = item1.sortOrder
        item1.sortOrder = item2.sortOrder
        item2.sortOrder = temp

        let now = Int(Date().timeIntervalSince1970)
        item1.modifiedAt = now
        item2.modifiedAt = now

        do {
            try repository.update(item1)
            try repository.update(item2)
            loadItems()
            return true
        } catch {
            print("Error swapping items: \(error)")
            return false
        }
    }

    /// Moves an item to a specific position among its siblings
    /// - Parameters:
    ///   - id: Item ID to move
    ///   - position: Zero-based position (0 = first)
    /// - Returns: true if successful
    @discardableResult
    func moveToPosition(id: String, position: Int) -> Bool {
        guard let item = items.first(where: { $0.id == id }) else { return false }

        var siblings = items
            .filter { $0.parentId == item.parentId && $0.id != id }
            .sorted { $0.sortOrder < $1.sortOrder }

        // Clamp position
        let targetPosition = max(0, min(position, siblings.count))

        // Insert at position
        siblings.insert(item, at: targetPosition)

        // Reassign sort orders
        let now = Int(Date().timeIntervalSince1970)
        do {
            for (index, var sibling) in siblings.enumerated() {
                if sibling.sortOrder != index {
                    sibling.sortOrder = index
                    sibling.modifiedAt = now
                    try repository.update(sibling)
                }
            }
            loadItems()
            return true
        } catch {
            print("Error moving to position: \(error)")
            return false
        }
    }

    /// Reorders all children of a parent based on provided order
    /// - Parameters:
    ///   - parentId: Parent item ID (nil for root items)
    ///   - orderedIds: Array of child IDs in desired order
    /// - Returns: true if successful
    @discardableResult
    func reorderChildren(parentId: String?, orderedIds: [String]) -> Bool {
        let currentChildren = items.filter { $0.parentId == parentId }
        let currentIds = Set(currentChildren.map { $0.id })
        let orderedIdSet = Set(orderedIds)

        guard currentChildren.count == orderedIds.count,
              currentIds == orderedIdSet else {
            return false
        }

        let now = Int(Date().timeIntervalSince1970)

        do {
            for (index, id) in orderedIds.enumerated() {
                guard var item = items.first(where: { $0.id == id && $0.parentId == parentId }) else {
                    continue
                }

                if item.sortOrder != index {
                    item.sortOrder = index
                    item.modifiedAt = now
                    try repository.update(item)
                }
            }
            loadItems()
            return true
        } catch {
            print("Error reordering children: \(error)")
            return false
        }
    }

    // MARK: - Tree/Hierarchy Functions

    /// Represents a node in the item tree
    struct TreeNode {
        let item: Item
        let children: [TreeNode]
        let depth: Int
        let tags: [Tag]
    }

    /// Builds a tree structure starting from a root
    /// - Parameters:
    ///   - rootId: Optional root item ID. If nil, builds from all root items.
    ///   - maxDepth: Maximum depth to traverse. nil = unlimited.
    /// - Returns: Array of root TreeNodes
    func getTree(rootId: String? = nil, maxDepth: Int? = nil) -> [TreeNode] {
        if let rootId = rootId {
            // Build tree from specific root
            guard let rootItem = items.first(where: { $0.id == rootId }) else {
                return []
            }
            return [buildTreeNode(item: rootItem, depth: 0, maxDepth: maxDepth)]
        } else {
            // Build from all root items
            let rootItems = items
                .filter { $0.parentId == nil }
                .sorted { $0.sortOrder < $1.sortOrder }

            return rootItems.map { buildTreeNode(item: $0, depth: 0, maxDepth: maxDepth) }
        }
    }

    /// Helper: Recursively builds a tree node
    private func buildTreeNode(item: Item, depth: Int, maxDepth: Int?) -> TreeNode {
        let childItems: [TreeNode]

        if let maxDepth = maxDepth, depth >= maxDepth {
            childItems = []
        } else {
            let children = items
                .filter { $0.parentId == item.id }
                .sorted { $0.sortOrder < $1.sortOrder }

            childItems = children.map { buildTreeNode(item: $0, depth: depth + 1, maxDepth: maxDepth) }
        }

        return TreeNode(
            item: item,
            children: childItems,
            depth: depth,
            tags: itemTags[item.id] ?? []
        )
    }
}
