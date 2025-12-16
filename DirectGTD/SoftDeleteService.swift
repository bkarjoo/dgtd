import DirectGTDCore
import Foundation
import GRDB

/// Service for handling soft-delete cascades and tombstone management.
/// Since CASCADE deletes are removed, this service enforces tombstone cascades in application code.
class SoftDeleteService {
    private let database: DatabaseProvider

    init(database: DatabaseProvider) {
        self.database = database
    }

    private func getQueue() throws -> DatabaseQueue {
        guard let queue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }
        return queue
    }

    // MARK: - Item Soft Delete

    /// Soft-delete an item and all its descendants, plus related item_tags and time_entries.
    /// Sets deleted_at and needs_push=1 on all affected rows.
    func softDeleteItem(id: String) throws {
        let dbQueue = try getQueue()
        try dbQueue.write { db in
            try self.softDeleteItemRecursive(db: db, itemId: id)
        }
    }

    /// Soft-delete multiple items and their descendants.
    func softDeleteItems(ids: [String]) throws {
        let dbQueue = try getQueue()
        try dbQueue.write { db in
            for id in ids {
                try self.softDeleteItemRecursive(db: db, itemId: id)
            }
        }
    }

    /// SQLite has a limit of 999 bound variables, so we chunk large ID lists
    private static let chunkSize = 500

    private func softDeleteItemRecursive(db: GRDB.Database, itemId: String) throws {
        let now = Int(Date().timeIntervalSince1970)

        // 1. Get all descendant item IDs (recursive)
        let descendantIds = try getDescendantIds(db: db, parentId: itemId)
        let allItemIds = [itemId] + descendantIds

        // Process in chunks to avoid SQLite's 999 variable limit
        for chunk in allItemIds.chunked(into: SoftDeleteService.chunkSize) {
            let placeholders = chunk.map { _ in "?" }.joined(separator: ",")

            // 2. Ensure ck_record_name is set for item_tags (required for CloudKit delete)
            try db.execute(
                sql: """
                    UPDATE item_tags
                    SET ck_record_name = 'ItemTag_' || item_id || '_' || tag_id
                    WHERE item_id IN (\(placeholders))
                    AND (ck_record_name IS NULL OR ck_record_name = '')
                """,
                arguments: StatementArguments(chunk)
            )

            // 3. Soft-delete all item_tags for these items
            try db.execute(
                sql: """
                    UPDATE item_tags
                    SET deleted_at = ?, needs_push = 1, modified_at = ?
                    WHERE item_id IN (\(placeholders))
                    AND deleted_at IS NULL
                """,
                arguments: StatementArguments([now, now] + chunk)
            )

            // 4. Ensure ck_record_name is set for time_entries (required for CloudKit delete)
            try db.execute(
                sql: """
                    UPDATE time_entries
                    SET ck_record_name = 'TimeEntry_' || id
                    WHERE item_id IN (\(placeholders))
                    AND (ck_record_name IS NULL OR ck_record_name = '')
                """,
                arguments: StatementArguments(chunk)
            )

            // 5. Soft-delete all time_entries for these items
            try db.execute(
                sql: """
                    UPDATE time_entries
                    SET deleted_at = ?, needs_push = 1, modified_at = ?
                    WHERE item_id IN (\(placeholders))
                    AND deleted_at IS NULL
                """,
                arguments: StatementArguments([now, now] + chunk)
            )

            // 6. Ensure ck_record_name is set for items (required for CloudKit delete)
            try db.execute(
                sql: """
                    UPDATE items
                    SET ck_record_name = 'Item_' || id
                    WHERE id IN (\(placeholders))
                    AND (ck_record_name IS NULL OR ck_record_name = '')
                """,
                arguments: StatementArguments(chunk)
            )

            // 7. Soft-delete all items (parent + descendants)
            try db.execute(
                sql: """
                    UPDATE items
                    SET deleted_at = ?, needs_push = 1, modified_at = ?
                    WHERE id IN (\(placeholders))
                    AND deleted_at IS NULL
                """,
                arguments: StatementArguments([now, now] + chunk)
            )
        }

        NSLog("SoftDeleteService: Soft-deleted item \(itemId) with \(descendantIds.count) descendants")
    }

    private func getDescendantIds(db: GRDB.Database, parentId: String) throws -> [String] {
        var descendants: [String] = []
        var queue = [parentId]

        while !queue.isEmpty {
            let currentId = queue.removeFirst()
            let childIds = try String.fetchAll(db, sql: """
                SELECT id FROM items
                WHERE parent_id = ? AND deleted_at IS NULL
            """, arguments: [currentId])

            descendants.append(contentsOf: childIds)
            queue.append(contentsOf: childIds)
        }

        return descendants
    }

    // MARK: - Tag Soft Delete

    /// Soft-delete a tag and all item_tags referencing it.
    func softDeleteTag(id: String) throws {
        let dbQueue = try getQueue()
        try dbQueue.write { db in
            let now = Int(Date().timeIntervalSince1970)

            // 1. Ensure ck_record_name is set for item_tags (required for CloudKit delete)
            try db.execute(
                sql: """
                    UPDATE item_tags
                    SET ck_record_name = 'ItemTag_' || item_id || '_' || tag_id
                    WHERE tag_id = ?
                    AND (ck_record_name IS NULL OR ck_record_name = '')
                """,
                arguments: [id]
            )

            // 2. Soft-delete all item_tags referencing this tag
            try db.execute(
                sql: """
                    UPDATE item_tags
                    SET deleted_at = ?, needs_push = 1, modified_at = ?
                    WHERE tag_id = ? AND deleted_at IS NULL
                """,
                arguments: [now, now, id]
            )

            // 3. Ensure ck_record_name is set for the tag (required for CloudKit delete)
            try db.execute(
                sql: """
                    UPDATE tags
                    SET ck_record_name = 'Tag_' || id
                    WHERE id = ?
                    AND (ck_record_name IS NULL OR ck_record_name = '')
                """,
                arguments: [id]
            )

            // 4. Soft-delete the tag itself
            try db.execute(
                sql: """
                    UPDATE tags
                    SET deleted_at = ?, needs_push = 1, modified_at = ?
                    WHERE id = ? AND deleted_at IS NULL
                """,
                arguments: [now, now, id]
            )

            NSLog("SoftDeleteService: Soft-deleted tag \(id)")
        }
    }

    // MARK: - ItemTag Soft Delete

    /// Soft-delete a specific item-tag association.
    func softDeleteItemTag(itemId: String, tagId: String) throws {
        let dbQueue = try getQueue()
        try dbQueue.write { db in
            let now = Int(Date().timeIntervalSince1970)

            // Ensure ck_record_name is set (required for CloudKit delete)
            try db.execute(
                sql: """
                    UPDATE item_tags
                    SET ck_record_name = 'ItemTag_' || item_id || '_' || tag_id
                    WHERE item_id = ? AND tag_id = ?
                    AND (ck_record_name IS NULL OR ck_record_name = '')
                """,
                arguments: [itemId, tagId]
            )

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

    // MARK: - Time Entry Soft Delete

    /// Soft-delete a time entry.
    func softDeleteTimeEntry(id: String) throws {
        let dbQueue = try getQueue()
        try dbQueue.write { db in
            let now = Int(Date().timeIntervalSince1970)

            // Ensure ck_record_name is set (required for CloudKit delete)
            try db.execute(
                sql: """
                    UPDATE time_entries
                    SET ck_record_name = 'TimeEntry_' || id
                    WHERE id = ?
                    AND (ck_record_name IS NULL OR ck_record_name = '')
                """,
                arguments: [id]
            )

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

    // MARK: - Saved Search Soft Delete

    /// Soft-delete a saved search.
    func softDeleteSavedSearch(id: String) throws {
        let dbQueue = try getQueue()
        try dbQueue.write { db in
            let now = Int(Date().timeIntervalSince1970)

            // Ensure ck_record_name is set (required for CloudKit delete)
            try db.execute(
                sql: """
                    UPDATE saved_searches
                    SET ck_record_name = 'SavedSearch_' || id
                    WHERE id = ?
                    AND (ck_record_name IS NULL OR ck_record_name = '')
                """,
                arguments: [id]
            )

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

    // MARK: - Tombstone Purge

    /// Purge tombstones older than 30 days that have been synced (needs_push = 0).
    /// Call this periodically to clean up old soft-deleted records.
    func purgeSyncedTombstones() throws {
        let dbQueue = try getQueue()
        try dbQueue.write { db in
            let thirtyDaysAgo = Int(Date().timeIntervalSince1970) - (30 * 24 * 60 * 60)

            // Purge in dependency order: item_tags and time_entries first, then items, then tags

            // 1. Purge item_tags tombstones
            try db.execute(
                sql: """
                    DELETE FROM item_tags
                    WHERE deleted_at IS NOT NULL
                    AND deleted_at < ?
                    AND needs_push = 0
                """,
                arguments: [thirtyDaysAgo]
            )
            let itemTagsDeleted = db.changesCount

            // 2. Purge time_entries tombstones
            try db.execute(
                sql: """
                    DELETE FROM time_entries
                    WHERE deleted_at IS NOT NULL
                    AND deleted_at < ?
                    AND needs_push = 0
                """,
                arguments: [thirtyDaysAgo]
            )
            let timeEntriesDeleted = db.changesCount

            // 3. Purge items tombstones (only if no children still exist)
            // First get candidate item IDs
            let candidateItemIds = try String.fetchAll(db, sql: """
                SELECT id FROM items
                WHERE deleted_at IS NOT NULL
                AND deleted_at < ?
                AND needs_push = 0
            """, arguments: [thirtyDaysAgo])

            var itemsDeleted = 0
            for itemId in candidateItemIds {
                // Check if any children still reference this item
                let hasChildren = try Int.fetchOne(db, sql: """
                    SELECT COUNT(*) FROM items WHERE parent_id = ?
                """, arguments: [itemId]) ?? 0

                if hasChildren == 0 {
                    try db.execute(sql: "DELETE FROM items WHERE id = ?", arguments: [itemId])
                    itemsDeleted += 1
                }
            }

            // 4. Purge tags tombstones (only if no item_tags still reference)
            let candidateTagIds = try String.fetchAll(db, sql: """
                SELECT id FROM tags
                WHERE deleted_at IS NOT NULL
                AND deleted_at < ?
                AND needs_push = 0
            """, arguments: [thirtyDaysAgo])

            var tagsDeleted = 0
            for tagId in candidateTagIds {
                let hasItemTags = try Int.fetchOne(db, sql: """
                    SELECT COUNT(*) FROM item_tags WHERE tag_id = ?
                """, arguments: [tagId]) ?? 0

                if hasItemTags == 0 {
                    try db.execute(sql: "DELETE FROM tags WHERE id = ?", arguments: [tagId])
                    tagsDeleted += 1
                }
            }

            // 5. Purge saved_searches tombstones
            try db.execute(
                sql: """
                    DELETE FROM saved_searches
                    WHERE deleted_at IS NOT NULL
                    AND deleted_at < ?
                    AND needs_push = 0
                """,
                arguments: [thirtyDaysAgo]
            )
            let savedSearchesDeleted = db.changesCount

            NSLog("SoftDeleteService: Purged tombstones - items: \(itemsDeleted), tags: \(tagsDeleted), item_tags: \(itemTagsDeleted), time_entries: \(timeEntriesDeleted), saved_searches: \(savedSearchesDeleted)")
        }
    }

    /// Permanently delete soft-deleted items older than the specified timestamp.
    /// - Parameter olderThan: Delete items with deleted_at before this timestamp
    /// - Returns: Number of items permanently deleted
    func permanentlyDeleteItemsOlderThan(_ olderThan: Int) throws -> Int {
        let dbQueue = try getQueue()
        var totalDeleted = 0

        try dbQueue.write { db in
            // 1. Delete item_tags for deleted items older than cutoff
            try db.execute(
                sql: """
                    DELETE FROM item_tags
                    WHERE item_id IN (
                        SELECT id FROM items
                        WHERE deleted_at IS NOT NULL AND deleted_at < ?
                    )
                """,
                arguments: [olderThan]
            )

            // 2. Delete time_entries for deleted items older than cutoff
            try db.execute(
                sql: """
                    DELETE FROM time_entries
                    WHERE item_id IN (
                        SELECT id FROM items
                        WHERE deleted_at IS NOT NULL AND deleted_at < ?
                    )
                """,
                arguments: [olderThan]
            )

            // 3. Delete the items themselves (only leaf nodes first to handle hierarchy)
            // This may need multiple passes for deeply nested structures
            var deletedInPass = 1
            while deletedInPass > 0 {
                try db.execute(
                    sql: """
                        DELETE FROM items
                        WHERE deleted_at IS NOT NULL
                        AND deleted_at < ?
                        AND id NOT IN (SELECT parent_id FROM items WHERE parent_id IS NOT NULL)
                    """,
                    arguments: [olderThan]
                )
                deletedInPass = db.changesCount
                totalDeleted += deletedInPass
            }

            NSLog("SoftDeleteService: Permanently deleted \(totalDeleted) items older than \(olderThan)")
        }

        return totalDeleted
    }
}
