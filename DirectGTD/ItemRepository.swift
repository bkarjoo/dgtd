import Foundation
import GRDB

class ItemRepository {
    private let database: Database

    init(database: Database = .shared) {
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
}

// MARK: - Error Handling

enum DatabaseError: Error, LocalizedError {
    case notInitialized
    case itemNotFound

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Database is not initialized"
        case .itemNotFound:
            return "Item not found"
        }
    }
}
