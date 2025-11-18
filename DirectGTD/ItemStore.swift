import Foundation
import SwiftUI
import Combine

class ItemStore: ObservableObject {
    @Published private(set) var items: [Item] = []
    @Published var selectedItemId: String?
    @Published var editingItemId: String?
    @Published var expandedItemIds: Set<String> = []
    private let repository = ItemRepository()

    init() {
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

    func createItemAfterSelected() {
        let newItem = Item(title: "")

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

        // Get the item above
        let itemAbove = orderedItems[currentIndex - 1]

        // Make selected item a child of the item above
        var updatedItem = selectedItem
        updatedItem.parentId = itemAbove.id

        // Find the highest sortOrder among existing children of the new parent
        let existingChildren = items.filter { $0.parentId == itemAbove.id }
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
        guard let selectedId = selectedItemId,
              let selectedItem = items.first(where: { $0.id == selectedId }),
              let parentId = selectedItem.parentId,
              let parent = items.first(where: { $0.id == parentId }) else { return }

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
