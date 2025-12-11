import Foundation
import GRDB
import SQLite3

public class ItemRepository {
    private let database: DatabaseProvider

    public init(database: DatabaseProvider) {
        self.database = database
    }

    // MARK: - Create

    public func create(_ item: Item) throws {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        var newItem = item
        newItem.needsPush = 1
        let now = Int(Date().timeIntervalSince1970)
        newItem.modifiedAt = now
        if newItem.ckRecordName == nil {
            newItem.ckRecordName = "Item_\(newItem.id)"
        }

        _ = try dbQueue.write { db in
            try newItem.insert(db)
        }
    }

    public func createTag(_ tag: Tag) throws {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        var newTag = tag
        newTag.needsPush = 1
        let now = Int(Date().timeIntervalSince1970)
        newTag.modifiedAt = now
        if newTag.ckRecordName == nil {
            newTag.ckRecordName = "Tag_\(newTag.id)"
        }

        _ = try dbQueue.write { db in
            try newTag.insert(db)
        }
    }

    public func addTagToItem(itemId: String, tagId: String) throws {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        let now = Int(Date().timeIntervalSince1970)

        try dbQueue.write { db in
            // Use INSERT OR REPLACE to handle tombstoned rows (deleted_at was set)
            // This will either insert a new row or replace an existing one (including tombstones)
            try db.execute(
                sql: """
                    INSERT INTO item_tags (item_id, tag_id, created_at, modified_at, ck_record_name, needs_push, deleted_at)
                    VALUES (?, ?, ?, ?, ?, 1, NULL)
                    ON CONFLICT(item_id, tag_id) DO UPDATE SET
                        deleted_at = NULL,
                        needs_push = 1,
                        modified_at = excluded.modified_at
                """,
                arguments: [itemId, tagId, now, now, "ItemTag_\(itemId)_\(tagId)"]
            )
        }
    }

    // MARK: - Read

    public func getItem(id: String) throws -> Item? {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        return try dbQueue.read { db in
            try Item
                .filter(Column("id") == id)
                .filter(Column("deleted_at") == nil)
                .fetchOne(db)
        }
    }

    public func getAllItems() throws -> [Item] {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        return try dbQueue.read { db in
            try Item
                .filter(Column("deleted_at") == nil)
                .order(Column("sort_order"))
                .fetchAll(db)
        }
    }

    public func getChildItems(parentId: String) throws -> [Item] {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        return try dbQueue.read { db in
            try Item
                .filter(Column("parent_id") == parentId)
                .filter(Column("deleted_at") == nil)
                .order(Column("sort_order"))
                .fetchAll(db)
        }
    }

    public func getTagsForItem(itemId: String) throws -> [Tag] {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        return try dbQueue.read { db in
            let tagIds = try ItemTag
                .filter(Column("item_id") == itemId)
                .filter(Column("deleted_at") == nil)
                .fetchAll(db)
                .map { $0.tagId }

            return try Tag
                .filter(tagIds.contains(Column("id")))
                .filter(Column("deleted_at") == nil)
                .fetchAll(db)
        }
    }

    public func getAllTags() throws -> [Tag] {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        return try dbQueue.read { db in
            try Tag
                .filter(Column("deleted_at") == nil)
                .order(Column("name"))
                .fetchAll(db)
        }
    }

    // MARK: - Update

    public func update(_ item: Item) throws {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        var updatedItem = item
        updatedItem.modifiedAt = Int(Date().timeIntervalSince1970)
        updatedItem.needsPush = 1

        try dbQueue.write { db in
            try updatedItem.update(db)
        }
    }

    public func updateTag(_ tag: Tag) throws {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        var updatedTag = tag
        updatedTag.modifiedAt = Int(Date().timeIntervalSince1970)
        updatedTag.needsPush = 1

        try dbQueue.write { db in
            try updatedTag.update(db)
        }
    }

    // MARK: - Delete (Soft-Delete)

    /// Soft-deletes an item by ID. Use SoftDeleteService.softDeleteItem for cascade deletion.
    public func delete(itemId: String) throws {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        let now = Int(Date().timeIntervalSince1970)
        try dbQueue.write { db in
            // Soft-delete the item (note: this doesn't cascade - use SoftDeleteService for that)
            try db.execute(
                sql: """
                    UPDATE items
                    SET deleted_at = ?, needs_push = 1, modified_at = ?
                    WHERE id = ? AND deleted_at IS NULL
                """,
                arguments: [now, now, itemId]
            )
        }
    }

    /// Soft-deletes a tag by ID. Use SoftDeleteService.softDeleteTag for cascade deletion.
    public func deleteTag(tagId: String) throws {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        let now = Int(Date().timeIntervalSince1970)
        try dbQueue.write { db in
            // Soft-delete the tag (note: this doesn't cascade - use SoftDeleteService for that)
            try db.execute(
                sql: """
                    UPDATE tags
                    SET deleted_at = ?, needs_push = 1, modified_at = ?
                    WHERE id = ? AND deleted_at IS NULL
                """,
                arguments: [now, now, tagId]
            )
        }
    }

    public func removeTagFromItem(itemId: String, tagId: String) throws {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        let now = Int(Date().timeIntervalSince1970)
        try dbQueue.write { db in
            // Soft-delete the item_tag association
            try db.execute(
                sql: """
                    UPDATE item_tags
                    SET deleted_at = ?, needs_push = 1, modified_at = ?
                    WHERE item_id = ? AND tag_id = ? AND deleted_at IS NULL
                """,
                arguments: [now, now, itemId, tagId]
            )
        }
    }

    // MARK: - Undelete (Restore soft-deleted records)

    /// SQLite has a limit of 999 bound variables, so we chunk large ID lists
    private static let chunkSize = 500

    /// Restores a soft-deleted item and its related item_tags/time_entries
    public func undeleteItemsWithTags(itemIds: [String], itemTagKeys: [(itemId: String, tagId: String)]) throws {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        let now = Int(Date().timeIntervalSince1970)

        try dbQueue.write { db in
            // Restore all items (one at a time is fine, no IN clause needed)
            for itemId in itemIds {
                try db.execute(
                    sql: """
                        UPDATE items
                        SET deleted_at = NULL, needs_push = 1, modified_at = ?
                        WHERE id = ?
                    """,
                    arguments: [now, itemId]
                )
            }

            // Restore item_tag associations (one at a time is fine, no IN clause needed)
            for (itemId, tagId) in itemTagKeys {
                try db.execute(
                    sql: """
                        UPDATE item_tags
                        SET deleted_at = NULL, needs_push = 1, modified_at = ?
                        WHERE item_id = ? AND tag_id = ?
                    """,
                    arguments: [now, itemId, tagId]
                )
            }

            // Restore time_entries for these items - chunk to avoid 999 variable limit
            for chunk in itemIds.chunked(into: ItemRepository.chunkSize) {
                let placeholders = chunk.map { _ in "?" }.joined(separator: ", ")
                try db.execute(
                    sql: """
                        UPDATE time_entries
                        SET deleted_at = NULL, needs_push = 1, modified_at = ?
                        WHERE item_id IN (\(placeholders))
                    """,
                    arguments: StatementArguments([now] + chunk)
                )
            }
        }
    }

    /// Restores a soft-deleted tag and its item_tag associations
    public func undeleteTag(tagId: String, itemIds: [String]) throws {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        let now = Int(Date().timeIntervalSince1970)

        try dbQueue.write { db in
            // Restore the tag
            try db.execute(
                sql: """
                    UPDATE tags
                    SET deleted_at = NULL, needs_push = 1, modified_at = ?
                    WHERE id = ?
                """,
                arguments: [now, tagId]
            )

            // Restore item_tag associations
            for itemId in itemIds {
                try db.execute(
                    sql: """
                        UPDATE item_tags
                        SET deleted_at = NULL, needs_push = 1, modified_at = ?
                        WHERE item_id = ? AND tag_id = ?
                    """,
                    arguments: [now, itemId, tagId]
                )
            }
        }
    }

    // MARK: - Batch Operations

    public func getItemTagsForItems(itemIds: [String]) throws -> [ItemTag] {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        return try dbQueue.read { db in
            try ItemTag
                .filter(itemIds.contains(Column("item_id")))
                .filter(Column("deleted_at") == nil)
                .fetchAll(db)
        }
    }

    public func createItemsWithTags(items: [Item], itemTags: [ItemTag]) throws {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        let now = Int(Date().timeIntervalSince1970)

        try dbQueue.write { db in
            // Create all items
            for item in items {
                var newItem = item
                newItem.needsPush = 1
                newItem.modifiedAt = now
                if newItem.ckRecordName == nil {
                    newItem.ckRecordName = "Item_\(newItem.id)"
                }
                try newItem.insert(db)
            }

            // Create all tag relationships
            for itemTag in itemTags {
                var newItemTag = itemTag
                newItemTag.needsPush = 1
                newItemTag.modifiedAt = now
                try newItemTag.insert(db)
            }
        }
    }

    /// Atomically duplicates items: shifts siblings, creates new items, and copies tags in a single transaction
    public func duplicateItems(siblingsToUpdate: [Item], newItems: [Item], itemTags: [ItemTag]) throws {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        let now = Int(Date().timeIntervalSince1970)

        try dbQueue.write { db in
            // Update siblings' sort order (with updated modifiedAt to match repository.update behavior)
            for sibling in siblingsToUpdate {
                var updatedSibling = sibling
                updatedSibling.modifiedAt = now
                updatedSibling.needsPush = 1
                try updatedSibling.update(db)
            }

            // Create all new items
            for item in newItems {
                var newItem = item
                newItem.needsPush = 1
                newItem.modifiedAt = now
                if newItem.ckRecordName == nil {
                    newItem.ckRecordName = "Item_\(newItem.id)"
                }
                try newItem.insert(db)
            }

            // Create all tag relationships
            for itemTag in itemTags {
                var newItemTag = itemTag
                newItemTag.needsPush = 1
                newItemTag.modifiedAt = now
                try newItemTag.insert(db)
            }
        }
    }

    // MARK: - App Settings

    public func getSetting(key: String) throws -> String? {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        return try dbQueue.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT value FROM app_settings WHERE key = ?",
                arguments: [key]
            )
        }
    }

    public func setSetting(key: String, value: String?) throws {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
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

    public func observeDatabaseChanges(
        onChange: @escaping () -> Void
    ) throws -> DatabaseCancellable {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        // Track both counts and max modification times to detect any changes
        // Use .tracking instead of .trackingConstantRegion for reliable change detection
        let observation = ValueObservation.tracking { db -> (Int, Int?) in
            let itemCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items WHERE deleted_at IS NULL") ?? 0
            let maxModified = try Int.fetchOne(db, sql: "SELECT MAX(modified_at) FROM items")
            return (itemCount, maxModified)
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

    public func getAllSavedSearches() throws -> [SavedSearch] {
        guard let queue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        return try queue.read { db in
            try SavedSearch
                .filter(Column("deleted_at") == nil)
                .order(Column("sort_order"))
                .fetchAll(db)
        }
    }

    public func createSavedSearch(_ search: SavedSearch) throws {
        guard let queue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        var newSearch = search
        newSearch.needsPush = 1
        let now = Int(Date().timeIntervalSince1970)
        newSearch.modifiedAt = now
        if newSearch.ckRecordName == nil {
            newSearch.ckRecordName = "SavedSearch_\(newSearch.id)"
        }

        try queue.write { db in
            try newSearch.insert(db)
        }
    }

    public func updateSavedSearch(_ search: SavedSearch) throws {
        guard let queue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        var updatedSearch = search
        updatedSearch.modifiedAt = Int(Date().timeIntervalSince1970)
        updatedSearch.needsPush = 1

        try queue.write { db in
            try updatedSearch.update(db)
        }
    }

    public func deleteSavedSearch(id: String) throws {
        guard let queue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        let now = Int(Date().timeIntervalSince1970)
        try queue.write { db in
            // Soft-delete the saved search
            try db.execute(
                sql: """
                    UPDATE saved_searches
                    SET deleted_at = ?, needs_push = 1, modified_at = ?
                    WHERE id = ? AND deleted_at IS NULL
                """,
                arguments: [now, now, id]
            )
        }
    }

    // MARK: - SQL Query Execution

    public func executeSQLQuery(_ sql: String) async throws -> [String] {
        guard let queue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        // Normalize query text
        let trimmedSQL = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSQL.isEmpty else {
            throw RepositoryError.invalidQuery("Query cannot be empty")
        }

        // Determine first meaningful SQL keyword (ignoring comments/parentheses)
        guard let firstKeyword = firstSQLKeyword(in: trimmedSQL)?.uppercased() else {
            throw RepositoryError.invalidQuery("Unable to parse SQL query.")
        }

        // Allow SELECT or CTEs (WITH ... SELECT). Reject everything else (PRAGMA, etc.)
        guard firstKeyword == "SELECT" || firstKeyword == "WITH" else {
            throw RepositoryError.invalidQuery("Only SELECT queries are allowed. PRAGMA, ANALYZE, and other commands are not permitted.")
        }

        // Check for multiple statements (parse SQL to detect statement boundaries)
        // Must handle string literals, line comments (--), and block comments (/* */)
        if hasMultipleStatements(trimmedSQL) {
            throw RepositoryError.invalidQuery("Only single SELECT statements are allowed. Multiple statements are not permitted.")
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
                throw RepositoryError.invalidQuery("Query execution failed")
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
            throw RepositoryError.invalidQuery("Query timed out (>250ms)")
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
    public func createTimeEntry(_ entry: TimeEntry) throws {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        var newEntry = entry
        newEntry.needsPush = 1
        let now = Int(Date().timeIntervalSince1970)
        newEntry.modifiedAt = now
        if newEntry.ckRecordName == nil {
            newEntry.ckRecordName = "TimeEntry_\(newEntry.id)"
        }

        try dbQueue.write { db in
            try newEntry.insert(db)
        }
    }

    /// Updates an existing time entry
    public func updateTimeEntry(_ entry: TimeEntry) throws {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        var updatedEntry = entry
        updatedEntry.modifiedAt = Int(Date().timeIntervalSince1970)
        updatedEntry.needsPush = 1

        try dbQueue.write { db in
            try updatedEntry.update(db)
        }
    }

    /// Deletes a time entry by ID (soft-delete)
    public func deleteTimeEntry(id: String) throws {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        let now = Int(Date().timeIntervalSince1970)
        try dbQueue.write { db in
            // Soft-delete the time entry
            try db.execute(
                sql: """
                    UPDATE time_entries
                    SET deleted_at = ?, needs_push = 1, modified_at = ?
                    WHERE id = ? AND deleted_at IS NULL
                """,
                arguments: [now, now, id]
            )
        }
    }

    /// Gets a time entry by ID
    public func getTimeEntry(id: String) throws -> TimeEntry? {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        return try dbQueue.read { db in
            try TimeEntry
                .filter(Column("id") == id)
                .filter(Column("deleted_at") == nil)
                .fetchOne(db)
        }
    }

    /// Gets all time entries for a specific item, ordered by started_at descending
    public func getTimeEntriesForItem(itemId: String) throws -> [TimeEntry] {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        return try dbQueue.read { db in
            try TimeEntry
                .filter(Column("item_id") == itemId)
                .filter(Column("deleted_at") == nil)
                .order(Column("started_at").desc)
                .fetchAll(db)
        }
    }

    /// Gets all currently running time entries (ended_at IS NULL)
    public func getActiveTimeEntries() throws -> [TimeEntry] {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        return try dbQueue.read { db in
            try TimeEntry
                .filter(Column("ended_at") == nil)
                .filter(Column("deleted_at") == nil)
                .order(Column("started_at").desc)
                .fetchAll(db)
        }
    }

    /// Gets the most recent running time entry for a specific item, if any
    public func getActiveTimeEntryForItem(itemId: String) throws -> TimeEntry? {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        return try dbQueue.read { db in
            try TimeEntry
                .filter(Column("item_id") == itemId)
                .filter(Column("ended_at") == nil)
                .filter(Column("deleted_at") == nil)
                .order(Column("started_at").desc)
                .fetchOne(db)
        }
    }

    /// Calculates total tracked time (in seconds) for an item from completed entries
    public func getTotalTimeForItem(itemId: String) throws -> Int {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        return try dbQueue.read { db in
            let total = try Int.fetchOne(
                db,
                sql: "SELECT COALESCE(SUM(duration), 0) FROM time_entries WHERE item_id = ? AND duration IS NOT NULL AND deleted_at IS NULL",
                arguments: [itemId]
            )
            return total ?? 0
        }
    }

    /// Gets total tracked time for multiple items at once (for efficient batch loading)
    /// Chunks requests to avoid SQLite's 999 variable limit
    public func getTotalTimesForItems(itemIds: [String]) throws -> [String: Int] {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
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
                    WHERE item_id IN (\(placeholders)) AND duration IS NOT NULL AND deleted_at IS NULL
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
    public func stopTimeEntry(id: String, endedAt: Int = Int(Date().timeIntervalSince1970)) throws -> TimeEntry? {
        guard let dbQueue = database.getQueue() else {
            throw RepositoryError.notInitialized
        }

        return try dbQueue.write { db in
            guard var entry = try TimeEntry
                .filter(Column("id") == id)
                .filter(Column("deleted_at") == nil)
                .fetchOne(db) else {
                return nil
            }

            // Only stop if not already stopped
            guard entry.endedAt == nil else {
                return entry
            }

            entry.endedAt = endedAt
            entry.duration = endedAt - entry.startedAt
            entry.modifiedAt = endedAt
            entry.needsPush = 1
            try entry.update(db)
            return entry
        }
    }
}

// MARK: - Repository Error

public enum RepositoryError: Error, LocalizedError {
    case notInitialized
    case itemNotFound
    case invalidQuery(String)

    public var errorDescription: String? {
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

public extension Array {
    /// Splits the array into chunks of the specified size
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// Re-export GRDB types needed by consumers
public typealias DatabaseCancellable = GRDB.AnyDatabaseCancellable
