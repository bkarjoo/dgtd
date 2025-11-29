import Foundation
import GRDB
import SQLite3

class ItemRepository {
    private let database: DatabaseProvider

    init(database: DatabaseProvider = Database.shared) {
        self.database = database
    }

    // MARK: - Create

    func create(_ item: Item) throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        _ = try dbQueue.write { db in
            try item.insert(db)
        }
    }

    func createTag(_ tag: Tag) throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        _ = try dbQueue.write { db in
            try tag.insert(db)
        }
    }

    func addTagToItem(itemId: String, tagId: String) throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        let itemTag = ItemTag(itemId: itemId, tagId: tagId)
        try dbQueue.write { db in
            try itemTag.insert(db)
        }
    }

    // MARK: - Read

    func getItem(id: String) throws -> Item? {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        return try dbQueue.read { db in
            try Item.fetchOne(db, key: id)
        }
    }

    func getAllItems() throws -> [Item] {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        return try dbQueue.read { db in
            try Item.order(Column("sort_order")).fetchAll(db)
        }
    }

    func getChildItems(parentId: String) throws -> [Item] {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        return try dbQueue.read { db in
            try Item
                .filter(Column("parent_id") == parentId)
                .order(Column("sort_order"))
                .fetchAll(db)
        }
    }

    func getTagsForItem(itemId: String) throws -> [Tag] {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        return try dbQueue.read { db in
            let tagIds = try ItemTag
                .filter(Column("item_id") == itemId)
                .fetchAll(db)
                .map { $0.tagId }

            return try Tag
                .filter(tagIds.contains(Column("id")))
                .fetchAll(db)
        }
    }

    func getAllTags() throws -> [Tag] {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        return try dbQueue.read { db in
            try Tag.order(Column("name")).fetchAll(db)
        }
    }

    // MARK: - Update

    func update(_ item: Item) throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        var updatedItem = item
        updatedItem.modifiedAt = Int(Date().timeIntervalSince1970)

        try dbQueue.write { db in
            try updatedItem.update(db)
        }
    }

    func updateTag(_ tag: Tag) throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        try dbQueue.write { db in
            try tag.update(db)
        }
    }

    // MARK: - Delete

    func delete(itemId: String) throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        _ = try dbQueue.write { db in
            try Item.deleteOne(db, key: itemId)
        }
    }

    func deleteTag(tagId: String) throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        _ = try dbQueue.write { db in
            try Tag.deleteOne(db, key: tagId)
        }
    }

    func removeTagFromItem(itemId: String, tagId: String) throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        try dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM item_tags WHERE item_id = ? AND tag_id = ?",
                arguments: [itemId, tagId]
            )
        }
    }

    // MARK: - Batch Operations

    func getItemTagsForItems(itemIds: [String]) throws -> [ItemTag] {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        return try dbQueue.read { db in
            try ItemTag
                .filter(itemIds.contains(Column("item_id")))
                .fetchAll(db)
        }
    }

    func createItemsWithTags(items: [Item], itemTags: [ItemTag]) throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        try dbQueue.write { db in
            // Create all items
            for item in items {
                try item.insert(db)
            }

            // Create all tag relationships
            for itemTag in itemTags {
                try itemTag.insert(db)
            }
        }
    }

    // MARK: - App Settings

    func getSetting(key: String) throws -> String? {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        return try dbQueue.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT value FROM app_settings WHERE key = ?",
                arguments: [key]
            )
        }
    }

    func setSetting(key: String, value: String?) throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        try dbQueue.write { db in
            if let value = value {
                try db.execute(
                    sql: "INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?)",
                    arguments: [key, value]
                )
            } else {
                try db.execute(
                    sql: "DELETE FROM app_settings WHERE key = ?",
                    arguments: [key]
                )
            }
        }
    }

    // MARK: - Database Observation

    func observeDatabaseChanges(
        onChange: @escaping () -> Void
    ) throws -> DatabaseCancellable {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        let observation = ValueObservation.trackingConstantRegion { db -> (Int, Int, Int) in
            let itemCount = try Item.fetchCount(db)
            let tagCount = try Tag.fetchCount(db)
            let itemTagCount = try ItemTag.fetchCount(db)
            return (itemCount, tagCount, itemTagCount)
        }

        return observation.start(
            in: dbQueue,
            scheduling: .immediate,
            onError: { error in
                print("Database observation error: \(error)")
            },
            onChange: { _ in
                // Schedule callback on main queue
                DispatchQueue.main.async {
                    onChange()
                }
            }
        )
    }

    // MARK: - Saved Searches

    func getAllSavedSearches() throws -> [SavedSearch] {
        guard let queue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        return try queue.read { db in
            try SavedSearch
                .order(Column("sort_order"))
                .fetchAll(db)
        }
    }

    func createSavedSearch(_ search: SavedSearch) throws {
        guard let queue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        try queue.write { db in
            try search.insert(db)
        }
    }

    func updateSavedSearch(_ search: SavedSearch) throws {
        guard let queue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        try queue.write { db in
            try search.update(db)
        }
    }

    func deleteSavedSearch(id: String) throws {
        guard let queue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        try queue.write { db in
            try SavedSearch.deleteOne(db, key: id)
        }
    }

    // MARK: - SQL Query Execution

    func executeSQLQuery(_ sql: String) async throws -> [String] {
        guard let queue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        // Validate that query is a SELECT statement
        let trimmedSQL = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSQL.isEmpty else {
            throw DatabaseError.invalidQuery("Query cannot be empty")
        }

        // Check if query starts with SELECT (case-insensitive)
        let upperSQL = trimmedSQL.uppercased()
        guard upperSQL.hasPrefix("SELECT") else {
            throw DatabaseError.invalidQuery("Only SELECT queries are allowed. PRAGMA, ANALYZE, and other commands are not permitted.")
        }

        // Check for multiple statements (skip semicolons in string literals)
        let semicolonCount = countSemicolonsOutsideStrings(trimmedSQL)

        // Reject queries with more than 1 semicolon (multiple statements)
        // Allow 0 or 1 semicolons (single statement, optionally with trailing ; or ; -- comment)
        if semicolonCount > 1 {
            throw DatabaseError.invalidQuery("Only single SELECT statements are allowed. Multiple statements are not permitted.")
        }

        // Thread-safe box for storing connection handle for interrupt
        final class ConnectionBox: @unchecked Sendable {
            var connection: OpaquePointer?
        }

        let connectionBox = ConnectionBox()

        // Result enum to distinguish success from timeout from other errors
        enum QueryResult {
            case success([String])
            case timeout
            case error(Error)
        }

        // Execute query asynchronously with 250ms timeout and interrupt capability
        let result = try await withThrowingTaskGroup(of: QueryResult.self) { group in
            // Task 1: Execute the query
            group.addTask {
                do {
                    let items = try queue.read { db in
                        // Store connection for potential interrupt
                        connectionBox.connection = db.sqliteConnection

                        // Execute query and extract first column (id) from each row
                        let rows = try Row.fetchAll(db, sql: sql)

                        var itemIds: [String] = []
                        for row in rows {
                            if let id = row[0] as? String {
                                itemIds.append(id)
                            }
                        }

                        return itemIds
                    }
                    return .success(items)
                } catch {
                    // Check if this is an interrupt error (from timeout)
                    // GRDB wraps SQLITE_INTERRUPT in DatabaseError
                    let errorString = String(describing: error)
                    if errorString.contains("interrupt") || errorString.contains("INTERRUPT") {
                        return .timeout
                    } else {
                        // Return actual SQL errors (syntax, invalid column, etc.)
                        return .error(error)
                    }
                }
            }

            // Task 2: Timeout watchdog
            group.addTask {
                try await Task.sleep(nanoseconds: 250_000_000) // 250ms

                // Interrupt the running SQLite query
                if let connection = connectionBox.connection {
                    sqlite3_interrupt(connection)
                }

                return .timeout
            }

            // Wait for first task to complete
            guard let firstResult = try await group.next() else {
                throw DatabaseError.invalidQuery("Query execution failed")
            }

            // Cancel the other task
            group.cancelAll()

            return firstResult
        }

        // Check which task won the race and handle appropriately
        switch result {
        case .success(let items):
            return items
        case .timeout:
            throw DatabaseError.invalidQuery("Query timed out (>250ms)")
        case .error(let error):
            // Re-throw actual SQL errors so users can see real error messages
            throw error
        }
    }

    // Helper: Count semicolons outside of string literals
    // SQLite uses single quotes for strings, doubled quotes for escaping
    private func countSemicolonsOutsideStrings(_ sql: String) -> Int {
        var inString = false
        var semicolonCount = 0
        var i = sql.startIndex

        while i < sql.endIndex {
            let char = sql[i]

            if inString {
                if char == "'" {
                    // Check next character for escaped quote
                    let next = sql.index(after: i)
                    if next < sql.endIndex && sql[next] == "'" {
                        // Doubled quote - skip both
                        i = next
                    } else {
                        // End of string
                        inString = false
                    }
                }
            } else {
                if char == "'" {
                    inString = true
                } else if char == ";" {
                    semicolonCount += 1
                }
            }

            i = sql.index(after: i)
        }

        return semicolonCount
    }
}

// MARK: - Error Handling

enum DatabaseError: Error, LocalizedError {
    case notInitialized
    case itemNotFound
    case invalidQuery(String)

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Database is not initialized"
        case .itemNotFound:
            return "Item not found"
        case .invalidQuery(let message):
            return message
        }
    }
}
