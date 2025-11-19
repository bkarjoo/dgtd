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
        itemStore = ItemStore(settings: settings, repository: repository)
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
}
