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

    /// Atomically duplicates items: shifts siblings, creates new items, and copies tags in a single transaction
    func duplicateItems(siblingsToUpdate: [Item], newItems: [Item], itemTags: [ItemTag]) throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        let now = Int(Date().timeIntervalSince1970)

        try dbQueue.write { db in
            // Update siblings' sort order (with updated modifiedAt to match repository.update behavior)
            for sibling in siblingsToUpdate {
                var updatedSibling = sibling
                updatedSibling.modifiedAt = now
                try updatedSibling.update(db)
            }

            // Create all new items
            for item in newItems {
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

        let observation = ValueObservation.trackingConstantRegion { db -> (Int, Int, Int, Int) in
            let itemCount = try Item.fetchCount(db)
            let tagCount = try Tag.fetchCount(db)
            let itemTagCount = try ItemTag.fetchCount(db)
            let timeEntryCount = try TimeEntry.fetchCount(db)
            return (itemCount, tagCount, itemTagCount, timeEntryCount)
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

        // Normalize query text
        let trimmedSQL = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSQL.isEmpty else {
            throw DatabaseError.invalidQuery("Query cannot be empty")
        }

        // Determine first meaningful SQL keyword (ignoring comments/parentheses)
        guard let firstKeyword = firstSQLKeyword(in: trimmedSQL)?.uppercased() else {
            throw DatabaseError.invalidQuery("Unable to parse SQL query.")
        }

        // Allow SELECT or CTEs (WITH ... SELECT). Reject everything else (PRAGMA, etc.)
        guard firstKeyword == "SELECT" || firstKeyword == "WITH" else {
            throw DatabaseError.invalidQuery("Only SELECT queries are allowed. PRAGMA, ANALYZE, and other commands are not permitted.")
        }

        // Check for multiple statements (parse SQL to detect statement boundaries)
        // Must handle string literals, line comments (--), and block comments (/* */)
        if hasMultipleStatements(trimmedSQL) {
            throw DatabaseError.invalidQuery("Only single SELECT statements are allowed. Multiple statements are not permitted.")
        }

        // Thread-safe box for storing connection handle for interrupt
        final class ConnectionBox: @unchecked Sendable {
            private let lock = NSLock()
            private var connection: OpaquePointer?

            func set(_ value: OpaquePointer?) {
                lock.lock()
                connection = value
                lock.unlock()
            }

            func get() -> OpaquePointer? {
                lock.lock()
                let value = connection
                lock.unlock()
                return value
            }
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
                        connectionBox.set(db.sqliteConnection)

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
                if let connection = connectionBox.get() {
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

    // Helper: Retrieve first meaningful SQL keyword (ignores whitespace, parentheses, and comments)
    private func firstSQLKeyword(in sql: String) -> String? {
        var i = sql.startIndex
        var inLineComment = false
        var inBlockComment = false

        while i < sql.endIndex {
            let char = sql[i]

            if inLineComment {
                if char == "\n" {
                    inLineComment = false
                }
                i = sql.index(after: i)
                continue
            }

            if inBlockComment {
                if char == "*" {
                    let next = sql.index(after: i)
                    if next < sql.endIndex && sql[next] == "/" {
                        inBlockComment = false
                        i = sql.index(after: next)
                        continue
                    }
                }
                i = sql.index(after: i)
                continue
            }

            if char.isWhitespace {
                i = sql.index(after: i)
                continue
            }

            if char == "-" {
                let next = sql.index(after: i)
                if next < sql.endIndex && sql[next] == "-" {
                    inLineComment = true
                    i = sql.index(after: next)
                    continue
                }
            }

            if char == "/" {
                let next = sql.index(after: i)
                if next < sql.endIndex && sql[next] == "*" {
                    inBlockComment = true
                    i = sql.index(after: next)
                    continue
                }
            }

            if char == "(" {
                i = sql.index(after: i)
                continue
            }

            // Extract keyword (letters/underscores)
            if char.isLetter {
                var end = i
                while end < sql.endIndex {
                    let nextChar = sql[end]
                    if nextChar.isLetter || nextChar == "_" {
                        end = sql.index(after: end)
                    } else {
                        break
                    }
                }
                if end > i {
                    return String(sql[i..<end])
                }
            }

            // Non-letter token encountered
            break
        }

        return nil
    }

    // Helper: Check if SQL contains multiple statements
    // Handles string literals ('...' with '' escaping), line comments (--), and block comments (/* */)
    // Returns true if multiple statements detected (semicolon followed by non-comment content)
    private func hasMultipleStatements(_ sql: String) -> Bool {
        var inString = false
        var inLineComment = false
        var inBlockComment = false
        var foundFirstSemicolon = false
        var hasContentAfterSemicolon = false
        var i = sql.startIndex

        while i < sql.endIndex {
            let char = sql[i]

            if inString {
                // Inside string literal
                if char == "'" {
                    let next = sql.index(after: i)
                    if next < sql.endIndex && sql[next] == "'" {
                        // Doubled quote (escape) - skip both
                        i = next
                    } else {
                        // End of string
                        inString = false
                    }
                }
            } else if inLineComment {
                // Inside line comment (-- to newline)
                if char == "\n" {
                    inLineComment = false
                }
            } else if inBlockComment {
                // Inside block comment (/* to */)
                if char == "*" {
                    let next = sql.index(after: i)
                    if next < sql.endIndex && sql[next] == "/" {
                        inBlockComment = false
                        i = next // Skip the '/'
                    }
                }
            } else {
                // Not in string or comment - actual SQL code
                if char == "-" {
                    let next = sql.index(after: i)
                    if next < sql.endIndex && sql[next] == "-" {
                        // Start of line comment
                        inLineComment = true
                        i = next // Skip second '-'
                    }
                } else if char == "/" {
                    let next = sql.index(after: i)
                    if next < sql.endIndex && sql[next] == "*" {
                        // Start of block comment
                        inBlockComment = true
                        i = next // Skip '*'
                    }
                } else if char == "'" {
                    // Start of string literal
                    if foundFirstSemicolon {
                        // SQL code after semicolon = multiple statements
                        hasContentAfterSemicolon = true
                    }
                    inString = true
                } else if char == ";" {
                    // Semicolon found
                    if !foundFirstSemicolon {
                        foundFirstSemicolon = true
                    } else {
                        // Second semicolon = multiple statements
                        return true
                    }
                } else if !char.isWhitespace {
                    // Non-whitespace character
                    if foundFirstSemicolon {
                        // SQL code after semicolon = multiple statements
                        hasContentAfterSemicolon = true
                    }
                }
            }

            i = sql.index(after: i)
        }

        return hasContentAfterSemicolon
    }

    // MARK: - Time Entries

    /// Creates a new time entry
    func createTimeEntry(_ entry: TimeEntry) throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        try dbQueue.write { db in
            try entry.insert(db)
        }
    }

    /// Updates an existing time entry
    func updateTimeEntry(_ entry: TimeEntry) throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        try dbQueue.write { db in
            try entry.update(db)
        }
    }

    /// Deletes a time entry by ID
    func deleteTimeEntry(id: String) throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        try dbQueue.write { db in
            try TimeEntry.deleteOne(db, key: id)
        }
    }

    /// Gets a time entry by ID
    func getTimeEntry(id: String) throws -> TimeEntry? {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        return try dbQueue.read { db in
            try TimeEntry.fetchOne(db, key: id)
        }
    }

    /// Gets all time entries for a specific item, ordered by started_at descending
    func getTimeEntriesForItem(itemId: String) throws -> [TimeEntry] {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        return try dbQueue.read { db in
            try TimeEntry
                .filter(Column("item_id") == itemId)
                .order(Column("started_at").desc)
                .fetchAll(db)
        }
    }

    /// Gets all currently running time entries (ended_at IS NULL)
    func getActiveTimeEntries() throws -> [TimeEntry] {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        return try dbQueue.read { db in
            try TimeEntry
                .filter(Column("ended_at") == nil)
                .order(Column("started_at").desc)
                .fetchAll(db)
        }
    }

    /// Gets the most recent running time entry for a specific item, if any
    func getActiveTimeEntryForItem(itemId: String) throws -> TimeEntry? {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        return try dbQueue.read { db in
            try TimeEntry
                .filter(Column("item_id") == itemId)
                .filter(Column("ended_at") == nil)
                .order(Column("started_at").desc)
                .fetchOne(db)
        }
    }

    /// Calculates total tracked time (in seconds) for an item from completed entries
    func getTotalTimeForItem(itemId: String) throws -> Int {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        return try dbQueue.read { db in
            let total = try Int.fetchOne(
                db,
                sql: "SELECT COALESCE(SUM(duration), 0) FROM time_entries WHERE item_id = ? AND duration IS NOT NULL",
                arguments: [itemId]
            )
            return total ?? 0
        }
    }

    /// Gets total tracked time for multiple items at once (for efficient batch loading)
    /// Chunks requests to avoid SQLite's 999 variable limit
    func getTotalTimesForItems(itemIds: [String]) throws -> [String: Int] {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        guard !itemIds.isEmpty else { return [:] }

        // SQLite has a default limit of 999 variables; chunk to stay well under
        let chunkSize = 500
        var result: [String: Int] = [:]

        return try dbQueue.read { db in
            for chunk in itemIds.chunked(into: chunkSize) {
                let placeholders = chunk.map { _ in "?" }.joined(separator: ", ")
                let sql = """
                    SELECT item_id, COALESCE(SUM(duration), 0) as total
                    FROM time_entries
                    WHERE item_id IN (\(placeholders)) AND duration IS NOT NULL
                    GROUP BY item_id
                """

                let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(chunk))
                for row in rows {
                    if let itemId = row["item_id"] as? String,
                       let total = row["total"] as? Int {
                        result[itemId] = total
                    }
                }
            }
            return result
        }
    }

    /// Stops a time entry by setting ended_at and calculating duration (transactional)
    func stopTimeEntry(id: String, endedAt: Int = Int(Date().timeIntervalSince1970)) throws -> TimeEntry? {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        return try dbQueue.write { db in
            guard var entry = try TimeEntry.fetchOne(db, key: id) else {
                return nil
            }

            // Only stop if not already stopped
            guard entry.endedAt == nil else {
                return entry
            }

            entry.endedAt = endedAt
            entry.duration = endedAt - entry.startedAt
            try entry.update(db)
            return entry
        }
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

// MARK: - Array Chunking Extension

extension Array {
    /// Splits the array into chunks of the specified size
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
