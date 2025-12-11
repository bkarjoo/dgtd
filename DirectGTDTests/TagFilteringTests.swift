import DirectGTDCore
import XCTest
@testable import DirectGTD

final class TagFilteringTests: XCTestCase {
    var itemStore: ItemStore!
    var repository: ItemRepository!
    var undoManager: UndoManager!

    override func setUp() {
        super.setUp()
        let testDb = TestDatabaseWrapper()
        repository = ItemRepository(database: testDb)
        let settings = UserSettings()
        itemStore = ItemStore(settings: settings, repository: repository, database: testDb)
        undoManager = UndoManager()
        itemStore.undoManager = undoManager
    }

    override func tearDown() {
        itemStore = nil
        repository = nil
        undoManager = nil
        super.tearDown()
    }

    // MARK: - matchesTagFilter Tests

    func testMatchesTagFilterWithNoFilterReturnsTrue() throws {
        // Given: An item and no active filter
        let item = Item(id: "1", title: "Test Item", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        // When: No filter is set
        XCTAssertNil(itemStore.filteredByTag)

        // Then: Item matches filter (shows all items)
        XCTAssertTrue(itemStore.matchesTagFilter(item))
    }

    func testMatchesTagFilterWhenItemHasFilterTag() throws {
        // Given: An item with a tag
        let item = Item(id: "1", title: "Test Item", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        let tag = itemStore.createTag(name: "urgent", color: "#FF0000")!
        undoManager.endUndoGrouping()
        undoManager.beginUndoGrouping()

        itemStore.addTagToItem(itemId: item.id, tag: tag)

        // When: Filter is set to that tag
        itemStore.filteredByTag = tag

        // Then: Item matches filter
        XCTAssertTrue(itemStore.matchesTagFilter(item))
    }

    func testMatchesTagFilterWhenItemDoesNotHaveFilterTag() throws {
        // Given: An item without the filter tag (and no children)
        let item = Item(id: "1", title: "Test Item", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        let tag = itemStore.createTag(name: "urgent", color: "#FF0000")!

        // When: Filter is set but item doesn't have the tag
        itemStore.filteredByTag = tag

        // Then: Item does not match filter
        XCTAssertFalse(itemStore.matchesTagFilter(item))
    }

    func testMatchesTagFilterWhenChildHasFilterTag() throws {
        // Given: Parent item without tag, child item with tag
        let parent = Item(id: "parent", title: "Parent", itemType: .project)
        var child = Item(id: "child", title: "Child", itemType: .task)
        child.parentId = "parent"

        try repository.create(parent)
        try repository.create(child)
        itemStore.loadItems()

        let tag = itemStore.createTag(name: "urgent", color: "#FF0000")!
        undoManager.endUndoGrouping()
        undoManager.beginUndoGrouping()

        itemStore.addTagToItem(itemId: child.id, tag: tag)

        // When: Filter is set to the tag
        itemStore.filteredByTag = tag

        // Then: Parent matches filter (to show hierarchy)
        XCTAssertTrue(itemStore.matchesTagFilter(parent))
    }

    func testMatchesTagFilterWhenGrandchildHasFilterTag() throws {
        // Given: Three-level hierarchy, only grandchild has tag
        let grandparent = Item(id: "grandparent", title: "Grandparent", itemType: .project)
        var parent = Item(id: "parent", title: "Parent", itemType: .project)
        parent.parentId = "grandparent"
        var child = Item(id: "child", title: "Child", itemType: .task)
        child.parentId = "parent"

        try repository.create(grandparent)
        try repository.create(parent)
        try repository.create(child)
        itemStore.loadItems()

        let tag = itemStore.createTag(name: "urgent", color: "#FF0000")!
        undoManager.endUndoGrouping()
        undoManager.beginUndoGrouping()

        itemStore.addTagToItem(itemId: child.id, tag: tag)

        // When: Filter is set to the tag
        itemStore.filteredByTag = tag

        // Then: Both ancestors match filter (to show hierarchy)
        XCTAssertTrue(itemStore.matchesTagFilter(grandparent))
        XCTAssertTrue(itemStore.matchesTagFilter(parent))
    }

    func testMatchesTagFilterWhenNoDescendantsHaveTag() throws {
        // Given: Parent with children, none have the filter tag
        let parent = Item(id: "parent", title: "Parent", itemType: .project)
        var child1 = Item(id: "child1", title: "Child 1", itemType: .task)
        child1.parentId = "parent"
        var child2 = Item(id: "child2", title: "Child 2", itemType: .task)
        child2.parentId = "parent"

        try repository.create(parent)
        try repository.create(child1)
        try repository.create(child2)
        itemStore.loadItems()

        let tag = itemStore.createTag(name: "urgent", color: "#FF0000")!

        // When: Filter is set but no items have the tag
        itemStore.filteredByTag = tag

        // Then: Nothing matches filter
        XCTAssertFalse(itemStore.matchesTagFilter(parent))
        XCTAssertFalse(itemStore.matchesTagFilter(child1))
        XCTAssertFalse(itemStore.matchesTagFilter(child2))
    }

    func testMatchesTagFilterWithDifferentTag() throws {
        // Given: Item has one tag but filter is set to a different tag
        let item = Item(id: "1", title: "Test Item", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        let tag1 = itemStore.createTag(name: "urgent", color: "#FF0000")!
        let tag2 = itemStore.createTag(name: "later", color: "#0000FF")!
        undoManager.endUndoGrouping()
        undoManager.beginUndoGrouping()

        itemStore.addTagToItem(itemId: item.id, tag: tag1)

        // When: Filter is set to different tag
        itemStore.filteredByTag = tag2

        // Then: Item does not match filter
        XCTAssertFalse(itemStore.matchesTagFilter(item))
    }

    // MARK: - hasDescendantWithTag Tests

    func testHasDescendantWithTagWhenNoChildren() throws {
        // Given: Item with no children
        let item = Item(id: "1", title: "Test Item", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        let tag = itemStore.createTag(name: "urgent", color: "#FF0000")!

        // When: Checking for descendants with tag
        let hasDescendant = itemStore.hasDescendantWithTag(item, tagId: tag.id, allItems: itemStore.items)

        // Then: Returns false
        XCTAssertFalse(hasDescendant)
    }

    func testHasDescendantWithTagWhenDirectChildHasTag() throws {
        // Given: Parent with child that has the tag
        let parent = Item(id: "parent", title: "Parent", itemType: .project)
        var child = Item(id: "child", title: "Child", itemType: .task)
        child.parentId = "parent"

        try repository.create(parent)
        try repository.create(child)
        itemStore.loadItems()

        let tag = itemStore.createTag(name: "urgent", color: "#FF0000")!
        undoManager.endUndoGrouping()
        undoManager.beginUndoGrouping()

        itemStore.addTagToItem(itemId: child.id, tag: tag)

        // When: Checking parent for descendants with tag
        let hasDescendant = itemStore.hasDescendantWithTag(parent, tagId: tag.id, allItems: itemStore.items)

        // Then: Returns true
        XCTAssertTrue(hasDescendant)
    }

    func testHasDescendantWithTagWhenGrandchildHasTag() throws {
        // Given: Grandparent > Parent > Child hierarchy, child has tag
        let grandparent = Item(id: "grandparent", title: "Grandparent", itemType: .project)
        var parent = Item(id: "parent", title: "Parent", itemType: .project)
        parent.parentId = "grandparent"
        var child = Item(id: "child", title: "Child", itemType: .task)
        child.parentId = "parent"

        try repository.create(grandparent)
        try repository.create(parent)
        try repository.create(child)
        itemStore.loadItems()

        let tag = itemStore.createTag(name: "urgent", color: "#FF0000")!
        undoManager.endUndoGrouping()
        undoManager.beginUndoGrouping()

        itemStore.addTagToItem(itemId: child.id, tag: tag)

        // When: Checking grandparent for descendants with tag
        let hasDescendant = itemStore.hasDescendantWithTag(grandparent, tagId: tag.id, allItems: itemStore.items)

        // Then: Returns true (recursive search works)
        XCTAssertTrue(hasDescendant)
    }

    func testHasDescendantWithTagWhenNoDescendantsHaveTag() throws {
        // Given: Parent with children, none have the tag
        let parent = Item(id: "parent", title: "Parent", itemType: .project)
        var child1 = Item(id: "child1", title: "Child 1", itemType: .task)
        child1.parentId = "parent"
        var child2 = Item(id: "child2", title: "Child 2", itemType: .task)
        child2.parentId = "parent"

        try repository.create(parent)
        try repository.create(child1)
        try repository.create(child2)
        itemStore.loadItems()

        let tag = itemStore.createTag(name: "urgent", color: "#FF0000")!

        // When: Checking parent for descendants with tag
        let hasDescendant = itemStore.hasDescendantWithTag(parent, tagId: tag.id, allItems: itemStore.items)

        // Then: Returns false
        XCTAssertFalse(hasDescendant)
    }

    func testHasDescendantWithTagWithMultipleDescendantsOneHasTag() throws {
        // Given: Parent with multiple children, only one has the tag
        let parent = Item(id: "parent", title: "Parent", itemType: .project)
        var child1 = Item(id: "child1", title: "Child 1", itemType: .task)
        child1.parentId = "parent"
        var child2 = Item(id: "child2", title: "Child 2", itemType: .task)
        child2.parentId = "parent"
        var child3 = Item(id: "child3", title: "Child 3", itemType: .task)
        child3.parentId = "parent"

        try repository.create(parent)
        try repository.create(child1)
        try repository.create(child2)
        try repository.create(child3)
        itemStore.loadItems()

        let tag = itemStore.createTag(name: "urgent", color: "#FF0000")!
        undoManager.endUndoGrouping()
        undoManager.beginUndoGrouping()

        itemStore.addTagToItem(itemId: child2.id, tag: tag)

        // When: Checking parent for descendants with tag
        let hasDescendant = itemStore.hasDescendantWithTag(parent, tagId: tag.id, allItems: itemStore.items)

        // Then: Returns true
        XCTAssertTrue(hasDescendant)
    }

    func testHasDescendantWithTagWithComplexHierarchy() throws {
        // Given: Complex hierarchy with tag deep in one branch
        //        Root
        //        ├── Branch1
        //        │   ├── Leaf1A
        //        │   └── Leaf1B (has tag)
        //        └── Branch2
        //            └── Leaf2A

        let root = Item(id: "root", title: "Root", itemType: .project)
        var branch1 = Item(id: "branch1", title: "Branch 1", itemType: .project)
        branch1.parentId = "root"
        var branch2 = Item(id: "branch2", title: "Branch 2", itemType: .project)
        branch2.parentId = "root"
        var leaf1A = Item(id: "leaf1A", title: "Leaf 1A", itemType: .task)
        leaf1A.parentId = "branch1"
        var leaf1B = Item(id: "leaf1B", title: "Leaf 1B", itemType: .task)
        leaf1B.parentId = "branch1"
        var leaf2A = Item(id: "leaf2A", title: "Leaf 2A", itemType: .task)
        leaf2A.parentId = "branch2"

        try repository.create(root)
        try repository.create(branch1)
        try repository.create(branch2)
        try repository.create(leaf1A)
        try repository.create(leaf1B)
        try repository.create(leaf2A)
        itemStore.loadItems()

        let tag = itemStore.createTag(name: "urgent", color: "#FF0000")!
        undoManager.endUndoGrouping()
        undoManager.beginUndoGrouping()

        itemStore.addTagToItem(itemId: leaf1B.id, tag: tag)

        // When: Checking various items
        // Then: Root and Branch1 should have descendant with tag
        XCTAssertTrue(itemStore.hasDescendantWithTag(root, tagId: tag.id, allItems: itemStore.items))
        XCTAssertTrue(itemStore.hasDescendantWithTag(branch1, tagId: tag.id, allItems: itemStore.items))

        // Branch2 should not have descendant with tag
        XCTAssertFalse(itemStore.hasDescendantWithTag(branch2, tagId: tag.id, allItems: itemStore.items))
    }

    func testHasDescendantWithTagWithChildHavingMultipleTags() throws {
        // Given: Child has multiple tags, checking for one of them
        let parent = Item(id: "parent", title: "Parent", itemType: .project)
        var child = Item(id: "child", title: "Child", itemType: .task)
        child.parentId = "parent"

        try repository.create(parent)
        try repository.create(child)
        itemStore.loadItems()

        let tag1 = itemStore.createTag(name: "urgent", color: "#FF0000")!
        let tag2 = itemStore.createTag(name: "later", color: "#0000FF")!
        undoManager.endUndoGrouping()
        undoManager.beginUndoGrouping()

        itemStore.addTagToItem(itemId: child.id, tag: tag1)
        undoManager.endUndoGrouping()
        undoManager.beginUndoGrouping()
        itemStore.addTagToItem(itemId: child.id, tag: tag2)

        // When: Checking parent for descendants with either tag
        // Then: Should find descendant for both tags
        XCTAssertTrue(itemStore.hasDescendantWithTag(parent, tagId: tag1.id, allItems: itemStore.items))
        XCTAssertTrue(itemStore.hasDescendantWithTag(parent, tagId: tag2.id, allItems: itemStore.items))
    }
}
