import XCTest
import GRDB
@testable import DirectGTD

final class ItemRepositoryTests: XCTestCase {
    var testDB: TestDatabaseWrapper!
    var repository: ItemRepository!

    override func setUp() {
        super.setUp()
        testDB = TestDatabaseWrapper()
        repository = ItemRepository(database: testDB)
    }

    override func tearDown() {
        testDB = nil
        repository = nil
        super.tearDown()
    }

    // MARK: - Create Tests

    func testCreateItem() throws {
        // Given
        let item = Item(id: "test-1", title: "Test Item", itemType: .task)

        // When
        try repository.create(item)

        // Then
        let fetchedItem = try repository.getItem(id: "test-1")
        XCTAssertNotNil(fetchedItem)
        XCTAssertEqual(fetchedItem?.id, "test-1")
        XCTAssertEqual(fetchedItem?.title, "Test Item")
        XCTAssertEqual(fetchedItem?.itemType, .task)
    }

    func testCreateTag() throws {
        // Given
        let tag = Tag(id: "tag-1", name: "Work", color: "#FF0000")

        // When
        try repository.createTag(tag)

        // Then
        let allTags = try repository.getAllTags()
        XCTAssertEqual(allTags.count, 1)
        XCTAssertEqual(allTags.first?.name, "Work")
        XCTAssertEqual(allTags.first?.color, "#FF0000")
    }

    // MARK: - Read Tests

    func testGetAllItems() throws {
        // Given
        let item1 = Item(id: "item-1", title: "Item 1", itemType: .task, sortOrder: 0)
        let item2 = Item(id: "item-2", title: "Item 2", itemType: .project, sortOrder: 1)
        try repository.create(item1)
        try repository.create(item2)

        // When
        let items = try repository.getAllItems()

        // Then
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].id, "item-1")
        XCTAssertEqual(items[1].id, "item-2")
    }

    func testGetChildItems() throws {
        // Given
        let parent = Item(id: "parent", title: "Parent", itemType: .project)
        let child1 = Item(id: "child-1", title: "Child 1", itemType: .task, parentId: "parent", sortOrder: 0)
        let child2 = Item(id: "child-2", title: "Child 2", itemType: .task, parentId: "parent", sortOrder: 1)
        let unrelated = Item(id: "unrelated", title: "Unrelated", itemType: .task)

        try repository.create(parent)
        try repository.create(child1)
        try repository.create(child2)
        try repository.create(unrelated)

        // When
        let children = try repository.getChildItems(parentId: "parent")

        // Then
        XCTAssertEqual(children.count, 2)
        XCTAssertEqual(children[0].id, "child-1")
        XCTAssertEqual(children[1].id, "child-2")
    }

    // MARK: - Update Tests

    func testUpdateItem() throws {
        // Given
        var item = Item(id: "update-test", title: "Original", itemType: .task)
        try repository.create(item)

        // When
        item.title = "Updated"
        item.itemType = .project
        try repository.update(item)

        // Then
        let fetched = try repository.getItem(id: "update-test")
        XCTAssertEqual(fetched?.title, "Updated")
        XCTAssertEqual(fetched?.itemType, .project)
    }

    // MARK: - Delete Tests

    func testDeleteItem() throws {
        // Given
        let item = Item(id: "delete-test", title: "To Delete", itemType: .task)
        try repository.create(item)

        // Verify it exists
        var fetchedItem = try repository.getItem(id: "delete-test")
        XCTAssertNotNil(fetchedItem)

        // When
        try repository.delete(itemId: "delete-test")

        // Then
        fetchedItem = try repository.getItem(id: "delete-test")
        XCTAssertNil(fetchedItem)
    }
}

// MARK: - Test Database Helper

class TestDatabaseWrapper: DatabaseProvider {
    private var testQueue: DatabaseQueue?

    init() {
        // Create an in-memory database for testing
        do {
            testQueue = try DatabaseQueue()
            try setupTestSchema()
        } catch {
            fatalError("Failed to create test database: \(error)")
        }
    }

    private func setupTestSchema() throws {
        guard let queue = testQueue else {
            fatalError("Test queue not initialized")
        }

        try queue.write { db in
            // Create items table
            try db.execute(sql: """
                CREATE TABLE items (
                    id TEXT PRIMARY KEY,
                    title TEXT,
                    item_type TEXT DEFAULT 'Unknown',
                    parent_id TEXT,
                    sort_order INTEGER DEFAULT 0,
                    created_at INTEGER NOT NULL,
                    modified_at INTEGER NOT NULL,
                    completed_at INTEGER,
                    due_date INTEGER,
                    earliest_start_time INTEGER,
                    notes TEXT,
                    FOREIGN KEY (parent_id) REFERENCES items(id) ON DELETE CASCADE
                )
            """)

            // Create tags table
            try db.execute(sql: """
                CREATE TABLE tags (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL UNIQUE,
                    color TEXT
                )
            """)

            // Create item_tags junction table
            try db.execute(sql: """
                CREATE TABLE item_tags (
                    item_id TEXT NOT NULL,
                    tag_id TEXT NOT NULL,
                    PRIMARY KEY (item_id, tag_id),
                    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
                    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
                )
            """)

            // Create time_entries table
            try db.execute(sql: """
                CREATE TABLE time_entries (
                    id TEXT PRIMARY KEY,
                    item_id TEXT NOT NULL,
                    started_at INTEGER NOT NULL,
                    ended_at INTEGER,
                    duration INTEGER,
                    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
                )
            """)

            // Create indexes
            try db.execute(sql: "CREATE INDEX idx_parent_id ON items(parent_id)")
            try db.execute(sql: "CREATE INDEX idx_item_tags_item ON item_tags(item_id)")
            try db.execute(sql: "CREATE INDEX idx_item_tags_tag ON item_tags(tag_id)")
            try db.execute(sql: "CREATE INDEX idx_time_entries_item_id ON time_entries(item_id)")
            try db.execute(sql: "CREATE INDEX idx_time_entries_started_at ON time_entries(started_at)")
        }
    }

    func getQueue() -> DatabaseQueue? {
        return testQueue
    }
}
