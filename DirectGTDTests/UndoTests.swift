import XCTest
import GRDB
@testable import DirectGTD

final class UndoTests: XCTestCase {
    var testDB: TestDatabaseWrapper!
    var repository: ItemRepository!
    var itemStore: ItemStore!
    var undoManager: UndoManager!
    var settings: UserSettings!

    override func setUp() {
        super.setUp()
        testDB = TestDatabaseWrapper()
        repository = ItemRepository(database: testDB)
        settings = UserSettings()
        itemStore = ItemStore(settings: settings, repository: repository)

        undoManager = UndoManager()
        itemStore.undoManager = undoManager

        itemStore.loadItems()
    }

    override func tearDown() {
        undoManager = nil
        itemStore = nil
        settings = nil
        repository = nil
        testDB = nil
        super.tearDown()
    }

    // MARK: - Undo Title Update Tests

    func testUndoTitleUpdate() throws {
        // Given - Create an item
        let item = Item(id: "test-1", title: "Original Title", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        // When - Update the title
        itemStore.updateItemTitle(id: "test-1", title: "New Title")

        // Then - Verify title changed
        let updatedItem = itemStore.items.first(where: { $0.id == "test-1" })
        XCTAssertEqual(updatedItem?.title, "New Title")

        // When - Undo
        XCTAssertTrue(undoManager.canUndo, "Should be able to undo")
        undoManager.undo()

        // Then - Verify title reverted
        let revertedItem = itemStore.items.first(where: { $0.id == "test-1" })
        XCTAssertEqual(revertedItem?.title, "Original Title")
    }

    func testUndoActionNameForTitleUpdate() throws {
        // Given
        let item = Item(id: "test-1", title: "Original", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        // When
        itemStore.updateItemTitle(id: "test-1", title: "Updated")

        // Then
        XCTAssertEqual(undoManager.undoActionName, "Edit Title")
    }

    func testRedoTitleUpdate() throws {
        // Given - Create and update item
        let item = Item(id: "test-1", title: "Original", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()
        itemStore.updateItemTitle(id: "test-1", title: "Updated")

        // When - Undo then redo
        undoManager.undo()
        XCTAssertTrue(undoManager.canRedo, "Should be able to redo")
        undoManager.redo()

        // Then - Verify title is back to updated state
        let redoneItem = itemStore.items.first(where: { $0.id == "test-1" })
        XCTAssertEqual(redoneItem?.title, "Updated")
    }

    // MARK: - Undo Task Completion Tests

    func testUndoTaskCompletion() throws {
        // Given - Create a pending task
        let item = Item(id: "task-1", title: "Task", itemType: .task, completedAt: nil)
        try repository.create(item)
        itemStore.loadItems()

        // When - Mark as complete
        itemStore.toggleTaskCompletion(id: "task-1")

        // Then - Verify completed
        var completedTask = itemStore.items.first(where: { $0.id == "task-1" })
        XCTAssertNotNil(completedTask?.completedAt, "Task should be completed")

        // When - Undo
        XCTAssertTrue(undoManager.canUndo)
        undoManager.undo()

        // Then - Verify back to pending
        let pendingTask = itemStore.items.first(where: { $0.id == "task-1" })
        XCTAssertNil(pendingTask?.completedAt, "Task should be pending after undo")
    }

    func testUndoTaskUncompletion() throws {
        // Given - Create a completed task
        let completedTime = Int(Date().timeIntervalSince1970)
        let item = Item(id: "task-1", title: "Task", itemType: .task, completedAt: completedTime)
        try repository.create(item)
        itemStore.loadItems()

        // When - Mark as incomplete
        itemStore.toggleTaskCompletion(id: "task-1")

        // Then - Verify pending
        var pendingTask = itemStore.items.first(where: { $0.id == "task-1" })
        XCTAssertNil(pendingTask?.completedAt, "Task should be pending")

        // When - Undo
        undoManager.undo()

        // Then - Verify back to completed
        let completedTask = itemStore.items.first(where: { $0.id == "task-1" })
        XCTAssertNotNil(completedTask?.completedAt, "Task should be completed after undo")
    }

    func testUndoActionNameForTaskCompletion() throws {
        // Given - Pending task
        let item = Item(id: "task-1", title: "Task", itemType: .task, completedAt: nil)
        try repository.create(item)
        itemStore.loadItems()

        // When - Mark complete
        itemStore.toggleTaskCompletion(id: "task-1")

        // Then
        XCTAssertEqual(undoManager.undoActionName, "Mark Complete")
    }

    func testUndoActionNameForTaskUncompletion() throws {
        // Given - Completed task
        let completedTime = Int(Date().timeIntervalSince1970)
        let item = Item(id: "task-1", title: "Task", itemType: .task, completedAt: completedTime)
        try repository.create(item)
        itemStore.loadItems()

        // When - Mark incomplete
        itemStore.toggleTaskCompletion(id: "task-1")

        // Then
        XCTAssertEqual(undoManager.undoActionName, "Mark Incomplete")
    }

    // MARK: - Undo Delete Tests

    func testUndoDeleteSingleItem() throws {
        // Given - Create an item
        let item = Item(id: "delete-1", title: "To Delete", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()
        itemStore.selectedItemId = "delete-1"

        let itemCountBefore = itemStore.items.count

        // When - Delete the item
        itemStore.deleteSelectedItem()

        // Then - Verify deleted
        XCTAssertNil(itemStore.items.first(where: { $0.id == "delete-1" }))
        XCTAssertEqual(itemStore.items.count, itemCountBefore - 1)

        // When - Undo
        XCTAssertTrue(undoManager.canUndo)
        undoManager.undo()

        // Then - Verify restored
        let restoredItem = itemStore.items.first(where: { $0.id == "delete-1" })
        XCTAssertNotNil(restoredItem, "Item should be restored")
        XCTAssertEqual(restoredItem?.title, "To Delete")
        XCTAssertEqual(itemStore.items.count, itemCountBefore)
    }

    func testUndoDeleteItemWithChildren() throws {
        // Given - Create parent and children
        let parent = Item(id: "parent", title: "Parent", itemType: .project, sortOrder: 0)
        let child1 = Item(id: "child-1", title: "Child 1", itemType: .task, parentId: "parent", sortOrder: 0)
        let child2 = Item(id: "child-2", title: "Child 2", itemType: .task, parentId: "parent", sortOrder: 1)

        try repository.create(parent)
        try repository.create(child1)
        try repository.create(child2)
        itemStore.loadItems()
        itemStore.selectedItemId = "parent"

        let itemCountBefore = itemStore.items.count

        // When - Delete parent (cascades to children)
        itemStore.deleteSelectedItem()

        // Then - Verify all deleted
        XCTAssertNil(itemStore.items.first(where: { $0.id == "parent" }))
        XCTAssertNil(itemStore.items.first(where: { $0.id == "child-1" }))
        XCTAssertNil(itemStore.items.first(where: { $0.id == "child-2" }))

        // When - Undo
        undoManager.undo()

        // Then - Verify entire subtree restored
        XCTAssertNotNil(itemStore.items.first(where: { $0.id == "parent" }))
        XCTAssertNotNil(itemStore.items.first(where: { $0.id == "child-1" }))
        XCTAssertNotNil(itemStore.items.first(where: { $0.id == "child-2" }))
        XCTAssertEqual(itemStore.items.count, itemCountBefore)

        // Verify hierarchy is preserved
        let restoredChild1 = itemStore.items.first(where: { $0.id == "child-1" })
        XCTAssertEqual(restoredChild1?.parentId, "parent")
    }

    func testUndoActionNameForDelete() throws {
        // Given
        let item = Item(id: "delete-1", title: "Item", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()
        itemStore.selectedItemId = "delete-1"

        // When
        itemStore.deleteSelectedItem()

        // Then
        XCTAssertEqual(undoManager.undoActionName, "Delete Item")
    }

    // MARK: - Multiple Undo/Redo Tests

    func testMultipleUndoOperations() throws {
        // Given - Create an item
        let item = Item(id: "multi-1", title: "Original", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        // When - Perform multiple operations (each in its own undo group)
        itemStore.updateItemTitle(id: "multi-1", title: "First Update")
        undoManager.endUndoGrouping()  // End current group
        undoManager.beginUndoGrouping()  // Start new group

        itemStore.updateItemTitle(id: "multi-1", title: "Second Update")
        undoManager.endUndoGrouping()
        undoManager.beginUndoGrouping()

        itemStore.updateItemTitle(id: "multi-1", title: "Third Update")
        undoManager.endUndoGrouping()

        // Then - Verify final state
        var currentItem = itemStore.items.first(where: { $0.id == "multi-1" })
        XCTAssertEqual(currentItem?.title, "Third Update")

        // When - Undo once
        undoManager.undo()
        currentItem = itemStore.items.first(where: { $0.id == "multi-1" })
        XCTAssertEqual(currentItem?.title, "Second Update")

        // When - Undo again
        undoManager.undo()
        currentItem = itemStore.items.first(where: { $0.id == "multi-1" })
        XCTAssertEqual(currentItem?.title, "First Update")

        // When - Undo again
        undoManager.undo()
        currentItem = itemStore.items.first(where: { $0.id == "multi-1" })
        XCTAssertEqual(currentItem?.title, "Original")

        // Then - Should not be able to undo further
        XCTAssertFalse(undoManager.canUndo)
    }

    func testUndoRedoSequence() throws {
        // Given
        let item = Item(id: "seq-1", title: "Start", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        // When - Update, undo, update again
        itemStore.updateItemTitle(id: "seq-1", title: "First")
        undoManager.undo()
        itemStore.updateItemTitle(id: "seq-1", title: "Second")

        // Then - Redo should not be available (new action clears redo stack)
        XCTAssertFalse(undoManager.canRedo)

        var currentItem = itemStore.items.first(where: { $0.id == "seq-1" })
        XCTAssertEqual(currentItem?.title, "Second")

        // When - Undo
        undoManager.undo()
        currentItem = itemStore.items.first(where: { $0.id == "seq-1" })
        XCTAssertEqual(currentItem?.title, "Start")
    }

    func testCannotUndoWhenNoOperations() throws {
        // Given - Fresh store with no operations
        // When/Then
        XCTAssertFalse(undoManager.canUndo)
        XCTAssertFalse(undoManager.canRedo)
    }
}
