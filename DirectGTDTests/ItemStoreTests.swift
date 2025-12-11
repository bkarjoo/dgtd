import DirectGTDCore
import XCTest
import GRDB
@testable import DirectGTD

final class ItemStoreTests: XCTestCase {
    var testDB: TestDatabaseWrapper!
    var repository: ItemRepository!
    var itemStore: ItemStore!
    var settings: UserSettings!

    override func setUp() {
        super.setUp()
        testDB = TestDatabaseWrapper()
        repository = ItemRepository(database: testDB)
        settings = UserSettings()
        itemStore = ItemStore(settings: settings, repository: repository, database: testDB)
        itemStore.loadItems()
    }

    override func tearDown() {
        itemStore = nil
        settings = nil
        repository = nil
        testDB = nil
        super.tearDown()
    }

    // MARK: - Item Creation Tests

    func testCreateItem() throws {
        // Given - Empty store
        XCTAssertEqual(itemStore.items.count, 0)

        // When - Create an item
        itemStore.createItem(title: "New Task")

        // Then - Item should be created
        XCTAssertEqual(itemStore.items.count, 1)
        XCTAssertEqual(itemStore.items.first?.title, "New Task")
        XCTAssertEqual(itemStore.selectedItemId, itemStore.items.first?.id)
    }

    func testCreateItemWithEmptyTitle() throws {
        // Given - Empty store
        let initialCount = itemStore.items.count

        // When - Try to create item with empty title
        itemStore.createItem(title: "")

        // Then - No item should be created
        XCTAssertEqual(itemStore.items.count, initialCount)
    }

    func testCreateItemAfterSelected() throws {
        // Given - One existing item
        let firstItem = Item(id: "first", title: "First", itemType: .task, sortOrder: 0)
        try repository.create(firstItem)
        itemStore.loadItems()
        itemStore.selectedItemId = "first"

        // When - Create item after selected
        itemStore.createItemAfterSelected()

        // Then - New item should be created after the first
        XCTAssertEqual(itemStore.items.count, 2)
        let newItem = itemStore.items.first(where: { $0.id != "first" })
        XCTAssertNotNil(newItem)
        XCTAssertEqual(newItem?.sortOrder, 1)
        XCTAssertEqual(newItem?.parentId, firstItem.parentId)
        XCTAssertEqual(itemStore.selectedItemId, newItem?.id)
        XCTAssertEqual(itemStore.editingItemId, newItem?.id)
    }

    func testCreateItemAfterSelectedAsChild() throws {
        // Given - Parent with child
        let parent = Item(id: "parent", title: "Parent", itemType: .project, sortOrder: 0)
        let child = Item(id: "child", title: "Child", itemType: .task, parentId: "parent", sortOrder: 0)
        try repository.create(parent)
        try repository.create(child)
        itemStore.loadItems()
        itemStore.selectedItemId = "child"

        // When - Create item after the child
        itemStore.createItemAfterSelected()

        // Then - New item should be sibling of child
        let newItem = itemStore.items.first(where: { $0.id != "parent" && $0.id != "child" })
        XCTAssertNotNil(newItem)
        XCTAssertEqual(newItem?.parentId, "parent")
        XCTAssertEqual(newItem?.sortOrder, 1)
    }

    func testCreateFirstItemWhenNoneSelected() throws {
        // Given - Empty store with no selection
        XCTAssertNil(itemStore.selectedItemId)

        // When - Create item after selected
        itemStore.createItemAfterSelected()

        // Then - Item should be created as first root item
        XCTAssertEqual(itemStore.items.count, 1)
        let newItem = itemStore.items.first
        XCTAssertNotNil(newItem)
        XCTAssertNil(newItem?.parentId)
        XCTAssertEqual(newItem?.sortOrder, 0)
        XCTAssertEqual(itemStore.editingItemId, newItem?.id)
    }

    // MARK: - Editing Lifecycle Tests

    func testCancelEditingWithEmptyTitle() throws {
        // Given - Create an empty item
        itemStore.createItemAfterSelected()
        guard let newItemId = itemStore.editingItemId else {
            XCTFail("No item being edited")
            return
        }

        // When - Cancel editing
        itemStore.cancelEditing()

        // Then - Empty item should be deleted
        XCTAssertNil(itemStore.items.first(where: { $0.id == newItemId }))
        XCTAssertNil(itemStore.editingItemId)
    }

    func testCancelEditingWithNonEmptyTitle() throws {
        // Given - Item with title being edited
        let item = Item(id: "test", title: "Not Empty", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()
        itemStore.editingItemId = "test"

        // When - Cancel editing
        itemStore.cancelEditing()

        // Then - Item should remain
        XCTAssertNotNil(itemStore.items.first(where: { $0.id == "test" }))
        XCTAssertNil(itemStore.editingItemId)
    }

    func testCancelEditingSelectsPreviousItem() throws {
        // Given - Two items, editing the second empty one
        let first = Item(id: "first", title: "First", itemType: .task, sortOrder: 0)
        try repository.create(first)
        itemStore.loadItems()
        itemStore.selectedItemId = "first"
        itemStore.createItemAfterSelected()
        let secondId = itemStore.editingItemId

        // When - Cancel editing (deletes empty second item)
        itemStore.cancelEditing()

        // Then - First item should be selected
        XCTAssertEqual(itemStore.selectedItemId, "first")
        XCTAssertNil(itemStore.items.first(where: { $0.id == secondId }))
    }

    // MARK: - Indent/Outdent Tests

    func testIndentItem() throws {
        // Given - Two sibling items
        let item1 = Item(id: "item1", title: "Item 1", itemType: .task, sortOrder: 0)
        let item2 = Item(id: "item2", title: "Item 2", itemType: .task, sortOrder: 1)
        try repository.create(item1)
        try repository.create(item2)
        itemStore.loadItems()
        itemStore.selectedItemId = "item2"

        // When - Indent item2
        itemStore.indentItem()

        // Then - item2 should become child of item1
        let indentedItem = itemStore.items.first(where: { $0.id == "item2" })
        XCTAssertEqual(indentedItem?.parentId, "item1")
        XCTAssertTrue(settings.expandedItemIds.contains("item1"))
    }

    func testIndentItemWithExistingChildren() throws {
        // Given - item1 already has a child, item2 is sibling
        let item1 = Item(id: "item1", title: "Item 1", itemType: .project, sortOrder: 0)
        let child1 = Item(id: "child1", title: "Child 1", itemType: .task, parentId: "item1", sortOrder: 0)
        let item2 = Item(id: "item2", title: "Item 2", itemType: .task, sortOrder: 1)
        try repository.create(item1)
        try repository.create(child1)
        try repository.create(item2)
        itemStore.loadItems()
        itemStore.selectedItemId = "item2"

        // When - Indent item2
        itemStore.indentItem()

        // Then - item2 should become second child of item1
        let indentedItem = itemStore.items.first(where: { $0.id == "item2" })
        XCTAssertEqual(indentedItem?.parentId, "item1")
        XCTAssertEqual(indentedItem?.sortOrder, 1)
    }

    func testCannotIndentFirstItem() throws {
        // Given - Single item (nothing to indent under)
        let item = Item(id: "item1", title: "Item 1", itemType: .task, sortOrder: 0)
        try repository.create(item)
        itemStore.loadItems()
        itemStore.selectedItemId = "item1"

        // When - Try to indent
        itemStore.indentItem()

        // Then - Item should remain at root level
        let unchangedItem = itemStore.items.first(where: { $0.id == "item1" })
        XCTAssertNil(unchangedItem?.parentId)
    }

    func testOutdentItem() throws {
        // Given - Parent with child
        let parent = Item(id: "parent", title: "Parent", itemType: .project, sortOrder: 0)
        let child = Item(id: "child", title: "Child", itemType: .task, parentId: "parent", sortOrder: 0)
        try repository.create(parent)
        try repository.create(child)
        itemStore.loadItems()
        itemStore.selectedItemId = "child"

        // When - Outdent child
        itemStore.outdentItem()

        // Then - Child should become sibling of parent
        let outdentedItem = itemStore.items.first(where: { $0.id == "child" })
        XCTAssertNil(outdentedItem?.parentId)
        XCTAssertEqual(outdentedItem?.sortOrder, 1)
    }

    func testOutdentNestedItem() throws {
        // Given - Three level hierarchy: grandparent > parent > child
        let grandparent = Item(id: "gp", title: "Grandparent", itemType: .project, sortOrder: 0)
        let parent = Item(id: "parent", title: "Parent", itemType: .project, parentId: "gp", sortOrder: 0)
        let child = Item(id: "child", title: "Child", itemType: .task, parentId: "parent", sortOrder: 0)
        try repository.create(grandparent)
        try repository.create(parent)
        try repository.create(child)
        itemStore.loadItems()
        itemStore.selectedItemId = "child"

        // When - Outdent child
        itemStore.outdentItem()

        // Then - Child should become sibling of parent (under grandparent)
        let outdentedItem = itemStore.items.first(where: { $0.id == "child" })
        XCTAssertEqual(outdentedItem?.parentId, "gp")
        XCTAssertEqual(outdentedItem?.sortOrder, 1)
    }

    func testCannotOutdentRootItem() throws {
        // Given - Root level item
        let item = Item(id: "root", title: "Root", itemType: .task, sortOrder: 0)
        try repository.create(item)
        itemStore.loadItems()
        itemStore.selectedItemId = "root"

        // When - Try to outdent
        itemStore.outdentItem()

        // Then - Item should remain at root level
        let unchangedItem = itemStore.items.first(where: { $0.id == "root" })
        XCTAssertNil(unchangedItem?.parentId)
    }

    // MARK: - Item Ordering Tests

    func testItemsLoadedInCorrectOrder() throws {
        // Given - Multiple items with different sort orders
        let item3 = Item(id: "item3", title: "Third", itemType: .task, sortOrder: 2)
        let item1 = Item(id: "item1", title: "First", itemType: .task, sortOrder: 0)
        let item2 = Item(id: "item2", title: "Second", itemType: .task, sortOrder: 1)

        // Create in random order
        try repository.create(item3)
        try repository.create(item1)
        try repository.create(item2)

        // When - Load items
        itemStore.loadItems()

        // Then - Items should be in sort order
        XCTAssertEqual(itemStore.items.count, 3)
        XCTAssertEqual(itemStore.items[0].id, "item1")
        XCTAssertEqual(itemStore.items[1].id, "item2")
        XCTAssertEqual(itemStore.items[2].id, "item3")
    }

    func testCreateItemAdjustsSortOrderOfFollowingItems() throws {
        // Given - Two items
        let item1 = Item(id: "item1", title: "First", itemType: .task, sortOrder: 0)
        let item2 = Item(id: "item2", title: "Second", itemType: .task, sortOrder: 1)
        try repository.create(item1)
        try repository.create(item2)
        itemStore.loadItems()
        itemStore.selectedItemId = "item1"

        // When - Create item after first
        itemStore.createItemAfterSelected()

        // Then - Second item's sort order should be incremented
        let updatedItem2 = itemStore.items.first(where: { $0.id == "item2" })
        XCTAssertEqual(updatedItem2?.sortOrder, 2)
    }

    // MARK: - Drag and Drop Tests

    func testMoveItemBasic() throws {
        // Given - Two root items
        let item1 = Item(id: "item1", title: "Item 1", itemType: .project, sortOrder: 0)
        let item2 = Item(id: "item2", title: "Item 2", itemType: .task, sortOrder: 1)
        try repository.create(item1)
        try repository.create(item2)
        itemStore.loadItems()

        // When - Move item2 into item1
        itemStore.moveItem(draggedItemId: "item2", targetItemId: "item1", position: .into)

        // Then - item2 should be child of item1
        let movedItem = itemStore.items.first(where: { $0.id == "item2" })
        XCTAssertEqual(movedItem?.parentId, "item1")
        XCTAssertEqual(movedItem?.sortOrder, 0)
    }

    func testMoveItemPreventsSelfDrop() throws {
        // Given - One item
        let item = Item(id: "item1", title: "Item 1", itemType: .task, sortOrder: 0)
        try repository.create(item)
        itemStore.loadItems()

        // When - Try to move item into itself
        itemStore.moveItem(draggedItemId: "item1", targetItemId: "item1", position: .into)

        // Then - Item should remain unchanged
        let unchangedItem = itemStore.items.first(where: { $0.id == "item1" })
        XCTAssertNil(unchangedItem?.parentId)
        XCTAssertEqual(unchangedItem?.sortOrder, 0)
    }

    func testMoveItemPreventsParentIntoDescendant() throws {
        // Given - Parent with child
        let parent = Item(id: "parent", title: "Parent", itemType: .project, sortOrder: 0)
        let child = Item(id: "child", title: "Child", itemType: .task, parentId: "parent", sortOrder: 0)
        try repository.create(parent)
        try repository.create(child)
        itemStore.loadItems()

        // When - Try to move parent into its own child
        itemStore.moveItem(draggedItemId: "parent", targetItemId: "child", position: .into)

        // Then - Parent should remain unchanged
        let unchangedParent = itemStore.items.first(where: { $0.id == "parent" })
        XCTAssertNil(unchangedParent?.parentId)
    }

    func testMoveItemExpandsTarget() throws {
        // Given - Two items, target is collapsed
        let target = Item(id: "target", title: "Target", itemType: .project, sortOrder: 0)
        let item = Item(id: "item", title: "Item", itemType: .task, sortOrder: 1)
        try repository.create(target)
        try repository.create(item)
        itemStore.loadItems()
        settings.expandedItemIds.remove("target")

        // When - Move item into target
        itemStore.moveItem(draggedItemId: "item", targetItemId: "target", position: .into)

        // Then - Target should be expanded
        XCTAssertTrue(settings.expandedItemIds.contains("target"))
    }

    func testMoveItemUndoRedo() throws {
        // Given - Two root items with undo manager
        let item1 = Item(id: "item1", title: "Item 1", itemType: .project, sortOrder: 0)
        let item2 = Item(id: "item2", title: "Item 2", itemType: .task, sortOrder: 1)
        try repository.create(item1)
        try repository.create(item2)
        itemStore.loadItems()
        let undoManager = UndoManager()
        itemStore.undoManager = undoManager

        // When - Move item2 into item1
        itemStore.moveItem(draggedItemId: "item2", targetItemId: "item1", position: .into)
        XCTAssertTrue(undoManager.canUndo)

        // Then - Undo should restore original state
        undoManager.undo()
        let restoredItem = itemStore.items.first(where: { $0.id == "item2" })
        XCTAssertNil(restoredItem?.parentId)
        XCTAssertEqual(restoredItem?.sortOrder, 1)

        // And - Redo should reapply the move
        XCTAssertTrue(undoManager.canRedo)
        undoManager.redo()
        let removedItem = itemStore.items.first(where: { $0.id == "item2" })
        XCTAssertEqual(removedItem?.parentId, "item1")
    }

    func testCanDropItemValidCases() throws {
        // Given - Parent with two children
        let parent = Item(id: "parent", title: "Parent", itemType: .project, sortOrder: 0)
        let child1 = Item(id: "child1", title: "Child 1", itemType: .task, parentId: "parent", sortOrder: 0)
        let child2 = Item(id: "child2", title: "Child 2", itemType: .task, parentId: "parent", sortOrder: 1)
        try repository.create(parent)
        try repository.create(child1)
        try repository.create(child2)
        itemStore.loadItems()

        // Then - Valid drops should return true
        XCTAssertTrue(itemStore.canDropItem(draggedItemId: "child1", onto: "child2", position: .into))
        XCTAssertTrue(itemStore.canDropItem(draggedItemId: "child2", onto: "child1", position: .into))
    }

    func testCanDropItemInvalidCases() throws {
        // Given - Parent with child
        let parent = Item(id: "parent", title: "Parent", itemType: .project, sortOrder: 0)
        let child = Item(id: "child", title: "Child", itemType: .task, parentId: "parent", sortOrder: 0)
        try repository.create(parent)
        try repository.create(child)
        itemStore.loadItems()

        // Then - Invalid drops should return false
        // Self-drop
        XCTAssertFalse(itemStore.canDropItem(draggedItemId: "parent", onto: "parent", position: .into))
        // Parent into descendant
        XCTAssertFalse(itemStore.canDropItem(draggedItemId: "parent", onto: "child", position: .into))
        // Nil dragged item
        XCTAssertFalse(itemStore.canDropItem(draggedItemId: nil, onto: "parent", position: .into))
        // Non-existent dragged item
        XCTAssertFalse(itemStore.canDropItem(draggedItemId: "nonexistent", onto: "parent", position: .into))
        // Non-existent target
        XCTAssertFalse(itemStore.canDropItem(draggedItemId: "child", onto: "nonexistent", position: .into))
    }

    func testMoveItemSortOrderAssignment() throws {
        // Given - Target with existing children
        let target = Item(id: "target", title: "Target", itemType: .project, sortOrder: 0)
        let existingChild1 = Item(id: "child1", title: "Child 1", itemType: .task, parentId: "target", sortOrder: 0)
        let existingChild2 = Item(id: "child2", title: "Child 2", itemType: .task, parentId: "target", sortOrder: 1)
        let newItem = Item(id: "new", title: "New", itemType: .task, sortOrder: 1)
        try repository.create(target)
        try repository.create(existingChild1)
        try repository.create(existingChild2)
        try repository.create(newItem)
        itemStore.loadItems()

        // When - Move new item into target
        itemStore.moveItem(draggedItemId: "new", targetItemId: "target", position: .into)

        // Then - New item should get sortOrder 2 (max + 1)
        let movedItem = itemStore.items.first(where: { $0.id == "new" })
        XCTAssertEqual(movedItem?.parentId, "target")
        XCTAssertEqual(movedItem?.sortOrder, 2)
    }

    // MARK: - Date Tests

    func testUpdateDueDate() throws {
        // Given - Create an item
        let item = Item(id: "test", title: "Test", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        // When - Set due date
        let dueDate = Int(Date().timeIntervalSince1970)
        itemStore.updateDueDate(id: "test", dueDate: dueDate)

        // Then - Due date should be set
        let updatedItem = itemStore.items.first(where: { $0.id == "test" })
        XCTAssertEqual(updatedItem?.dueDate, dueDate)
    }

    func testClearDueDate() throws {
        // Given - Create an item with due date
        let dueDate = Int(Date().timeIntervalSince1970)
        let item = Item(id: "test", title: "Test", itemType: .task, dueDate: dueDate)
        try repository.create(item)
        itemStore.loadItems()

        // When - Clear due date
        itemStore.updateDueDate(id: "test", dueDate: nil)

        // Then - Due date should be cleared
        let updatedItem = itemStore.items.first(where: { $0.id == "test" })
        XCTAssertNil(updatedItem?.dueDate)
    }

    func testUpdateDueDateUndo() throws {
        // Given - Create an item
        let item = Item(id: "test", title: "Test", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()
        itemStore.undoManager = UndoManager()

        // When - Set due date and undo
        let dueDate = Int(Date().timeIntervalSince1970)
        itemStore.updateDueDate(id: "test", dueDate: dueDate)
        itemStore.undoManager?.undo()

        // Then - Due date should be cleared
        let updatedItem = itemStore.items.first(where: { $0.id == "test" })
        XCTAssertNil(updatedItem?.dueDate)
    }

    func testUpdateEarliestStartTime() throws {
        // Given - Create an item
        let item = Item(id: "test", title: "Test", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        // When - Set earliest start time
        let startTime = Int(Date().timeIntervalSince1970)
        itemStore.updateEarliestStartTime(id: "test", earliestStartTime: startTime)

        // Then - Earliest start time should be set
        let updatedItem = itemStore.items.first(where: { $0.id == "test" })
        XCTAssertEqual(updatedItem?.earliestStartTime, startTime)
    }

    func testClearEarliestStartTime() throws {
        // Given - Create an item with earliest start time
        let startTime = Int(Date().timeIntervalSince1970)
        let item = Item(id: "test", title: "Test", itemType: .task, earliestStartTime: startTime)
        try repository.create(item)
        itemStore.loadItems()

        // When - Clear earliest start time
        itemStore.updateEarliestStartTime(id: "test", earliestStartTime: nil)

        // Then - Earliest start time should be cleared
        let updatedItem = itemStore.items.first(where: { $0.id == "test" })
        XCTAssertNil(updatedItem?.earliestStartTime)
    }

    func testUpdateEarliestStartTimeUndo() throws {
        // Given - Create an item
        let item = Item(id: "test", title: "Test", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()
        itemStore.undoManager = UndoManager()

        // When - Set earliest start time and undo
        let startTime = Int(Date().timeIntervalSince1970)
        itemStore.updateEarliestStartTime(id: "test", earliestStartTime: startTime)
        itemStore.undoManager?.undo()

        // Then - Earliest start time should be cleared
        let updatedItem = itemStore.items.first(where: { $0.id == "test" })
        XCTAssertNil(updatedItem?.earliestStartTime)
    }

    func testUpdateDueDateUpdatesModifiedAt() throws {
        // Given - Create an item
        let item = Item(id: "test", title: "Test", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()
        let originalModifiedAt = itemStore.items.first(where: { $0.id == "test" })?.modifiedAt

        // Wait to ensure time difference in integer seconds
        Thread.sleep(forTimeInterval: 1.1)

        // When - Set due date
        let dueDate = Int(Date().timeIntervalSince1970)
        itemStore.updateDueDate(id: "test", dueDate: dueDate)

        // Then - modifiedAt should be updated
        let updatedItem = itemStore.items.first(where: { $0.id == "test" })
        XCTAssertNotNil(updatedItem?.modifiedAt)
        if let original = originalModifiedAt, let updated = updatedItem?.modifiedAt {
            XCTAssertGreaterThan(updated, original, "modifiedAt should be updated to a later timestamp")
        }
    }

    func testUpdateEarliestStartTimeUpdatesModifiedAt() throws {
        // Given - Create an item
        let item = Item(id: "test", title: "Test", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()
        let originalModifiedAt = itemStore.items.first(where: { $0.id == "test" })?.modifiedAt

        // Wait to ensure time difference in integer seconds
        Thread.sleep(forTimeInterval: 1.1)

        // When - Set earliest start time
        let startTime = Int(Date().timeIntervalSince1970)
        itemStore.updateEarliestStartTime(id: "test", earliestStartTime: startTime)

        // Then - modifiedAt should be updated
        let updatedItem = itemStore.items.first(where: { $0.id == "test" })
        XCTAssertNotNil(updatedItem?.modifiedAt)
        if let original = originalModifiedAt, let updated = updatedItem?.modifiedAt {
            XCTAssertGreaterThan(updated, original, "modifiedAt should be updated to a later timestamp")
        }
    }
}
