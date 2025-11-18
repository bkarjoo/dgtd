import Foundation
import GRDB

// MARK: - Item Model
struct Item: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var title: String?

    // Hierarchy
    var parentId: String?
    var sortOrder: Int

    // Temporal
    var createdAt: Int
    var modifiedAt: Int
    var completedAt: Int?
    var dueDate: Int?
    var earliestStartTime: Int?

    // Database table name
    static let databaseTableName = "items"

    // Column names mapping
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let title = Column(CodingKeys.title)
        static let parentId = Column(CodingKeys.parentId)
        static let sortOrder = Column(CodingKeys.sortOrder)
        static let createdAt = Column(CodingKeys.createdAt)
        static let modifiedAt = Column(CodingKeys.modifiedAt)
        static let completedAt = Column(CodingKeys.completedAt)
        static let dueDate = Column(CodingKeys.dueDate)
        static let earliestStartTime = Column(CodingKeys.earliestStartTime)
    }

    // Custom coding keys to match snake_case database columns
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case parentId = "parent_id"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
        case completedAt = "completed_at"
        case dueDate = "due_date"
        case earliestStartTime = "earliest_start_time"
    }

    // Initialize with defaults
    init(
        id: String = UUID().uuidString,
        title: String? = nil,
        parentId: String? = nil,
        sortOrder: Int = 0,
        createdAt: Int = Int(Date().timeIntervalSince1970),
        modifiedAt: Int = Int(Date().timeIntervalSince1970),
        completedAt: Int? = nil,
        dueDate: Int? = nil,
        earliestStartTime: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.parentId = parentId
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.completedAt = completedAt
        self.dueDate = dueDate
        self.earliestStartTime = earliestStartTime
    }
}

// MARK: - Tag Model
struct Tag: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var name: String
    var color: String?

    static let databaseTableName = "tags"

    init(
        id: String = UUID().uuidString,
        name: String,
        color: String? = nil
    ) {
        self.id = id
        self.name = name
        self.color = color
    }
}

// MARK: - ItemTag Model (junction table)
struct ItemTag: Codable, FetchableRecord, PersistableRecord {
    var itemId: String
    var tagId: String

    static let databaseTableName = "item_tags"

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case tagId = "tag_id"
    }

    init(itemId: String, tagId: String) {
        self.itemId = itemId
        self.tagId = tagId
    }
}
