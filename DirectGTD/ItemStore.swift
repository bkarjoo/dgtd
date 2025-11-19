import Foundation
import SwiftUI
import Combine

class ItemStore: ObservableObject {
    @Published private(set) var items: [Item] = []
    @Published var selectedItemId: String?
    @Published var editingItemId: String?
    @Published var showingQuickCapture: Bool = false
    private let repository = ItemRepository()
    let settings: UserSettings

    init(settings: UserSettings) {
        self.settings = settings
        NSLog("ItemStore initialized - console is working!")
    }

    func loadItems() {
        do {
            items = try repository.getAllItems()
        } catch {
            print("Error loading items: \(error)")
        }
    }

    func createItem(title: String) {
        guard !title.isEmpty else { return }

        do {
            let item = Item(title: title)
            try repository.create(item)
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
            loadItems()
            selectedItemId = item.id
        } catch {
            print("Error creating quick capture item: \(error)")
        }
    }

    func updateItemTitle(id: String, title: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }

        do {
            var item = items[index]
            item.title = title
            try repository.update(item)
            items[index] = item
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

    func toggleTaskCompletion(id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }

        do {
            var item = items[index]
            if item.completedAt == nil {
                // Mark as completed
                item.completedAt = Int(Date().timeIntervalSince1970)
            } else {
                // Mark as pending
                item.completedAt = nil
            }
            try repository.update(item)
            items[index] = item
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

        // Get all items in order before deletion
        let orderedItems = getAllItemsInOrder()
        guard let currentIndex = orderedItems.firstIndex(where: { $0.id == itemId }) else { return }

        do {
            try repository.delete(itemId: itemId)
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
}
