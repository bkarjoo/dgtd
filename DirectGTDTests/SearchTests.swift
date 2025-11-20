import XCTest
import GRDB
@testable import DirectGTD

final class SearchTests: XCTestCase {
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

    // MARK: - searchResults Tests

    func testSearchResultsEmptyWhenSearchTextEmpty() throws {
        // Given - Items exist
        let item1 = Item(id: "1", title: "Task One", itemType: .task)
        let item2 = Item(id: "2", title: "Task Two", itemType: .task)
        try repository.create(item1)
        try repository.create(item2)
        itemStore.loadItems()

        // When - searchText is empty
        itemStore.searchText = ""

        // Then - searchResults should be empty
        XCTAssertTrue(itemStore.searchResults.isEmpty, "searchResults should be empty when searchText is empty")
    }

    func testSearchResultsCaseInsensitive() throws {
        // Given - Items with mixed case titles
        let item1 = Item(id: "1", title: "Buy Groceries", itemType: .task)
        let item2 = Item(id: "2", title: "Call Doctor", itemType: .task)
        try repository.create(item1)
        try repository.create(item2)
        itemStore.loadItems()

        // When - Search with lowercase
        itemStore.searchText = "groceries"

        // Then - Should find the item regardless of case
        XCTAssertEqual(itemStore.searchResults.count, 1)
        XCTAssertEqual(itemStore.searchResults.first?.id, "1")

        // When - Search with uppercase
        itemStore.searchText = "DOCTOR"

        // Then - Should find the item
        XCTAssertEqual(itemStore.searchResults.count, 1)
        XCTAssertEqual(itemStore.searchResults.first?.id, "2")
    }

    func testSearchResultsPartialMatch() throws {
        // Given - Items
        let item1 = Item(id: "1", title: "Complete project documentation", itemType: .task)
        let item2 = Item(id: "2", title: "Review pull request", itemType: .task)
        try repository.create(item1)
        try repository.create(item2)
        itemStore.loadItems()

        // When - Search with partial text
        itemStore.searchText = "project"

        // Then - Should find item containing the text
        XCTAssertEqual(itemStore.searchResults.count, 1)
        XCTAssertEqual(itemStore.searchResults.first?.id, "1")
        XCTAssertEqual(itemStore.searchResults.first?.title, "Complete project documentation")
    }

    func testSearchResultsNoMatch() throws {
        // Given - Items
        let item1 = Item(id: "1", title: "Task One", itemType: .task)
        let item2 = Item(id: "2", title: "Task Two", itemType: .task)
        try repository.create(item1)
        try repository.create(item2)
        itemStore.loadItems()

        // When - Search with non-matching text
        itemStore.searchText = "NonExistentText"

        // Then - Should return empty results
        XCTAssertTrue(itemStore.searchResults.isEmpty)
    }

    func testSearchResultsMultipleMatches() throws {
        // Given - Multiple items with matching text
        let item1 = Item(id: "1", title: "Buy coffee beans", itemType: .task)
        let item2 = Item(id: "2", title: "Buy groceries", itemType: .task)
        let item3 = Item(id: "3", title: "Sell old laptop", itemType: .task)
        try repository.create(item1)
        try repository.create(item2)
        try repository.create(item3)
        itemStore.loadItems()

        // When - Search for "buy"
        itemStore.searchText = "buy"

        // Then - Should return both items with "buy" in title
        XCTAssertEqual(itemStore.searchResults.count, 2)
        let resultIds = itemStore.searchResults.map { $0.id }.sorted()
        XCTAssertEqual(resultIds, ["1", "2"])
    }

    func testSearchResultsIgnoresNilTitles() throws {
        // Given - Item with nil title
        let item1 = Item(id: "1", title: nil, itemType: .task)
        let item2 = Item(id: "2", title: "Valid Title", itemType: .task)
        try repository.create(item1)
        try repository.create(item2)
        itemStore.loadItems()

        // When - Search for any text
        itemStore.searchText = "title"

        // Then - Should only return item with non-nil title
        XCTAssertEqual(itemStore.searchResults.count, 1)
        XCTAssertEqual(itemStore.searchResults.first?.id, "2")
    }

    func testSearchResultsIncludesAllItemTypes() throws {
        // Given - Items of different types
        let task = Item(id: "1", title: "Important task", itemType: .task)
        let project = Item(id: "2", title: "Important project", itemType: .project)
        let note = Item(id: "3", title: "Important note", itemType: .note)
        try repository.create(task)
        try repository.create(project)
        try repository.create(note)
        itemStore.loadItems()

        // When - Search for common text
        itemStore.searchText = "important"

        // Then - Should return all matching items regardless of type
        XCTAssertEqual(itemStore.searchResults.count, 3)
    }

    func testSearchResultsIncludesNestedItems() throws {
        // Given - Hierarchical items
        let parent = Item(id: "parent", title: "Work", itemType: .project, sortOrder: 0)
        let child = Item(id: "child", title: "Client meeting", itemType: .task, parentId: "parent", sortOrder: 0)
        try repository.create(parent)
        try repository.create(child)
        itemStore.loadItems()

        // When - Search for nested item
        itemStore.searchText = "client"

        // Then - Should find the nested item
        XCTAssertEqual(itemStore.searchResults.count, 1)
        XCTAssertEqual(itemStore.searchResults.first?.id, "child")
    }

    func testSearchResultsIncludesCompletedTasks() throws {
        // Given - Completed and incomplete tasks
        let completedTask = Item(id: "1", title: "Finished task", itemType: .task, completedAt: Int(Date().timeIntervalSince1970))
        let pendingTask = Item(id: "2", title: "Pending task", itemType: .task, completedAt: nil)
        try repository.create(completedTask)
        try repository.create(pendingTask)
        itemStore.loadItems()

        // When - Search for "task"
        itemStore.searchText = "task"

        // Then - Should return both completed and pending tasks
        XCTAssertEqual(itemStore.searchResults.count, 2)
    }

    // MARK: - getItemPath Tests

    func testGetItemPathForRootItem() throws {
        // Given - Single root item
        let item = Item(id: "root", title: "Root Item", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        // When - Get path for root item
        let path = itemStore.getItemPath(itemId: "root")

        // Then - Path should be just the item title
        XCTAssertEqual(path, "Root Item")
    }

    func testGetItemPathForNestedItem() throws {
        // Given - Three-level hierarchy
        let grandparent = Item(id: "gp", title: "Projects", itemType: .project, sortOrder: 0)
        let parent = Item(id: "p", title: "Work", itemType: .project, parentId: "gp", sortOrder: 0)
        let child = Item(id: "c", title: "Task", itemType: .task, parentId: "p", sortOrder: 0)
        try repository.create(grandparent)
        try repository.create(parent)
        try repository.create(child)
        itemStore.loadItems()

        // When - Get path for deeply nested item
        let path = itemStore.getItemPath(itemId: "c")

        // Then - Path should show full hierarchy
        XCTAssertEqual(path, "Projects > Work > Task")
    }

    func testGetItemPathForTwoLevelHierarchy() throws {
        // Given - Parent and child
        let parent = Item(id: "parent", title: "Parent Item", itemType: .project, sortOrder: 0)
        let child = Item(id: "child", title: "Child Item", itemType: .task, parentId: "parent", sortOrder: 0)
        try repository.create(parent)
        try repository.create(child)
        itemStore.loadItems()

        // When - Get path for child
        let path = itemStore.getItemPath(itemId: "child")

        // Then - Path should show parent and child
        XCTAssertEqual(path, "Parent Item > Child Item")
    }

    func testGetItemPathSkipsEmptyTitles() throws {
        // Given - Hierarchy with empty title in middle
        let grandparent = Item(id: "gp", title: "Top", itemType: .project, sortOrder: 0)
        let parent = Item(id: "p", title: "", itemType: .project, parentId: "gp", sortOrder: 0)
        let child = Item(id: "c", title: "Bottom", itemType: .task, parentId: "p", sortOrder: 0)
        try repository.create(grandparent)
        try repository.create(parent)
        try repository.create(child)
        itemStore.loadItems()

        // When - Get path for child
        let path = itemStore.getItemPath(itemId: "c")

        // Then - Path should skip empty title
        XCTAssertEqual(path, "Top > Bottom")
    }

    func testGetItemPathForNonExistentItem() throws {
        // Given - Empty store
        // When - Get path for non-existent item
        let path = itemStore.getItemPath(itemId: "non-existent")

        // Then - Path should be empty
        XCTAssertEqual(path, "")
    }

    // MARK: - Integration Tests

    func testSearchAndGetPathIntegration() throws {
        // Given - Complex hierarchy
        let project = Item(id: "proj", title: "Marketing Campaign", itemType: .project, sortOrder: 0)
        let task1 = Item(id: "task1", title: "Design logo", itemType: .task, parentId: "proj", sortOrder: 0)
        let task2 = Item(id: "task2", title: "Design website", itemType: .task, parentId: "proj", sortOrder: 1)
        try repository.create(project)
        try repository.create(task1)
        try repository.create(task2)
        itemStore.loadItems()

        // When - Search for "design"
        itemStore.searchText = "design"

        // Then - Should find both tasks
        XCTAssertEqual(itemStore.searchResults.count, 2)

        // And - Should be able to get paths for results
        for result in itemStore.searchResults {
            let path = itemStore.getItemPath(itemId: result.id)
            XCTAssertTrue(path.contains("Marketing Campaign"))
        }
    }

    func testSearchTextClearsResults() throws {
        // Given - Items and active search
        let item = Item(id: "1", title: "Test Item", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()
        itemStore.searchText = "test"
        XCTAssertEqual(itemStore.searchResults.count, 1)

        // When - Clear search text
        itemStore.searchText = ""

        // Then - Results should be empty
        XCTAssertTrue(itemStore.searchResults.isEmpty)
    }
}
