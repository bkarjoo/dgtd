import XCTest
import GRDB
@testable import DirectGTD

final class TagManagementTests: XCTestCase {
    var testDB: TestDatabaseWrapper!
    var repository: ItemRepository!
    var itemStore: ItemStore!
    var settings: UserSettings!
    var undoManager: UndoManager!

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

    // MARK: - Tag Creation Tests

    func testCreateTag() throws {
        // Given - Empty store
        XCTAssertTrue(itemStore.tags.isEmpty)

        // When - Create a tag
        let tag = itemStore.createTag(name: "Important", color: "#FF0000")

        // Then - Tag should be created
        XCTAssertNotNil(tag)
        XCTAssertEqual(tag?.name, "Important")
        XCTAssertEqual(tag?.color, "#FF0000")
        XCTAssertEqual(itemStore.tags.count, 1)
        XCTAssertEqual(itemStore.tags.first?.name, "Important")
    }

    func testCreateTagWithEmptyName() throws {
        // Given - Empty store
        // When - Try to create tag with empty name
        let tag = itemStore.createTag(name: "", color: "#FF0000")

        // Then - Tag should not be created
        XCTAssertNil(tag)
        XCTAssertTrue(itemStore.tags.isEmpty)
    }

    func testCreateMultipleTags() throws {
        // Given - Empty store
        // When - Create multiple tags
        _ = itemStore.createTag(name: "Work", color: "#FF0000")
        _ = itemStore.createTag(name: "Personal", color: "#00FF00")
        _ = itemStore.createTag(name: "Urgent", color: "#0000FF")

        // Then - All tags should be created
        XCTAssertEqual(itemStore.tags.count, 3)
        let tagNames = itemStore.tags.map { $0.name }.sorted()
        XCTAssertEqual(tagNames, ["Personal", "Urgent", "Work"])
    }

    func testUndoCreateTag() throws {
        // Given - Create a tag
        guard let tag = itemStore.createTag(name: "Test Tag", color: "#FF0000") else {
            XCTFail("Failed to create tag")
            return
        }
        XCTAssertEqual(itemStore.tags.count, 1)

        // When - Undo
        XCTAssertTrue(undoManager.canUndo)
        undoManager.undo()

        // Then - Tag should be deleted
        XCTAssertTrue(itemStore.tags.isEmpty)
    }

    func testRedoCreateTag() throws {
        // Given - Create and undo tag
        _ = itemStore.createTag(name: "Test Tag", color: "#FF0000")
        undoManager.undo()
        XCTAssertTrue(itemStore.tags.isEmpty)

        // When - Redo
        XCTAssertTrue(undoManager.canRedo)
        undoManager.redo()

        // Then - Tag should be recreated
        XCTAssertEqual(itemStore.tags.count, 1)
        XCTAssertEqual(itemStore.tags.first?.name, "Test Tag")
    }

    // MARK: - Tag Update Tests

    func testUpdateTag() throws {
        // Given - Create a tag
        guard var tag = itemStore.createTag(name: "Original Name", color: "#FF0000") else {
            XCTFail("Failed to create tag")
            return
        }

        // When - Update the tag
        tag.name = "Updated Name"
        tag.color = "#00FF00"
        itemStore.updateTag(tag: tag)

        // Then - Tag should be updated
        XCTAssertEqual(itemStore.tags.count, 1)
        let updatedTag = itemStore.tags.first
        XCTAssertEqual(updatedTag?.name, "Updated Name")
        XCTAssertEqual(updatedTag?.color, "#00FF00")
    }

    func testUndoUpdateTag() throws {
        // Given - Create and update a tag
        guard var tag = itemStore.createTag(name: "Original", color: "#FF0000") else {
            XCTFail("Failed to create tag")
            return
        }

        // Close creation undo group
        undoManager.endUndoGrouping()

        // Update in separate group
        undoManager.beginUndoGrouping()
        tag.name = "Modified"
        tag.color = "#00FF00"
        itemStore.updateTag(tag: tag)
        undoManager.endUndoGrouping()

        // When - Undo the update
        undoManager.undo()

        // Then - Tag should revert to original values
        let revertedTag = itemStore.tags.first
        XCTAssertEqual(revertedTag?.name, "Original")
        XCTAssertEqual(revertedTag?.color, "#FF0000")
    }

    // MARK: - Tag Deletion Tests

    func testDeleteTag() throws {
        // Given - Create a tag
        guard let tag = itemStore.createTag(name: "To Delete", color: "#FF0000") else {
            XCTFail("Failed to create tag")
            return
        }
        XCTAssertEqual(itemStore.tags.count, 1)

        // When - Delete the tag
        itemStore.deleteTag(tagId: tag.id)

        // Then - Tag should be deleted
        XCTAssertTrue(itemStore.tags.isEmpty)
    }

    func testUndoDeleteTag() throws {
        // Given - Create and delete a tag
        guard let tag = itemStore.createTag(name: "Test Tag", color: "#FF0000") else {
            XCTFail("Failed to create tag")
            return
        }
        let tagId = tag.id

        // Close creation undo group
        undoManager.endUndoGrouping()

        // Delete in separate group
        undoManager.beginUndoGrouping()
        itemStore.deleteTag(tagId: tagId)
        undoManager.endUndoGrouping()
        XCTAssertTrue(itemStore.tags.isEmpty)

        // When - Undo the deletion
        undoManager.undo()

        // Then - Tag should be restored
        XCTAssertEqual(itemStore.tags.count, 1)
        let restoredTag = itemStore.tags.first
        XCTAssertEqual(restoredTag?.id, tagId)
        XCTAssertEqual(restoredTag?.name, "Test Tag")
        XCTAssertEqual(restoredTag?.color, "#FF0000")
    }

    func testDeleteTagPreservesItemAssociations() throws {
        // Given - Create tag and item, associate them
        guard let tag = itemStore.createTag(name: "Test", color: "#FF0000") else {
            XCTFail("Failed to create tag")
            return
        }
        let item = Item(id: "item1", title: "Test Item", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        // Close tag creation undo group
        undoManager.endUndoGrouping()

        // Add tag in separate group
        undoManager.beginUndoGrouping()
        itemStore.addTagToItem(itemId: item.id, tag: tag)
        undoManager.endUndoGrouping()
        XCTAssertEqual(itemStore.getTagsForItem(itemId: item.id).count, 1)

        // When - Delete tag in separate group
        undoManager.beginUndoGrouping()
        itemStore.deleteTag(tagId: tag.id)
        undoManager.endUndoGrouping()

        // Then - Tag removed from item
        XCTAssertTrue(itemStore.getTagsForItem(itemId: item.id).isEmpty)

        // When - Undo deletion
        undoManager.undo()

        // Then - Tag and association should be restored
        XCTAssertEqual(itemStore.tags.count, 1)
        let itemTags = itemStore.getTagsForItem(itemId: item.id)
        XCTAssertEqual(itemTags.count, 1)
        XCTAssertEqual(itemTags.first?.name, "Test")
    }

    // MARK: - Add Tag to Item Tests

    func testAddTagToItem() throws {
        // Given - Create tag and item
        guard let tag = itemStore.createTag(name: "Important", color: "#FF0000") else {
            XCTFail("Failed to create tag")
            return
        }
        let item = Item(id: "item1", title: "Test Item", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        // When - Add tag to item
        itemStore.addTagToItem(itemId: item.id, tag: tag)

        // Then - Item should have the tag
        let itemTags = itemStore.getTagsForItem(itemId: item.id)
        XCTAssertEqual(itemTags.count, 1)
        XCTAssertEqual(itemTags.first?.id, tag.id)
        XCTAssertEqual(itemTags.first?.name, "Important")
    }

    func testAddMultipleTagsToItem() throws {
        // Given - Create multiple tags and one item
        guard let tag1 = itemStore.createTag(name: "Work", color: "#FF0000") else {
            XCTFail("Failed to create tag1")
            return
        }
        guard let tag2 = itemStore.createTag(name: "Urgent", color: "#00FF00") else {
            XCTFail("Failed to create tag2")
            return
        }
        let item = Item(id: "item1", title: "Test Item", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        // When - Add both tags to item
        itemStore.addTagToItem(itemId: item.id, tag: tag1)
        itemStore.addTagToItem(itemId: item.id, tag: tag2)

        // Then - Item should have both tags
        let itemTags = itemStore.getTagsForItem(itemId: item.id)
        XCTAssertEqual(itemTags.count, 2)
        let tagNames = itemTags.map { $0.name }.sorted()
        XCTAssertEqual(tagNames, ["Urgent", "Work"])
    }

    func testUndoAddTagToItem() throws {
        // Given - Create tag and item, add tag to item
        guard let tag = itemStore.createTag(name: "Test", color: "#FF0000") else {
            XCTFail("Failed to create tag")
            return
        }
        let item = Item(id: "item1", title: "Test Item", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()
        itemStore.addTagToItem(itemId: item.id, tag: tag)
        XCTAssertEqual(itemStore.getTagsForItem(itemId: item.id).count, 1)

        // When - Undo
        undoManager.undo()

        // Then - Tag should be removed from item
        XCTAssertTrue(itemStore.getTagsForItem(itemId: item.id).isEmpty)
    }

    // MARK: - Remove Tag from Item Tests

    func testRemoveTagFromItem() throws {
        // Given - Create tag and item, add tag to item
        guard let tag = itemStore.createTag(name: "Test", color: "#FF0000") else {
            XCTFail("Failed to create tag")
            return
        }
        let item = Item(id: "item1", title: "Test Item", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()
        itemStore.addTagToItem(itemId: item.id, tag: tag)
        XCTAssertEqual(itemStore.getTagsForItem(itemId: item.id).count, 1)

        // When - Remove tag from item
        itemStore.removeTagFromItem(itemId: item.id, tagId: tag.id)

        // Then - Item should have no tags
        XCTAssertTrue(itemStore.getTagsForItem(itemId: item.id).isEmpty)
    }

    func testRemoveOneOfMultipleTags() throws {
        // Given - Item with multiple tags
        guard let tag1 = itemStore.createTag(name: "Work", color: "#FF0000") else {
            XCTFail("Failed to create tag1")
            return
        }
        guard let tag2 = itemStore.createTag(name: "Urgent", color: "#00FF00") else {
            XCTFail("Failed to create tag2")
            return
        }
        let item = Item(id: "item1", title: "Test Item", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()
        itemStore.addTagToItem(itemId: item.id, tag: tag1)
        itemStore.addTagToItem(itemId: item.id, tag: tag2)

        // When - Remove one tag
        itemStore.removeTagFromItem(itemId: item.id, tagId: tag1.id)

        // Then - Item should still have the other tag
        let itemTags = itemStore.getTagsForItem(itemId: item.id)
        XCTAssertEqual(itemTags.count, 1)
        XCTAssertEqual(itemTags.first?.name, "Urgent")
    }

    func testUndoRemoveTagFromItem() throws {
        // Given - Create tag and item, add then remove tag
        guard let tag = itemStore.createTag(name: "Test", color: "#FF0000") else {
            XCTFail("Failed to create tag")
            return
        }
        let item = Item(id: "item1", title: "Test Item", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        // Close tag creation undo group
        undoManager.endUndoGrouping()

        // Add tag in separate group
        undoManager.beginUndoGrouping()
        itemStore.addTagToItem(itemId: item.id, tag: tag)
        undoManager.endUndoGrouping()

        // Remove tag in separate group
        undoManager.beginUndoGrouping()
        itemStore.removeTagFromItem(itemId: item.id, tagId: tag.id)
        undoManager.endUndoGrouping()
        XCTAssertTrue(itemStore.getTagsForItem(itemId: item.id).isEmpty)

        // When - Undo the removal
        undoManager.undo()

        // Then - Tag should be back on the item
        let itemTags = itemStore.getTagsForItem(itemId: item.id)
        XCTAssertEqual(itemTags.count, 1)
        XCTAssertEqual(itemTags.first?.name, "Test")
    }

    // MARK: - Get Tags for Item Tests

    func testGetTagsForItemWithNoTags() throws {
        // Given - Item with no tags
        let item = Item(id: "item1", title: "Test Item", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        // When - Get tags for item
        let tags = itemStore.getTagsForItem(itemId: item.id)

        // Then - Should return empty array
        XCTAssertTrue(tags.isEmpty)
    }

    func testGetTagsForItemWithTags() throws {
        // Given - Item with tags
        guard let tag1 = itemStore.createTag(name: "Work", color: "#FF0000") else {
            XCTFail("Failed to create tag1")
            return
        }
        guard let tag2 = itemStore.createTag(name: "Urgent", color: "#00FF00") else {
            XCTFail("Failed to create tag2")
            return
        }
        let item = Item(id: "item1", title: "Test Item", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()
        itemStore.addTagToItem(itemId: item.id, tag: tag1)
        itemStore.addTagToItem(itemId: item.id, tag: tag2)

        // When - Get tags for item
        let tags = itemStore.getTagsForItem(itemId: item.id)

        // Then - Should return both tags
        XCTAssertEqual(tags.count, 2)
        let tagNames = tags.map { $0.name }.sorted()
        XCTAssertEqual(tagNames, ["Urgent", "Work"])
    }

    func testGetTagsForNonExistentItem() throws {
        // Given - No items
        // When - Get tags for non-existent item
        let tags = itemStore.getTagsForItem(itemId: "non-existent")

        // Then - Should return empty array
        XCTAssertTrue(tags.isEmpty)
    }

    // MARK: - Load Tags Tests

    func testLoadTagsPopulatesCache() throws {
        // Given - Create tags and items with associations
        guard let tag = itemStore.createTag(name: "Test", color: "#FF0000") else {
            XCTFail("Failed to create tag")
            return
        }
        let item1 = Item(id: "item1", title: "Item 1", itemType: .task)
        let item2 = Item(id: "item2", title: "Item 2", itemType: .task)
        try repository.create(item1)
        try repository.create(item2)
        itemStore.loadItems()
        itemStore.addTagToItem(itemId: item1.id, tag: tag)

        // When - Reload tags
        itemStore.loadTags()

        // Then - Cache should be populated correctly
        XCTAssertEqual(itemStore.getTagsForItem(itemId: item1.id).count, 1)
        XCTAssertTrue(itemStore.getTagsForItem(itemId: item2.id).isEmpty)
    }

    // MARK: - Integration Tests

    func testCompleteTagWorkflow() throws {
        // Given - Empty store
        XCTAssertTrue(itemStore.tags.isEmpty)

        // When - Create tags
        guard let workTag = itemStore.createTag(name: "Work", color: "#FF0000") else {
            XCTFail("Failed to create work tag")
            return
        }
        guard let urgentTag = itemStore.createTag(name: "Urgent", color: "#FFFF00") else {
            XCTFail("Failed to create urgent tag")
            return
        }

        // And - Create items
        let item1 = Item(id: "item1", title: "Important Task", itemType: .task)
        let item2 = Item(id: "item2", title: "Regular Task", itemType: .task)
        try repository.create(item1)
        try repository.create(item2)
        itemStore.loadItems()

        // And - Add tags to items
        itemStore.addTagToItem(itemId: item1.id, tag: workTag)
        itemStore.addTagToItem(itemId: item1.id, tag: urgentTag)
        itemStore.addTagToItem(itemId: item2.id, tag: workTag)

        // Then - Verify tags are correctly associated
        let item1Tags = itemStore.getTagsForItem(itemId: item1.id)
        XCTAssertEqual(item1Tags.count, 2)

        let item2Tags = itemStore.getTagsForItem(itemId: item2.id)
        XCTAssertEqual(item2Tags.count, 1)
        XCTAssertEqual(item2Tags.first?.name, "Work")

        // When - Remove one tag from item1
        itemStore.removeTagFromItem(itemId: item1.id, tagId: urgentTag.id)

        // Then - item1 should have only work tag
        let updatedItem1Tags = itemStore.getTagsForItem(itemId: item1.id)
        XCTAssertEqual(updatedItem1Tags.count, 1)
        XCTAssertEqual(updatedItem1Tags.first?.name, "Work")
    }

    func testUndoActionNamesForTagOperations() throws {
        // Given - Create tag
        _ = itemStore.createTag(name: "Test", color: "#FF0000")

        // Then - Verify create action name is set
        XCTAssertTrue(undoManager.canUndo, "Should be able to undo after creating tag")
        XCTAssertFalse(undoManager.undoActionName.isEmpty, "Undo action name should not be empty")
    }
}
