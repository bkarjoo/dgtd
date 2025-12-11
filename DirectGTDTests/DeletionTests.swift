import DirectGTDCore
import XCTest
@testable import DirectGTD

final class DeletionTests: XCTestCase {
    var itemStore: ItemStore!
    var repository: ItemRepository!
    var settings: UserSettings!
    var undoManager: UndoManager!

    override func setUp() {
        super.setUp()
        let testDb = TestDatabaseWrapper()
        repository = ItemRepository(database: testDb)
        settings = UserSettings()
        // Pass the same database provider to ItemStore so SoftDeleteService uses the test DB
        itemStore = ItemStore(settings: settings, repository: repository, database: testDb)
        undoManager = UndoManager()
        itemStore.undoManager = undoManager
    }

    override func tearDown() {
        itemStore = nil
        repository = nil
        settings = nil
        undoManager = nil
        super.tearDown()
    }

    // MARK: - Basic Deletion Tests

    func testDeleteItemSelectsPreviousVisibleItem() throws {
        // Given: Three items in sequence
        let item1 = Item(id: "item1", title: "Item 1", itemType: .task, sortOrder: 0)
        let item2 = Item(id: "item2", title: "Item 2", itemType: .task, sortOrder: 1)
        let item3 = Item(id: "item3", title: "Item 3", itemType: .task, sortOrder: 2)
        try repository.create(item1)
        try repository.create(item2)
        try repository.create(item3)
        itemStore.loadItems()

        // When: Deleting item2
        itemStore.selectedItemId = "item2"
        itemStore.deleteSelectedItem()

        // Then: Selection moves to item1 (previous item)
        XCTAssertEqual(itemStore.selectedItemId, "item1")
        XCTAssertNil(itemStore.items.first(where: { $0.id == "item2" }))
    }

    func testDeleteItemSelectsNextVisibleItemWhenNoPrevious() throws {
        // Given: Three items with first one selected
        let item1 = Item(id: "item1", title: "Item 1", itemType: .task, sortOrder: 0)
        let item2 = Item(id: "item2", title: "Item 2", itemType: .task, sortOrder: 1)
        let item3 = Item(id: "item3", title: "Item 3", itemType: .task, sortOrder: 2)
        try repository.create(item1)
        try repository.create(item2)
        try repository.create(item3)
        itemStore.loadItems()

        // When: Deleting first item
        itemStore.selectedItemId = "item1"
        itemStore.deleteSelectedItem()

        // Then: Selection moves to item2 (next item)
        XCTAssertEqual(itemStore.selectedItemId, "item2")
        XCTAssertNil(itemStore.items.first(where: { $0.id == "item1" }))
    }

    func testDeleteLastItemLeavesNoSelection() throws {
        // Given: Single item
        let item = Item(id: "item1", title: "Item 1", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        // When: Deleting the only item
        itemStore.selectedItemId = "item1"
        itemStore.deleteSelectedItem()

        // Then: No selection remains
        XCTAssertNil(itemStore.selectedItemId)
        XCTAssertTrue(itemStore.items.isEmpty)
    }

    // MARK: - Deletion with Tag Filtering

    func testDeleteItemWithTagFilterSelectsNextMatchingItem() throws {
        // Given: Items with different tags
        let workTag = Tag(id: "work", name: "Work", color: "#FF0000")
        let homeTag = Tag(id: "home", name: "Home", color: "#00FF00")
        try repository.createTag(workTag)
        try repository.createTag(homeTag)

        let item1 = Item(id: "item1", title: "Work 1", itemType: .task, sortOrder: 0)
        let item2 = Item(id: "item2", title: "Home 1", itemType: .task, sortOrder: 1)
        let item3 = Item(id: "item3", title: "Work 2", itemType: .task, sortOrder: 2)
        try repository.create(item1)
        try repository.create(item2)
        try repository.create(item3)
        try repository.addTagToItem(itemId: "item1", tagId: "work")
        try repository.addTagToItem(itemId: "item2", tagId: "home")
        try repository.addTagToItem(itemId: "item3", tagId: "work")
        itemStore.loadItems()

        // When: Filtering by "work" tag and deleting item1
        itemStore.filteredByTag = workTag
        itemStore.selectedItemId = "item1"
        itemStore.deleteSelectedItem()

        // Then: Selection should skip item2 (doesn't match filter) and select item3
        XCTAssertEqual(itemStore.selectedItemId, "item3")
        XCTAssertNil(itemStore.items.first(where: { $0.id == "item1" }))
    }

    func testDeleteItemWithTagFilterSelectsPreviousMatchingItem() throws {
        // Given: Items with different tags
        let workTag = Tag(id: "work", name: "Work", color: "#FF0000")
        let homeTag = Tag(id: "home", name: "Home", color: "#00FF00")
        try repository.createTag(workTag)
        try repository.createTag(homeTag)

        let item1 = Item(id: "item1", title: "Work 1", itemType: .task, sortOrder: 0)
        let item2 = Item(id: "item2", title: "Home 1", itemType: .task, sortOrder: 1)
        let item3 = Item(id: "item3", title: "Work 2", itemType: .task, sortOrder: 2)
        try repository.create(item1)
        try repository.create(item2)
        try repository.create(item3)
        try repository.addTagToItem(itemId: "item1", tagId: "work")
        try repository.addTagToItem(itemId: "item2", tagId: "home")
        try repository.addTagToItem(itemId: "item3", tagId: "work")
        itemStore.loadItems()

        // When: Filtering by "work" tag and deleting item3
        itemStore.filteredByTag = workTag
        itemStore.selectedItemId = "item3"
        itemStore.deleteSelectedItem()

        // Then: Selection should skip item2 (doesn't match filter) and select item1
        XCTAssertEqual(itemStore.selectedItemId, "item1")
        XCTAssertNil(itemStore.items.first(where: { $0.id == "item3" }))
    }

    func testDeleteLastMatchingItemWithTagFilterLeavesNoSelection() throws {
        // Given: One item with work tag, others with home tag
        let workTag = Tag(id: "work", name: "Work", color: "#FF0000")
        let homeTag = Tag(id: "home", name: "Home", color: "#00FF00")
        try repository.createTag(workTag)
        try repository.createTag(homeTag)

        let item1 = Item(id: "item1", title: "Home 1", itemType: .task, sortOrder: 0)
        let item2 = Item(id: "item2", title: "Work 1", itemType: .task, sortOrder: 1)
        let item3 = Item(id: "item3", title: "Home 2", itemType: .task, sortOrder: 2)
        try repository.create(item1)
        try repository.create(item2)
        try repository.create(item3)
        try repository.addTagToItem(itemId: "item1", tagId: "home")
        try repository.addTagToItem(itemId: "item2", tagId: "work")
        try repository.addTagToItem(itemId: "item3", tagId: "home")
        itemStore.loadItems()

        // When: Filtering by "work" tag and deleting the only matching item
        itemStore.filteredByTag = workTag
        itemStore.selectedItemId = "item2"
        itemStore.deleteSelectedItem()

        // Then: No selection should remain (no other work items visible)
        XCTAssertNil(itemStore.selectedItemId)
        XCTAssertNil(itemStore.items.first(where: { $0.id == "item2" }))
    }

    // MARK: - Deletion with Hide Completed Tasks

    func testDeleteItemWithHideCompletedSelectsNextNonCompletedItem() throws {
        // Given: Items with some completed
        let item1 = Item(id: "item1", title: "Task 1", itemType: .task, sortOrder: 0)
        var item2 = Item(id: "item2", title: "Task 2", itemType: .task, sortOrder: 1)
        item2.completedAt = 12345 // Completed
        let item3 = Item(id: "item3", title: "Task 3", itemType: .task, sortOrder: 2)
        try repository.create(item1)
        try repository.create(item2)
        try repository.create(item3)
        itemStore.loadItems()

        // When: Hiding completed tasks and deleting item1
        settings.showCompletedTasks = false
        itemStore.selectedItemId = "item1"
        itemStore.deleteSelectedItem()

        // Then: Selection should skip item2 (completed) and select item3
        XCTAssertEqual(itemStore.selectedItemId, "item3")
        XCTAssertNil(itemStore.items.first(where: { $0.id == "item1" }))
    }

    func testDeleteItemWithHideCompletedSelectsPreviousNonCompletedItem() throws {
        // Given: Items with some completed
        let item1 = Item(id: "item1", title: "Task 1", itemType: .task, sortOrder: 0)
        var item2 = Item(id: "item2", title: "Task 2", itemType: .task, sortOrder: 1)
        item2.completedAt = 12345 // Completed
        let item3 = Item(id: "item3", title: "Task 3", itemType: .task, sortOrder: 2)
        try repository.create(item1)
        try repository.create(item2)
        try repository.create(item3)
        itemStore.loadItems()

        // When: Hiding completed tasks and deleting item3
        settings.showCompletedTasks = false
        itemStore.selectedItemId = "item3"
        itemStore.deleteSelectedItem()

        // Then: Selection should skip item2 (completed) and select item1
        XCTAssertEqual(itemStore.selectedItemId, "item1")
        XCTAssertNil(itemStore.items.first(where: { $0.id == "item3" }))
    }

    func testDeleteLastNonCompletedItemWithHideCompletedLeavesNoSelection() throws {
        // Given: One non-completed item among completed items
        var item1 = Item(id: "item1", title: "Task 1", itemType: .task, sortOrder: 0)
        item1.completedAt = 12345 // Completed
        let item2 = Item(id: "item2", title: "Task 2", itemType: .task, sortOrder: 1)
        var item3 = Item(id: "item3", title: "Task 3", itemType: .task, sortOrder: 2)
        item3.completedAt = 12345 // Completed
        try repository.create(item1)
        try repository.create(item2)
        try repository.create(item3)
        itemStore.loadItems()

        // When: Hiding completed tasks and deleting the only non-completed item
        settings.showCompletedTasks = false
        itemStore.selectedItemId = "item2"
        itemStore.deleteSelectedItem()

        // Then: No selection should remain (no other non-completed items visible)
        XCTAssertNil(itemStore.selectedItemId)
        XCTAssertNil(itemStore.items.first(where: { $0.id == "item2" }))
    }

    // MARK: - Deletion with Combined Filters

    func testDeleteItemWithBothFiltersActiveSelectsNextVisibleItem() throws {
        // Given: Items with tags and completion states
        let workTag = Tag(id: "work", name: "Work", color: "#FF0000")
        try repository.createTag(workTag)

        let item1 = Item(id: "item1", title: "Work 1", itemType: .task, sortOrder: 0)
        var item2 = Item(id: "item2", title: "Work 2 (completed)", itemType: .task, sortOrder: 1)
        item2.completedAt = 12345 // Completed
        let item3 = Item(id: "item3", title: "Work 3", itemType: .task, sortOrder: 2)
        try repository.create(item1)
        try repository.create(item2)
        try repository.create(item3)
        try repository.addTagToItem(itemId: "item1", tagId: "work")
        try repository.addTagToItem(itemId: "item2", tagId: "work")
        try repository.addTagToItem(itemId: "item3", tagId: "work")
        itemStore.loadItems()

        // When: Filtering by work tag, hiding completed, and deleting item1
        // Note: Tag filtering takes precedence, so completed items with the tag are still visible
        itemStore.filteredByTag = workTag
        settings.showCompletedTasks = false
        itemStore.selectedItemId = "item1"
        itemStore.deleteSelectedItem()

        // Then: Selection moves to item2 (tag filter takes precedence over hide completed)
        XCTAssertEqual(itemStore.selectedItemId, "item2")
        XCTAssertNil(itemStore.items.first(where: { $0.id == "item1" }))
    }

    // MARK: - Deletion with Hierarchical Items

    func testDeleteItemSkipsHiddenChildOfCollapsedParent() throws {
        // Given: Single-level collapsed hierarchy followed by root item
        // Simplified version of testDeleteItemSkipsNestedCollapsedAncestors with one level
        // Structure: proj1 (visible root, collapsed) → task1 (hidden), then task2 (visible root)
        let proj1 = Item(id: "proj1_unique", title: "Project 1", itemType: .project, sortOrder: 0)
        let task1 = Item(id: "task1_unique", title: "Task 1", itemType: .task, parentId: "proj1_unique", sortOrder: 0)
        let task2 = Item(id: "task2_unique", title: "Task 2", itemType: .task, sortOrder: 1)

        try repository.create(proj1)
        try repository.create(task1)
        try repository.create(task2)
        itemStore.loadItems()

        // Leave proj1 collapsed (task1 is hidden)
        XCTAssertFalse(settings.expandedItemIds.contains("proj1_unique"))

        // When: Deleting task2
        itemStore.selectedItemId = "task2_unique"
        itemStore.deleteSelectedItem()

        // Then: Should skip hidden task1 and select proj1
        // This tests single-level isItemVisible check (ItemStore.swift:830-831)
        XCTAssertEqual(itemStore.selectedItemId, "proj1_unique",
                      "Should skip hidden child of collapsed parent")
        XCTAssertNil(itemStore.items.first(where: { $0.id == "task2_unique" }))
    }

    func testDeleteItemSkipsNestedCollapsedAncestors() throws {
        // Given: Nested hierarchy with collapsed grandparent
        // Order: grandparent, parent (hidden), child (hidden), item
        let grandparent = Item(id: "grandparent", title: "Grandparent", itemType: .project, sortOrder: 0)
        let parent = Item(id: "parent", title: "Parent", itemType: .project, parentId: "grandparent", sortOrder: 0)
        let child = Item(id: "child", title: "Child", itemType: .task, parentId: "parent", sortOrder: 0)
        let item = Item(id: "item", title: "Item", itemType: .task, sortOrder: 1)
        try repository.create(grandparent)
        try repository.create(parent)
        try repository.create(child)
        try repository.create(item)
        itemStore.loadItems()

        // Leave grandparent collapsed (parent and child are hidden)
        XCTAssertFalse(settings.expandedItemIds.contains("grandparent"))

        // When: Deleting item
        itemStore.selectedItemId = "item"
        itemStore.deleteSelectedItem()

        // Then: Selection should skip hidden child and parent, select grandparent
        // This tests recursive isItemVisible check for multiple collapsed ancestors
        XCTAssertEqual(itemStore.selectedItemId, "grandparent")
        XCTAssertNil(itemStore.items.first(where: { $0.id == "item" }))
    }

    func testDeleteItemWithExpandedParentSelectsVisibleSibling() throws {
        // Given: Expanded parent with multiple children
        let parent = Item(id: "parent", title: "Parent", itemType: .project, sortOrder: 0)
        let child1 = Item(id: "child1", title: "Child 1", itemType: .task, parentId: "parent", sortOrder: 0)
        let child2 = Item(id: "child2", title: "Child 2", itemType: .task, parentId: "parent", sortOrder: 1)
        try repository.create(parent)
        try repository.create(child1)
        try repository.create(child2)
        itemStore.loadItems()

        // Expand parent (both children visible)
        settings.expandedItemIds.insert("parent")

        // When: Deleting child2
        itemStore.selectedItemId = "child2"
        itemStore.deleteSelectedItem()

        // Then: Selection should move to child1 (previous visible sibling)
        XCTAssertEqual(itemStore.selectedItemId, "child1")
        XCTAssertNil(itemStore.items.first(where: { $0.id == "child2" }))
    }

    // MARK: - Undo Tests

    func testUndoDeleteRestoresItemAndSelection() throws {
        // Given: Three items with middle one selected
        let item1 = Item(id: "item1", title: "Item 1", itemType: .task, sortOrder: 0)
        let item2 = Item(id: "item2", title: "Item 2", itemType: .task, sortOrder: 1)
        let item3 = Item(id: "item3", title: "Item 3", itemType: .task, sortOrder: 2)
        try repository.create(item1)
        try repository.create(item2)
        try repository.create(item3)
        itemStore.loadItems()

        // When: Deleting item2 then undoing
        itemStore.selectedItemId = "item2"
        itemStore.deleteSelectedItem()
        let selectionAfterDelete = itemStore.selectedItemId

        undoManager.undo()

        // Then: Item is restored and reselected
        XCTAssertNotNil(itemStore.items.first(where: { $0.id == "item2" }))
        XCTAssertEqual(itemStore.selectedItemId, "item2")
        XCTAssertNotEqual(selectionAfterDelete, "item2") // Verify selection did change during delete
    }

    func testUndoDeleteWithSubtreeRestoresAllDescendants() throws {
        // Given: Parent with children
        let parent = Item(id: "parent", title: "Parent", itemType: .project, sortOrder: 0)
        let child1 = Item(id: "child1", title: "Child 1", itemType: .task, parentId: "parent", sortOrder: 0)
        let child2 = Item(id: "child2", title: "Child 2", itemType: .task, parentId: "parent", sortOrder: 1)
        try repository.create(parent)
        try repository.create(child1)
        try repository.create(child2)
        itemStore.loadItems()

        let initialCount = itemStore.items.count

        // When: Deleting parent then undoing
        itemStore.selectedItemId = "parent"
        itemStore.deleteSelectedItem()

        XCTAssertEqual(itemStore.items.count, 0) // All deleted due to cascade

        undoManager.undo()

        // Then: All items are restored
        XCTAssertEqual(itemStore.items.count, initialCount)
        XCTAssertNotNil(itemStore.items.first(where: { $0.id == "parent" }))
        XCTAssertNotNil(itemStore.items.first(where: { $0.id == "child1" }))
        XCTAssertNotNil(itemStore.items.first(where: { $0.id == "child2" }))
        XCTAssertEqual(itemStore.selectedItemId, "parent")
    }
}
