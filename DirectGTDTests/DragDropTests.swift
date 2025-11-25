import XCTest
@testable import DirectGTD

final class DragDropTests: XCTestCase {
    var itemStore: ItemStore!
    var repository: ItemRepository!
    var undoManager: UndoManager!

    override func setUp() {
        super.setUp()
        let testDb = TestDatabaseWrapper()
        repository = ItemRepository(database: testDb)
        let settings = UserSettings()
        itemStore = ItemStore(settings: settings, repository: repository)
        undoManager = UndoManager()
        itemStore.undoManager = undoManager
    }

    override func tearDown() {
        itemStore = nil
        repository = nil
        undoManager = nil
        super.tearDown()
    }

    // MARK: - canDropItem Tests

    func testCanDropItemReturnsFalseWhenDraggedItemIdIsNil() throws {
        // Given: A target item
        let target = Item(id: "target", title: "Target", itemType: .project)
        try repository.create(target)
        itemStore.loadItems()

        // When: Checking if nil can be dropped
        let canDrop = itemStore.canDropItem(draggedItemId: nil, onto: target.id)

        // Then: Returns false
        XCTAssertFalse(canDrop)
    }

    func testCanDropItemReturnsFalseWhenDraggedItemDoesNotExist() throws {
        // Given: A target item
        let target = Item(id: "target", title: "Target", itemType: .project)
        try repository.create(target)
        itemStore.loadItems()

        // When: Checking if non-existent item can be dropped
        let canDrop = itemStore.canDropItem(draggedItemId: "nonexistent", onto: target.id)

        // Then: Returns false
        XCTAssertFalse(canDrop)
    }

    func testCanDropItemReturnsFalseWhenTargetDoesNotExist() throws {
        // Given: A dragged item
        let dragged = Item(id: "dragged", title: "Dragged", itemType: .task)
        try repository.create(dragged)
        itemStore.loadItems()

        // When: Checking if item can be dropped onto non-existent target
        let canDrop = itemStore.canDropItem(draggedItemId: dragged.id, onto: "nonexistent")

        // Then: Returns false
        XCTAssertFalse(canDrop)
    }

    func testCanDropItemReturnsFalseWhenDroppingIntoItself() throws {
        // Given: An item
        let item = Item(id: "item", title: "Item", itemType: .project)
        try repository.create(item)
        itemStore.loadItems()

        // When: Checking if item can be dropped onto itself
        let canDrop = itemStore.canDropItem(draggedItemId: item.id, onto: item.id)

        // Then: Returns false
        XCTAssertFalse(canDrop)
    }

    func testCanDropItemReturnsFalseWhenDroppingParentIntoDirectChild() throws {
        // Given: Parent and child hierarchy
        let parent = Item(id: "parent", title: "Parent", itemType: .project)
        var child = Item(id: "child", title: "Child", itemType: .task)
        child.parentId = "parent"

        try repository.create(parent)
        try repository.create(child)
        itemStore.loadItems()

        // When: Checking if parent can be dropped into its child
        let canDrop = itemStore.canDropItem(draggedItemId: parent.id, onto: child.id)

        // Then: Returns false (prevents circular hierarchy)
        XCTAssertFalse(canDrop)
    }

    func testCanDropItemReturnsFalseWhenDroppingParentIntoGrandchild() throws {
        // Given: Three-level hierarchy
        let grandparent = Item(id: "grandparent", title: "Grandparent", itemType: .project)
        var parent = Item(id: "parent", title: "Parent", itemType: .project)
        parent.parentId = "grandparent"
        var child = Item(id: "child", title: "Child", itemType: .task)
        child.parentId = "parent"

        try repository.create(grandparent)
        try repository.create(parent)
        try repository.create(child)
        itemStore.loadItems()

        // When: Checking if grandparent can be dropped into its grandchild
        let canDrop = itemStore.canDropItem(draggedItemId: grandparent.id, onto: child.id)

        // Then: Returns false (prevents circular hierarchy)
        XCTAssertFalse(canDrop)
    }

    func testCanDropItemReturnsTrueForValidDrop() throws {
        // Given: Two separate items (siblings)
        let item1 = Item(id: "item1", title: "Item 1", itemType: .project)
        let item2 = Item(id: "item2", title: "Item 2", itemType: .task)

        try repository.create(item1)
        try repository.create(item2)
        itemStore.loadItems()

        // When: Checking if item2 can be dropped into item1
        let canDrop = itemStore.canDropItem(draggedItemId: item2.id, onto: item1.id)

        // Then: Returns true
        XCTAssertTrue(canDrop)
    }

    func testCanDropItemReturnsTrueWhenMovingToDifferentBranch() throws {
        // Given: Two separate hierarchies
        let branch1 = Item(id: "branch1", title: "Branch 1", itemType: .project)
        var child1 = Item(id: "child1", title: "Child 1", itemType: .task)
        child1.parentId = "branch1"

        let branch2 = Item(id: "branch2", title: "Branch 2", itemType: .project)

        try repository.create(branch1)
        try repository.create(child1)
        try repository.create(branch2)
        itemStore.loadItems()

        // When: Checking if child1 can be dropped into branch2
        let canDrop = itemStore.canDropItem(draggedItemId: child1.id, onto: branch2.id)

        // Then: Returns true
        XCTAssertTrue(canDrop)
    }

    // MARK: - moveItem Tests

    func testMoveItemSuccessfullyMovesItemToNewParent() throws {
        // Given: Source and target items
        let source = Item(id: "source", title: "Source", itemType: .project)
        let target = Item(id: "target", title: "Target", itemType: .project)
        var child = Item(id: "child", title: "Child", itemType: .task)
        child.parentId = "source"

        try repository.create(source)
        try repository.create(target)
        try repository.create(child)
        itemStore.loadItems()

        // When: Moving child from source to target
        itemStore.moveItem(draggedItemId: child.id, targetItemId: target.id)

        // Then: Child's parent is updated
        let updatedChild = itemStore.items.first(where: { $0.id == child.id })
        XCTAssertEqual(updatedChild?.parentId, target.id)
    }

    func testMoveItemUpdatesSortOrderCorrectly() throws {
        // Given: Target with existing children
        let target = Item(id: "target", title: "Target", itemType: .project)
        var existingChild1 = Item(id: "existing1", title: "Existing 1", itemType: .task)
        existingChild1.parentId = "target"
        existingChild1.sortOrder = 0
        var existingChild2 = Item(id: "existing2", title: "Existing 2", itemType: .task)
        existingChild2.parentId = "target"
        existingChild2.sortOrder = 1

        let newChild = Item(id: "newChild", title: "New Child", itemType: .task)

        try repository.create(target)
        try repository.create(existingChild1)
        try repository.create(existingChild2)
        try repository.create(newChild)
        itemStore.loadItems()

        // When: Moving newChild to target
        itemStore.moveItem(draggedItemId: newChild.id, targetItemId: target.id)

        // Then: New child gets sortOrder after existing children
        let updatedChild = itemStore.items.first(where: { $0.id == newChild.id })
        XCTAssertEqual(updatedChild?.sortOrder, 2)
    }

    func testMoveItemExpandsTargetItem() throws {
        // Given: Source and target items
        let target = Item(id: "target", title: "Target", itemType: .project)
        let child = Item(id: "child", title: "Child", itemType: .task)

        try repository.create(target)
        try repository.create(child)
        itemStore.loadItems()

        // When: Moving child to target
        itemStore.moveItem(draggedItemId: child.id, targetItemId: target.id)

        // Then: Target is expanded (so dropped item is visible)
        XCTAssertTrue(itemStore.settings.expandedItemIds.contains(target.id))
    }

    func testMoveItemRegistersUndo() throws {
        // Given: Source and target items
        let source = Item(id: "source", title: "Source", itemType: .project)
        let target = Item(id: "target", title: "Target", itemType: .project)
        var child = Item(id: "child", title: "Child", itemType: .task)
        child.parentId = "source"
        child.sortOrder = 5

        try repository.create(source)
        try repository.create(target)
        try repository.create(child)
        itemStore.loadItems()

        // When: Moving child to target
        undoManager.beginUndoGrouping()
        itemStore.moveItem(draggedItemId: child.id, targetItemId: target.id)
        undoManager.endUndoGrouping()

        // Verify child was moved
        var updatedChild = itemStore.items.first(where: { $0.id == child.id })
        XCTAssertEqual(updatedChild?.parentId, target.id)

        // When: Undoing the move
        undoManager.undo()

        // Then: Child is back to original parent and sortOrder
        updatedChild = itemStore.items.first(where: { $0.id == child.id })
        XCTAssertEqual(updatedChild?.parentId, source.id)
        XCTAssertEqual(updatedChild?.sortOrder, 5)
    }

    func testMoveItemSupportsRedo() throws {
        // Given: Source and target items
        let source = Item(id: "source", title: "Source", itemType: .project)
        let target = Item(id: "target", title: "Target", itemType: .project)
        var child = Item(id: "child", title: "Child", itemType: .task)
        child.parentId = "source"

        try repository.create(source)
        try repository.create(target)
        try repository.create(child)
        itemStore.loadItems()

        // When: Moving, undoing, then redoing
        undoManager.beginUndoGrouping()
        itemStore.moveItem(draggedItemId: child.id, targetItemId: target.id)
        undoManager.endUndoGrouping()

        undoManager.undo()

        undoManager.redo()

        // Then: Child is back at target
        let updatedChild = itemStore.items.first(where: { $0.id == child.id })
        XCTAssertEqual(updatedChild?.parentId, target.id)
    }

    func testMoveItemReturnsEarlyWhenDraggedItemDoesNotExist() throws {
        // Given: A target item
        let target = Item(id: "target", title: "Target", itemType: .project)
        try repository.create(target)
        itemStore.loadItems()

        // When: Attempting to move non-existent item (should not crash)
        itemStore.moveItem(draggedItemId: "nonexistent", targetItemId: target.id)

        // Then: No changes occur (test completes without crash)
        XCTAssertTrue(true)
    }

    func testMoveItemReturnsEarlyWhenTargetDoesNotExist() throws {
        // Given: A dragged item
        let dragged = Item(id: "dragged", title: "Dragged", itemType: .task)
        try repository.create(dragged)
        itemStore.loadItems()

        let originalParent = dragged.parentId

        // When: Attempting to move to non-existent target
        itemStore.moveItem(draggedItemId: dragged.id, targetItemId: "nonexistent")

        // Then: Item remains unchanged
        let item = itemStore.items.first(where: { $0.id == dragged.id })
        XCTAssertEqual(item?.parentId, originalParent)
    }

    func testMoveItemReturnsEarlyWhenDroppingIntoItself() throws {
        // Given: An item
        let item = Item(id: "item", title: "Item", itemType: .project)
        try repository.create(item)
        itemStore.loadItems()

        let originalParent = item.parentId

        // When: Attempting to drop item into itself
        itemStore.moveItem(draggedItemId: item.id, targetItemId: item.id)

        // Then: Item remains unchanged
        let updatedItem = itemStore.items.first(where: { $0.id == item.id })
        XCTAssertEqual(updatedItem?.parentId, originalParent)
    }

    func testMoveItemReturnsEarlyWhenDroppingParentIntoDescendant() throws {
        // Given: Parent and child hierarchy
        let parent = Item(id: "parent", title: "Parent", itemType: .project)
        var child = Item(id: "child", title: "Child", itemType: .task)
        child.parentId = "parent"

        try repository.create(parent)
        try repository.create(child)
        itemStore.loadItems()

        // When: Attempting to drop parent into child
        itemStore.moveItem(draggedItemId: parent.id, targetItemId: child.id)

        // Then: Parent remains at root
        let updatedParent = itemStore.items.first(where: { $0.id == parent.id })
        XCTAssertNil(updatedParent?.parentId)
    }

    func testMoveItemToRootByMovingToItemWithNoParent() throws {
        // Given: Item with parent and a root-level target
        let parent = Item(id: "parent", title: "Parent", itemType: .project)
        var child = Item(id: "child", title: "Child", itemType: .task)
        child.parentId = "parent"
        let rootTarget = Item(id: "root", title: "Root", itemType: .project)

        try repository.create(parent)
        try repository.create(child)
        try repository.create(rootTarget)
        itemStore.loadItems()

        // When: Moving child to root-level target
        itemStore.moveItem(draggedItemId: child.id, targetItemId: rootTarget.id)

        // Then: Child's parent is root target
        let updatedChild = itemStore.items.first(where: { $0.id == child.id })
        XCTAssertEqual(updatedChild?.parentId, rootTarget.id)
    }
}
