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

        try dbQueue.write { db in
            try item.insert(db)
        }
    }

    func createNote(_ note: Note) throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        try dbQueue.write { db in
            try note.insert(db)
        }
    }

    func createTag(_ tag: Tag) throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        try dbQueue.write { db in
            try tag.insert(db)
        }
    }

    func createFolder(_ folder: Folder) throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        try dbQueue.write { db in
            try folder.insert(db)
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
            try Item.fetchAll(db)
        }
    }

    func getItemsByFolder(_ folderId: String) throws -> [Item] {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        return try dbQueue.read { db in
            try Item
                .filter(Column("folder_id") == folderId)
                .order(Column("sort_order"))
                .fetchAll(db)
        }
    }

    func getItemsByStatus(_ status: String) throws -> [Item] {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        return try dbQueue.read { db in
            try Item
                .filter(Column("status") == status)
                .order(Column("sort_order"))
                .fetchAll(db)
        }
    }

    func getItemsByContext(_ context: String) throws -> [Item] {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        return try dbQueue.read { db in
            try Item
                .filter(Column("context") == context)
                .order(Column("sort_order"))
                .fetchAll(db)
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

    func getNotesForItem(itemId: String) throws -> [Note] {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        return try dbQueue.read { db in
            try Note
                .filter(Column("item_id") == itemId)
                .order(Column("created_at").desc)
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

    func getAllFolders() throws -> [Folder] {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        return try dbQueue.read { db in
            try Folder.order(Column("sort_order")).fetchAll(db)
        }
    }

    func getFolder(id: String) throws -> Folder? {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        return try dbQueue.read { db in
            try Folder.fetchOne(db, key: id)
        }
    }

    func getFolderByName(_ name: String) throws -> Folder? {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        return try dbQueue.read { db in
            try Folder.filter(Column("name") == name).fetchOne(db)
        }
    }

    func getChildFolders(parentId: String) throws -> [Folder] {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        return try dbQueue.read { db in
            try Folder
                .filter(Column("parent_id") == parentId)
                .order(Column("sort_order"))
                .fetchAll(db)
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

    func updateNote(_ note: Note) throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        var updatedNote = note
        updatedNote.modifiedAt = Int(Date().timeIntervalSince1970)

        try dbQueue.write { db in
            try updatedNote.update(db)
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

    func updateFolder(_ folder: Folder) throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        var updatedFolder = folder
        updatedFolder.modifiedAt = Int(Date().timeIntervalSince1970)

        try dbQueue.write { db in
            try updatedFolder.update(db)
        }
    }

    func toggleFolderExpansion(folderId: String) throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        guard var folder = try getFolder(id: folderId) else {
            throw DatabaseError.folderNotFound
        }

        folder.isExpanded.toggle()
        folder.modifiedAt = Int(Date().timeIntervalSince1970)

        try dbQueue.write { db in
            try folder.update(db)
        }
    }

    // MARK: - Delete

    func delete(itemId: String) throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        try dbQueue.write { db in
            try Item.deleteOne(db, key: itemId)
        }
    }

    func deleteNote(noteId: String) throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        try dbQueue.write { db in
            try Note.deleteOne(db, key: noteId)
        }
    }

    func deleteTag(tagId: String) throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        try dbQueue.write { db in
            try Tag.deleteOne(db, key: tagId)
        }
    }

    func deleteFolder(folderId: String) throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        try dbQueue.write { db in
            try Folder.deleteOne(db, key: folderId)
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

    // MARK: - GTD-specific operations

    func addToInbox(title: String, description: String? = nil) throws -> Item {
        guard let inboxFolder = try getFolderByName("Inbox") else {
            throw DatabaseError.folderNotFound
        }

        let item = Item(
            title: title,
            description: description,
            status: "next_action",
            folderId: inboxFolder.id
        )
        try create(item)
        return item
    }

    func getInboxItems() throws -> [Item] {
        guard let inboxFolder = try getFolderByName("Inbox") else {
            throw DatabaseError.folderNotFound
        }
        return try getItemsByFolder(inboxFolder.id)
    }

    func getNextActions() throws -> [Item] {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        guard let trashFolder = try getFolderByName("Trash") else {
            throw DatabaseError.folderNotFound
        }

        return try dbQueue.read { db in
            try Item
                .filter(Column("status") == "next_action")
                .filter(Column("folder_id") != trashFolder.id)
                .filter(Column("parent_id") == nil || Column("parent_id") == "")
                .order(Column("sort_order"))
                .fetchAll(db)
        }
    }

    func getProjects() throws -> [Item] {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        guard let trashFolder = try getFolderByName("Trash") else {
            throw DatabaseError.folderNotFound
        }

        return try dbQueue.read { db in
            try Item
                .filter(Column("is_project") == true)
                .filter(Column("folder_id") != trashFolder.id)
                .order(Column("sort_order"))
                .fetchAll(db)
        }
    }

    func getWaitingItems() throws -> [Item] {
        return try getItemsByStatus("waiting")
    }

    func getSomedayItems() throws -> [Item] {
        return try getItemsByStatus("someday")
    }

    func completeItem(itemId: String) throws {
        guard var item = try getItem(id: itemId) else {
            throw DatabaseError.itemNotFound
        }

        item.status = "completed"
        item.completedAt = Int(Date().timeIntervalSince1970)
        try update(item)
    }

    func moveToTrash(itemId: String) throws {
        guard var item = try getItem(id: itemId) else {
            throw DatabaseError.itemNotFound
        }

        guard let trashFolder = try getFolderByName("Trash") else {
            throw DatabaseError.folderNotFound
        }

        item.folderId = trashFolder.id
        try update(item)
    }

    func moveToFolder(itemId: String, folderId: String) throws {
        guard var item = try getItem(id: itemId) else {
            throw DatabaseError.itemNotFound
        }

        item.folderId = folderId
        try update(item)
    }

    func setItemStatus(itemId: String, status: String) throws {
        guard var item = try getItem(id: itemId) else {
            throw DatabaseError.itemNotFound
        }

        item.status = status
        try update(item)
    }

    func convertToProject(itemId: String) throws {
        guard var item = try getItem(id: itemId) else {
            throw DatabaseError.itemNotFound
        }

        item.isProject = true
        try update(item)
    }

    func addSubItem(parentId: String, title: String, description: String? = nil) throws -> Item {
        guard let projectsFolder = try getFolderByName("Projects") else {
            throw DatabaseError.folderNotFound
        }

        let item = Item(
            title: title,
            description: description,
            parentId: parentId,
            folderId: projectsFolder.id
        )
        try create(item)
        return item
    }
}

// MARK: - Error Handling

enum DatabaseError: Error, LocalizedError {
    case notInitialized
    case itemNotFound
    case folderNotFound

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Database is not initialized"
        case .itemNotFound:
            return "Item not found"
        case .folderNotFound:
            return "Folder not found"
        }
    }
}
