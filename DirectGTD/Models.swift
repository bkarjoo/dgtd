import Foundation
import GRDB

// MARK: - Folder Model
struct Folder: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var name: String
    var parentId: String?
    var icon: String?
    var color: String?
    var sortOrder: Int
    var isSystem: Bool
    var createdAt: Int
    var modifiedAt: Int

    static let databaseTableName = "folders"

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case parentId = "parent_id"
        case icon
        case color
        case sortOrder = "sort_order"
        case isSystem = "is_system"
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        parentId: String? = nil,
        icon: String? = nil,
        color: String? = nil,
        sortOrder: Int = 0,
        isSystem: Bool = false,
        createdAt: Int = Int(Date().timeIntervalSince1970),
        modifiedAt: Int = Int(Date().timeIntervalSince1970)
    ) {
        self.id = id
        self.name = name
        self.parentId = parentId
        self.icon = icon
        self.color = color
        self.sortOrder = sortOrder
        self.isSystem = isSystem
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

// MARK: - Item Model
struct Item: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var title: String
    var description: String?

    // Hierarchy
    var parentId: String?
    var sortOrder: Int

    // GTD workflow
    var status: String // next_action, waiting, someday, completed
    var folderId: String?
    var context: String?

    // Temporal
    var createdAt: Int
    var modifiedAt: Int
    var completedAt: Int?
    var dueDate: Int?
    var earliestStartTime: Int?

    // Metadata
    var isProject: Bool
    var energyLevel: String?
    var timeEstimate: Int?

    // Database table name
    static let databaseTableName = "items"

    // Column names mapping
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let title = Column(CodingKeys.title)
        static let description = Column(CodingKeys.description)
        static let parentId = Column(CodingKeys.parentId)
        static let sortOrder = Column(CodingKeys.sortOrder)
        static let status = Column(CodingKeys.status)
        static let folderId = Column(CodingKeys.folderId)
        static let context = Column(CodingKeys.context)
        static let createdAt = Column(CodingKeys.createdAt)
        static let modifiedAt = Column(CodingKeys.modifiedAt)
        static let completedAt = Column(CodingKeys.completedAt)
        static let dueDate = Column(CodingKeys.dueDate)
        static let earliestStartTime = Column(CodingKeys.earliestStartTime)
        static let isProject = Column(CodingKeys.isProject)
        static let energyLevel = Column(CodingKeys.energyLevel)
        static let timeEstimate = Column(CodingKeys.timeEstimate)
    }

    // Custom coding keys to match snake_case database columns
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case parentId = "parent_id"
        case sortOrder = "sort_order"
        case status
        case folderId = "folder_id"
        case context
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
        case completedAt = "completed_at"
        case dueDate = "due_date"
        case earliestStartTime = "earliest_start_time"
        case isProject = "is_project"
        case energyLevel = "energy_level"
        case timeEstimate = "time_estimate"
    }

    // Initialize with defaults
    init(
        id: String = UUID().uuidString,
        title: String,
        description: String? = nil,
        parentId: String? = nil,
        sortOrder: Int = 0,
        status: String = "next_action",
        folderId: String? = nil,
        context: String? = nil,
        createdAt: Int = Int(Date().timeIntervalSince1970),
        modifiedAt: Int = Int(Date().timeIntervalSince1970),
        completedAt: Int? = nil,
        dueDate: Int? = nil,
        earliestStartTime: Int? = nil,
        isProject: Bool = false,
        energyLevel: String? = nil,
        timeEstimate: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.parentId = parentId
        self.sortOrder = sortOrder
        self.status = status
        self.folderId = folderId
        self.context = context
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.completedAt = completedAt
        self.dueDate = dueDate
        self.earliestStartTime = earliestStartTime
        self.isProject = isProject
        self.energyLevel = energyLevel
        self.timeEstimate = timeEstimate
    }
}

// MARK: - Note Model
struct Note: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var itemId: String
    var content: String
    var createdAt: Int
    var modifiedAt: Int

    static let databaseTableName = "notes"

    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case content
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
    }

    init(
        id: String = UUID().uuidString,
        itemId: String,
        content: String,
        createdAt: Int = Int(Date().timeIntervalSince1970),
        modifiedAt: Int = Int(Date().timeIntervalSince1970)
    ) {
        self.id = id
        self.itemId = itemId
        self.content = content
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
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
