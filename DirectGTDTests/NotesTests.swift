import XCTest
@testable import DirectGTD

final class NotesTests: XCTestCase {
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

    // MARK: - Basic updateNotes Tests

    func testUpdateNotesSuccessfullyUpdatesItem() throws {
        // Given: An item without notes
        let item = Item(id: "item1", title: "Test Item", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        // When: Updating notes
        itemStore.updateNotes(id: item.id, notes: "This is a test note")

        // Then: Item has updated notes
        let updatedItem = itemStore.items.first(where: { $0.id == item.id })
        XCTAssertEqual(updatedItem?.notes, "This is a test note")
    }

    func testUpdateNotesUpdatesModifiedAtTimestamp() throws {
        // Given: An item
        let item = Item(id: "item1", title: "Test Item", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        let originalModifiedAt = itemStore.items.first(where: { $0.id == item.id })!.modifiedAt

        // Small delay to ensure timestamp changes (timestamps are in seconds)
        Thread.sleep(forTimeInterval: 1.1)

        // When: Updating notes
        itemStore.updateNotes(id: item.id, notes: "Updated notes")

        // Then: modifiedAt timestamp is updated
        let updatedItem = itemStore.items.first(where: { $0.id == item.id })
        XCTAssertGreaterThan(updatedItem!.modifiedAt, originalModifiedAt)
    }

    func testUpdateNotesFromNilToText() throws {
        // Given: An item with nil notes
        let item = Item(id: "item1", title: "Test Item", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        XCTAssertNil(itemStore.items.first(where: { $0.id == item.id })?.notes)

        // When: Adding notes
        itemStore.updateNotes(id: item.id, notes: "New notes")

        // Then: Notes are set
        let updatedItem = itemStore.items.first(where: { $0.id == item.id })
        XCTAssertEqual(updatedItem?.notes, "New notes")
    }

    func testUpdateNotesFromTextToNil() throws {
        // Given: An item with notes
        var item = Item(id: "item1", title: "Test Item", itemType: .task)
        item.notes = "Existing notes"
        try repository.create(item)
        itemStore.loadItems()

        XCTAssertEqual(itemStore.items.first(where: { $0.id == item.id })?.notes, "Existing notes")

        // When: Clearing notes
        itemStore.updateNotes(id: item.id, notes: nil)

        // Then: Notes are cleared
        let updatedItem = itemStore.items.first(where: { $0.id == item.id })
        XCTAssertNil(updatedItem?.notes)
    }

    func testUpdateNotesFromTextToEmptyString() throws {
        // Given: An item with notes
        var item = Item(id: "item1", title: "Test Item", itemType: .task)
        item.notes = "Existing notes"
        try repository.create(item)
        itemStore.loadItems()

        // When: Setting notes to empty string
        itemStore.updateNotes(id: item.id, notes: "")

        // Then: Notes are set to empty string
        let updatedItem = itemStore.items.first(where: { $0.id == item.id })
        XCTAssertEqual(updatedItem?.notes, "")
    }

    func testUpdateNotesFromTextToDifferentText() throws {
        // Given: An item with notes
        var item = Item(id: "item1", title: "Test Item", itemType: .task)
        item.notes = "Original notes"
        try repository.create(item)
        itemStore.loadItems()

        // When: Updating notes to different text
        itemStore.updateNotes(id: item.id, notes: "Updated notes")

        // Then: Notes are updated
        let updatedItem = itemStore.items.first(where: { $0.id == item.id })
        XCTAssertEqual(updatedItem?.notes, "Updated notes")
    }

    func testUpdateNotesReturnsEarlyWhenItemDoesNotExist() throws {
        // Given: No items
        itemStore.loadItems()

        let initialCount = itemStore.items.count

        // When: Attempting to update notes on non-existent item
        itemStore.updateNotes(id: "nonexistent", notes: "Test notes")

        // Then: No changes occur
        XCTAssertEqual(itemStore.items.count, initialCount)
    }

    func testUpdateNotesPersistsToRepository() throws {
        // Given: An item
        let item = Item(id: "item1", title: "Test Item", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        // When: Updating notes
        itemStore.updateNotes(id: item.id, notes: "Persisted notes")

        // Then: Notes are persisted (reload from repository)
        let reloadedItem = try repository.getItem(id: item.id)
        XCTAssertEqual(reloadedItem?.notes, "Persisted notes")
    }

    func testUpdateNotesWithMultilineText() throws {
        // Given: An item
        let item = Item(id: "item1", title: "Test Item", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        let multilineNotes = """
        Line 1
        Line 2
        Line 3
        """

        // When: Updating notes with multiline text
        itemStore.updateNotes(id: item.id, notes: multilineNotes)

        // Then: Multiline notes are saved correctly
        let updatedItem = itemStore.items.first(where: { $0.id == item.id })
        XCTAssertEqual(updatedItem?.notes, multilineNotes)
    }

    func testUpdateNotesWithSpecialCharacters() throws {
        // Given: An item
        let item = Item(id: "item1", title: "Test Item", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        let specialNotes = "Special: @#$%^&*(){}[]|\\\"';:,.<>?/~`"

        // When: Updating notes with special characters
        itemStore.updateNotes(id: item.id, notes: specialNotes)

        // Then: Special characters are saved correctly
        let updatedItem = itemStore.items.first(where: { $0.id == item.id })
        XCTAssertEqual(updatedItem?.notes, specialNotes)
    }

    // MARK: - Undo/Redo Tests

    func testUpdateNotesRegistersUndo() throws {
        // Given: An item with notes
        var item = Item(id: "item1", title: "Test Item", itemType: .task)
        item.notes = "Original notes"
        try repository.create(item)
        itemStore.loadItems()

        // When: Updating notes
        undoManager.beginUndoGrouping()
        itemStore.updateNotes(id: item.id, notes: "Updated notes")
        undoManager.endUndoGrouping()

        // Verify notes were updated
        var updatedItem = itemStore.items.first(where: { $0.id == item.id })
        XCTAssertEqual(updatedItem?.notes, "Updated notes")

        // When: Undoing
        undoManager.undo()

        // Then: Notes are restored to original
        updatedItem = itemStore.items.first(where: { $0.id == item.id })
        XCTAssertEqual(updatedItem?.notes, "Original notes")
    }

    func testUpdateNotesSupportsRedo() throws {
        // Given: An item with notes
        var item = Item(id: "item1", title: "Test Item", itemType: .task)
        item.notes = "Original notes"
        try repository.create(item)
        itemStore.loadItems()

        // When: Updating notes, undoing, then redoing
        undoManager.beginUndoGrouping()
        itemStore.updateNotes(id: item.id, notes: "Updated notes")
        undoManager.endUndoGrouping()

        undoManager.undo()
        undoManager.redo()

        // Then: Notes are back to updated state
        let updatedItem = itemStore.items.first(where: { $0.id == item.id })
        XCTAssertEqual(updatedItem?.notes, "Updated notes")
    }

    func testUpdateNotesUndoRestoresNilNotes() throws {
        // Given: An item without notes
        let item = Item(id: "item1", title: "Test Item", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        // When: Adding notes then undoing
        undoManager.beginUndoGrouping()
        itemStore.updateNotes(id: item.id, notes: "New notes")
        undoManager.endUndoGrouping()

        undoManager.undo()

        // Then: Notes are back to nil
        let updatedItem = itemStore.items.first(where: { $0.id == item.id })
        XCTAssertNil(updatedItem?.notes)
    }

    // MARK: - Integration Tests

    func testUpdateNotesDoesNotAffectOtherFields() throws {
        // Given: An item with various fields set
        let parent = Item(id: "parent", title: "Parent", itemType: .project)
        try repository.create(parent)

        var item = Item(id: "item1", title: "Test Item", itemType: .task)
        item.parentId = "parent"
        item.sortOrder = 5
        item.completedAt = 12345
        try repository.create(item)
        itemStore.loadItems()

        // When: Updating notes
        itemStore.updateNotes(id: item.id, notes: "New notes")

        // Then: Only notes and modifiedAt are changed
        let updatedItem = itemStore.items.first(where: { $0.id == item.id })
        XCTAssertEqual(updatedItem?.title, "Test Item")
        XCTAssertEqual(updatedItem?.itemType, .task)
        XCTAssertEqual(updatedItem?.parentId, "parent")
        XCTAssertEqual(updatedItem?.sortOrder, 5)
        XCTAssertEqual(updatedItem?.completedAt, 12345)
        XCTAssertEqual(updatedItem?.notes, "New notes")
    }

    func testUpdateNotesOnMultipleItems() throws {
        // Given: Multiple items
        let item1 = Item(id: "item1", title: "Item 1", itemType: .task)
        let item2 = Item(id: "item2", title: "Item 2", itemType: .task)
        let item3 = Item(id: "item3", title: "Item 3", itemType: .task)
        try repository.create(item1)
        try repository.create(item2)
        try repository.create(item3)
        itemStore.loadItems()

        // When: Updating notes on different items
        itemStore.updateNotes(id: item1.id, notes: "Notes for item 1")
        itemStore.updateNotes(id: item2.id, notes: "Notes for item 2")
        itemStore.updateNotes(id: item3.id, notes: "Notes for item 3")

        // Then: Each item has its own notes
        XCTAssertEqual(itemStore.items.first(where: { $0.id == item1.id })?.notes, "Notes for item 1")
        XCTAssertEqual(itemStore.items.first(where: { $0.id == item2.id })?.notes, "Notes for item 2")
        XCTAssertEqual(itemStore.items.first(where: { $0.id == item3.id })?.notes, "Notes for item 3")
    }
}
