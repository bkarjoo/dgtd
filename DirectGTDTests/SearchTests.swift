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

    // MARK: - SQL Search Repository Tests

    func testExecuteSQLQueryReturnsMatchingIds() async throws {
        // Given - Items in database
        let item1 = Item(id: "1", title: "Buy groceries", itemType: .task)
        let item2 = Item(id: "2", title: "Call doctor", itemType: .task)
        let item3 = Item(id: "3", title: "Buy coffee", itemType: .task)
        try repository.create(item1)
        try repository.create(item2)
        try repository.create(item3)

        // When - Execute SQL query for items with "buy" in title
        let query = "SELECT id FROM items WHERE title LIKE '%buy%'"
        let results = try await repository.executeSQLQuery(query)

        // Then - Should return matching item IDs
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains("1"))
        XCTAssertTrue(results.contains("3"))
    }

    func testExecuteSQLQueryRejectsEmptyQuery() async throws {
        // When/Then - Empty query should throw
        do {
            _ = try await repository.executeSQLQuery("")
            XCTFail("Should throw invalidQuery error for empty query")
        } catch {
            let errorString = String(describing: error)
            XCTAssertTrue(errorString.contains("Query cannot be empty"),
                         "Expected 'Query cannot be empty', got: \(errorString)")
        }
    }

    func testExecuteSQLQueryRejectsWhitespaceOnlyQuery() async throws {
        // When/Then - Whitespace-only query should throw
        do {
            _ = try await repository.executeSQLQuery("   \n\t  ")
            XCTFail("Should throw invalidQuery error for whitespace-only query")
        } catch {
            let errorString = String(describing: error)
            XCTAssertTrue(errorString.contains("Query cannot be empty"),
                         "Expected 'Query cannot be empty', got: \(errorString)")
        }
    }

    func testExecuteSQLQueryRejectsNonSelectQueries() async throws {
        // Given - Test queries that should be rejected
        let invalidQueries = [
            "UPDATE items SET title = 'hacked'",
            "DELETE FROM items",
            "INSERT INTO items (id, title) VALUES ('x', 'y')",
            "DROP TABLE items",
            "PRAGMA table_info(items)",
            "ANALYZE",
        ]

        for query in invalidQueries {
            // When/Then - Non-SELECT queries should throw
            do {
                _ = try await repository.executeSQLQuery(query)
                XCTFail("Should reject non-SELECT query: \(query)")
            } catch {
                let errorString = String(describing: error)
                XCTAssertTrue(errorString.contains("Only SELECT queries are allowed"),
                             "Expected rejection message for: \(query), got: \(errorString)")
            }
        }
    }

    func testExecuteSQLQueryAllowsSelectQueries() async throws {
        // Given - Item in database
        let item = Item(id: "1", title: "Test", itemType: .task)
        try repository.create(item)

        // When - Execute valid SELECT query
        let query = "SELECT id FROM items WHERE title = 'Test'"
        let results = try await repository.executeSQLQuery(query)

        // Then - Should execute successfully
        XCTAssertEqual(results, ["1"])
    }

    func testExecuteSQLQueryAllowsCTEWithSelect() async throws {
        // Given - Items in database
        let item1 = Item(id: "1", title: "Task 1", itemType: .task)
        let item2 = Item(id: "2", title: "Task 2", itemType: .task)
        try repository.create(item1)
        try repository.create(item2)

        // When - Execute CTE (WITH) query
        let query = """
        WITH filtered AS (
            SELECT id FROM items WHERE title LIKE '%Task%'
        )
        SELECT id FROM filtered
        """
        let results = try await repository.executeSQLQuery(query)

        // Then - Should execute successfully
        XCTAssertEqual(results.count, 2)
    }

    func testExecuteSQLQueryRejectsMultipleStatements() async throws {
        // Given - Query with multiple statements
        let query = "SELECT id FROM items; DROP TABLE items;"

        // When/Then - Should reject multiple statements
        do {
            _ = try await repository.executeSQLQuery(query)
            XCTFail("Should reject query with multiple statements")
        } catch {
            let errorString = String(describing: error)
            XCTAssertTrue(errorString.contains("Multiple statements are not permitted"),
                         "Expected rejection message, got: \(errorString)")
        }
    }

    func testExecuteSQLQueryIgnoresCommentsInValidation() async throws {
        // Given - Query with comments
        let item = Item(id: "1", title: "Test", itemType: .task)
        try repository.create(item)

        let query = """
        -- This is a comment
        /* Block comment */
        SELECT id FROM items
        """

        // When - Execute query with comments
        let results = try await repository.executeSQLQuery(query)

        // Then - Should parse correctly and execute
        XCTAssertEqual(results, ["1"])
    }

    func testExecuteSQLQueryHandlesSyntaxErrors() async throws {
        // Given - Query with syntax error
        let query = "SELECT id FROM nonexistent_table"

        // When/Then - Should throw with helpful error message
        do {
            _ = try await repository.executeSQLQuery(query)
            XCTFail("Should throw error for invalid table")
        } catch {
            // Should get actual SQL error (not wrapped)
            let errorString = String(describing: error)
            XCTAssertTrue(errorString.contains("nonexistent_table") ||
                         errorString.contains("no such table"),
                         "Error should mention the table: \(errorString)")
        }
    }

    func testExecuteSQLQueryExtractsFirstColumnOnly() async throws {
        // Given - Items in database
        let item = Item(id: "1", title: "Test", itemType: .task)
        try repository.create(item)

        // When - Query returns multiple columns
        let query = "SELECT id, title FROM items"
        let results = try await repository.executeSQLQuery(query)

        // Then - Should only extract first column (id)
        XCTAssertEqual(results, ["1"])
    }

    // MARK: - SQL Search ItemStore Tests

    func testExecuteSQLSearchUpdatesState() async throws {
        // Given - Items in database
        let item1 = Item(id: "1", title: "Buy groceries", itemType: .task)
        let item2 = Item(id: "2", title: "Call doctor", itemType: .task)
        try repository.create(item1)
        try repository.create(item2)
        itemStore.loadItems()

        // When - Execute SQL search
        let query = "SELECT id FROM items WHERE title LIKE '%buy%'"
        try await itemStore.executeSQLSearch(query: query)

        // Then - State should be updated
        XCTAssertTrue(itemStore.sqlSearchActive)
        XCTAssertEqual(itemStore.sqlSearchQuery, query)
        XCTAssertEqual(itemStore.sqlSearchResults, ["1"])
    }

    func testExecuteSQLSearchClearsTagFilter() async throws {
        // Given - Tag filter active
        let tag = Tag(name: "urgent", color: "red")
        try repository.createTag(tag)
        itemStore.loadTags()
        itemStore.filteredByTag = tag

        let item = Item(id: "1", title: "Test", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        // When - Execute SQL search
        let query = "SELECT id FROM items"
        try await itemStore.executeSQLSearch(query: query)

        // Then - Tag filter should be cleared (mutual exclusivity)
        XCTAssertNil(itemStore.filteredByTag)
        XCTAssertTrue(itemStore.sqlSearchActive)
    }

    func testClearSQLSearchResetsState() async throws {
        // Given - Active SQL search
        let item = Item(id: "1", title: "Test", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        let query = "SELECT id FROM items"
        try await itemStore.executeSQLSearch(query: query)
        XCTAssertTrue(itemStore.sqlSearchActive)

        // When - Clear SQL search
        itemStore.clearSQLSearch()

        // Then - State should be reset
        XCTAssertFalse(itemStore.sqlSearchActive)
        XCTAssertEqual(itemStore.sqlSearchQuery, "")
        XCTAssertTrue(itemStore.sqlSearchResults.isEmpty)
    }

    func testMatchesSQLSearchReturnsTrueForMatchingItem() throws {
        // Given - Item in SQL results
        let item = Item(id: "1", title: "Test", itemType: .task)
        try repository.create(item)
        itemStore.loadItems()

        itemStore.sqlSearchActive = true
        itemStore.sqlSearchResults = ["1"]

        // When - Check if item matches
        let matches = itemStore.matchesSQLSearch(item)

        // Then - Should match
        XCTAssertTrue(matches)
    }

    func testMatchesSQLSearchReturnsTrueWhenInactive() throws {
        // Given - SQL search inactive
        let item = Item(id: "1", title: "Test", itemType: .task)
        itemStore.sqlSearchActive = false

        // When - Check if item matches
        let matches = itemStore.matchesSQLSearch(item)

        // Then - Should return true (no filter active)
        XCTAssertTrue(matches)
    }

    func testMatchesSQLSearchReturnsTrueForParentOfMatchingChild() throws {
        // Given - Parent and child, child in results
        let parent = Item(id: "parent", title: "Parent", itemType: .project, sortOrder: 0)
        let child = Item(id: "child", title: "Child", itemType: .task, parentId: "parent", sortOrder: 0)
        try repository.create(parent)
        try repository.create(child)
        itemStore.loadItems()

        itemStore.sqlSearchActive = true
        itemStore.sqlSearchResults = ["child"]

        // When - Check if parent matches
        let matches = itemStore.matchesSQLSearch(parent)

        // Then - Should match (shows parents of matching items)
        XCTAssertTrue(matches)
    }

    func testMatchesSQLSearchReturnsTrueForChildOfMatchingParent() throws {
        // Given - Parent and child, parent in results
        let parent = Item(id: "parent", title: "Parent", itemType: .project, sortOrder: 0)
        let child = Item(id: "child", title: "Child", itemType: .task, parentId: "parent", sortOrder: 0)
        try repository.create(parent)
        try repository.create(child)
        itemStore.loadItems()

        itemStore.sqlSearchActive = true
        itemStore.sqlSearchResults = ["parent"]

        // When - Check if child matches
        let matches = itemStore.matchesSQLSearch(child)

        // Then - Should match (shows descendants of matching items)
        XCTAssertTrue(matches)
    }

    func testMatchesSQLSearchReturnsFalseForUnrelatedItem() throws {
        // Given - Items where neither matches nor related
        let item1 = Item(id: "1", title: "Item 1", itemType: .task, sortOrder: 0)
        let item2 = Item(id: "2", title: "Item 2", itemType: .task, sortOrder: 1)
        try repository.create(item1)
        try repository.create(item2)
        itemStore.loadItems()

        itemStore.sqlSearchActive = true
        itemStore.sqlSearchResults = ["1"]

        // When - Check if item2 matches
        let matches = itemStore.matchesSQLSearch(item2)

        // Then - Should not match
        XCTAssertFalse(matches)
    }

    func testHasDescendantInSQLResultsWithDirectChild() throws {
        // Given - Parent with child in results
        let parent = Item(id: "parent", title: "Parent", itemType: .project, sortOrder: 0)
        let child = Item(id: "child", title: "Child", itemType: .task, parentId: "parent", sortOrder: 0)
        try repository.create(parent)
        try repository.create(child)
        itemStore.loadItems()

        itemStore.sqlSearchResults = ["child"]

        // When - Check if parent has descendant in results
        let hasDescendant = itemStore.hasDescendantInSQLResults(parent, allItems: itemStore.items)

        // Then - Should return true
        XCTAssertTrue(hasDescendant)
    }

    func testHasDescendantInSQLResultsWithNestedDescendant() throws {
        // Given - Three-level hierarchy with grandchild in results
        let grandparent = Item(id: "gp", title: "GP", itemType: .project, sortOrder: 0)
        let parent = Item(id: "p", title: "P", itemType: .project, parentId: "gp", sortOrder: 0)
        let child = Item(id: "c", title: "C", itemType: .task, parentId: "p", sortOrder: 0)
        try repository.create(grandparent)
        try repository.create(parent)
        try repository.create(child)
        itemStore.loadItems()

        itemStore.sqlSearchResults = ["c"]

        // When - Check if grandparent has descendant in results
        let hasDescendant = itemStore.hasDescendantInSQLResults(grandparent, allItems: itemStore.items)

        // Then - Should return true (recursive check)
        XCTAssertTrue(hasDescendant)
    }

    func testHasDescendantInSQLResultsReturnsFalseWhenNoMatch() throws {
        // Given - Parent with child not in results
        let parent = Item(id: "parent", title: "Parent", itemType: .project, sortOrder: 0)
        let child = Item(id: "child", title: "Child", itemType: .task, parentId: "parent", sortOrder: 0)
        try repository.create(parent)
        try repository.create(child)
        itemStore.loadItems()

        itemStore.sqlSearchResults = ["other_id"]

        // When - Check if parent has descendant in results
        let hasDescendant = itemStore.hasDescendantInSQLResults(parent, allItems: itemStore.items)

        // Then - Should return false
        XCTAssertFalse(hasDescendant)
    }

    func testHasAncestorInSQLResultsWithDirectParent() throws {
        // Given - Parent in results, child not
        let parent = Item(id: "parent", title: "Parent", itemType: .project, sortOrder: 0)
        let child = Item(id: "child", title: "Child", itemType: .task, parentId: "parent", sortOrder: 0)
        try repository.create(parent)
        try repository.create(child)
        itemStore.loadItems()

        itemStore.sqlSearchResults = ["parent"]

        // When - Check if child has ancestor in results
        let hasAncestor = itemStore.hasAncestorInSQLResults(child, allItems: itemStore.items)

        // Then - Should return true
        XCTAssertTrue(hasAncestor)
    }

    func testHasAncestorInSQLResultsWithDistantAncestor() throws {
        // Given - Three-level hierarchy with grandparent in results
        let grandparent = Item(id: "gp", title: "GP", itemType: .project, sortOrder: 0)
        let parent = Item(id: "p", title: "P", itemType: .project, parentId: "gp", sortOrder: 0)
        let child = Item(id: "c", title: "C", itemType: .task, parentId: "p", sortOrder: 0)
        try repository.create(grandparent)
        try repository.create(parent)
        try repository.create(child)
        itemStore.loadItems()

        itemStore.sqlSearchResults = ["gp"]

        // When - Check if child has ancestor in results
        let hasAncestor = itemStore.hasAncestorInSQLResults(child, allItems: itemStore.items)

        // Then - Should return true (climbs to grandparent)
        XCTAssertTrue(hasAncestor)
    }

    func testHasAncestorInSQLResultsReturnsFalseForRootItem() throws {
        // Given - Root item (no parent)
        let item = Item(id: "root", title: "Root", itemType: .task, sortOrder: 0)
        try repository.create(item)
        itemStore.loadItems()

        itemStore.sqlSearchResults = ["other_id"]

        // When - Check if root item has ancestor in results
        let hasAncestor = itemStore.hasAncestorInSQLResults(item, allItems: itemStore.items)

        // Then - Should return false (no ancestors)
        XCTAssertFalse(hasAncestor)
    }

    // MARK: - Saved Searches Tests

    func testSaveSQLSearchCreatesAndLoads() throws {
        // Given - ItemStore ready
        let searchName = "Urgent Tasks"
        let searchSQL = "SELECT id FROM items WHERE title LIKE '%urgent%'"

        // When - Save SQL search
        try itemStore.saveSQLSearch(name: searchName, sql: searchSQL)

        // Then - Should be in saved searches
        XCTAssertEqual(itemStore.savedSearches.count, 1)
        XCTAssertEqual(itemStore.savedSearches.first?.name, searchName)
        XCTAssertEqual(itemStore.savedSearches.first?.sql, searchSQL)
    }

    func testLoadSavedSearchesRetrievesAll() throws {
        // Given - Multiple saved searches in repository
        let search1 = SavedSearch(id: "1", name: "Search 1", sql: "SELECT id FROM items WHERE title LIKE '%a%'", sortOrder: 0, createdAt: 100, modifiedAt: 100)
        let search2 = SavedSearch(id: "2", name: "Search 2", sql: "SELECT id FROM items WHERE title LIKE '%b%'", sortOrder: 1, createdAt: 200, modifiedAt: 200)
        try repository.createSavedSearch(search1)
        try repository.createSavedSearch(search2)

        // When - Load saved searches
        itemStore.loadSavedSearches()

        // Then - Should retrieve all searches
        XCTAssertEqual(itemStore.savedSearches.count, 2)
        XCTAssertEqual(itemStore.savedSearches[0].name, "Search 1")
        XCTAssertEqual(itemStore.savedSearches[1].name, "Search 2")
    }

    func testGetAllSavedSearchesReturnsSortedByOrder() throws {
        // Given - Searches with different sort orders
        let search1 = SavedSearch(id: "1", name: "C", sql: "SELECT id FROM items", sortOrder: 2, createdAt: 100, modifiedAt: 100)
        let search2 = SavedSearch(id: "2", name: "A", sql: "SELECT id FROM items", sortOrder: 0, createdAt: 200, modifiedAt: 200)
        let search3 = SavedSearch(id: "3", name: "B", sql: "SELECT id FROM items", sortOrder: 1, createdAt: 300, modifiedAt: 300)
        try repository.createSavedSearch(search1)
        try repository.createSavedSearch(search2)
        try repository.createSavedSearch(search3)

        // When - Get all saved searches
        let searches = try repository.getAllSavedSearches()

        // Then - Should be sorted by sort_order
        XCTAssertEqual(searches.count, 3)
        XCTAssertEqual(searches[0].name, "A") // sortOrder 0
        XCTAssertEqual(searches[1].name, "B") // sortOrder 1
        XCTAssertEqual(searches[2].name, "C") // sortOrder 2
    }

    // MARK: - Integration Tests

    func testSQLSearchFilteringIntegration() async throws {
        // Given - Hierarchical items
        let project = Item(id: "proj", title: "Project A", itemType: .project, sortOrder: 0)
        let task1 = Item(id: "task1", title: "Important task", itemType: .task, parentId: "proj", sortOrder: 0)
        let task2 = Item(id: "task2", title: "Regular task", itemType: .task, parentId: "proj", sortOrder: 1)
        try repository.create(project)
        try repository.create(task1)
        try repository.create(task2)
        itemStore.loadItems()

        // When - Execute SQL search for "important"
        let query = "SELECT id FROM items WHERE title LIKE '%important%'"
        try await itemStore.executeSQLSearch(query: query)

        // Then - Only matching item and its ancestors should be visible
        XCTAssertTrue(itemStore.matchesSQLSearch(task1), "Matching task should be visible")
        XCTAssertTrue(itemStore.matchesSQLSearch(project), "Parent of matching task should be visible")
        XCTAssertFalse(itemStore.matchesSQLSearch(task2), "Non-matching task should be hidden")
    }
}
