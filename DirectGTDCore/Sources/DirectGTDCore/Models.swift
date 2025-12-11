import Foundation
import GRDB

// MARK: - ItemType Enum
public enum ItemType: String, Codable, CaseIterable, Sendable {
    case unknown = "Unknown"
    case task = "Task"
    case project = "Project"
    case note = "Note"
    case folder = "Folder"
    case template = "Template"
    case smartFolder = "SmartFolder"
    case alias = "Alias"
    case heading = "Heading"
    case link = "Link"
    case attachment = "Attachment"
    case event = "Event"

    public var defaultIcon: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .task: return "checkmark.circle"
        case .project: return "folder"
        case .note: return "doc.text"
        case .folder: return "folder.fill"
        case .template: return "doc.on.doc"
        case .smartFolder: return "folder.badge.gearshape"
        case .alias: return "link.circle"
        case .heading: return "textformat.size"
        case .link: return "link"
        case .attachment: return "paperclip"
        case .event: return "calendar"
        }
    }
}

// MARK: - Item Model
public struct Item: Codable, FetchableRecord, PersistableRecord, Sendable {
    public var id: String
    public var title: String?
    public var itemType: ItemType
    public var notes: String?

    // Hierarchy
    public var parentId: String?
    public var sortOrder: Int

    // Temporal
    public var createdAt: Int
    public var modifiedAt: Int
    public var completedAt: Int?
    public var dueDate: Int?
    public var earliestStartTime: Int?

    // CloudKit sync fields
    public var ckRecordName: String?
    public var ckChangeTag: String?
    public var ckSystemFields: Data?
    public var needsPush: Int?
    public var deletedAt: Int?

    // Database table name
    public static let databaseTableName = "items"

    // Column names mapping
    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let title = Column(CodingKeys.title)
        public static let itemType = Column(CodingKeys.itemType)
        public static let notes = Column(CodingKeys.notes)
        public static let parentId = Column(CodingKeys.parentId)
        public static let sortOrder = Column(CodingKeys.sortOrder)
        public static let createdAt = Column(CodingKeys.createdAt)
        public static let modifiedAt = Column(CodingKeys.modifiedAt)
        public static let completedAt = Column(CodingKeys.completedAt)
        public static let dueDate = Column(CodingKeys.dueDate)
        public static let earliestStartTime = Column(CodingKeys.earliestStartTime)
        public static let ckRecordName = Column(CodingKeys.ckRecordName)
        public static let ckChangeTag = Column(CodingKeys.ckChangeTag)
        public static let ckSystemFields = Column(CodingKeys.ckSystemFields)
        public static let needsPush = Column(CodingKeys.needsPush)
        public static let deletedAt = Column(CodingKeys.deletedAt)
    }

    // Custom coding keys to match snake_case database columns
    public enum CodingKeys: String, CodingKey {
        case id
        case title
        case itemType = "item_type"
        case notes
        case parentId = "parent_id"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
        case completedAt = "completed_at"
        case dueDate = "due_date"
        case earliestStartTime = "earliest_start_time"
        case ckRecordName = "ck_record_name"
        case ckChangeTag = "ck_change_tag"
        case ckSystemFields = "ck_system_fields"
        case needsPush = "needs_push"
        case deletedAt = "deleted_at"
    }

    // Initialize with defaults
    public init(
        id: String = UUID().uuidString,
        title: String? = nil,
        itemType: ItemType = .unknown,
        notes: String? = nil,
        parentId: String? = nil,
        sortOrder: Int = 0,
        createdAt: Int = Int(Date().timeIntervalSince1970),
        modifiedAt: Int = Int(Date().timeIntervalSince1970),
        completedAt: Int? = nil,
        dueDate: Int? = nil,
        earliestStartTime: Int? = nil,
        ckRecordName: String? = nil,
        ckChangeTag: String? = nil,
        ckSystemFields: Data? = nil,
        needsPush: Int? = 1,
        deletedAt: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.itemType = itemType
        self.notes = notes
        self.parentId = parentId
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.completedAt = completedAt
        self.dueDate = dueDate
        self.earliestStartTime = earliestStartTime
        self.ckRecordName = ckRecordName ?? "Item_\(id)"
        self.ckChangeTag = ckChangeTag
        self.ckSystemFields = ckSystemFields
        self.needsPush = needsPush
        self.deletedAt = deletedAt
    }

    /// Whether this item is soft-deleted
    public var isDeleted: Bool {
        deletedAt != nil
    }
}

// MARK: - Time Entry Model
public struct TimeEntry: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    public var id: String
    public var itemId: String
    public var startedAt: Int
    public var endedAt: Int?
    public var duration: Int?
    public var modifiedAt: Int?

    // CloudKit sync fields
    public var ckRecordName: String?
    public var ckChangeTag: String?
    public var ckSystemFields: Data?
    public var needsPush: Int?
    public var deletedAt: Int?

    public static let databaseTableName = "time_entries"

    public enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case duration
        case modifiedAt = "modified_at"
        case ckRecordName = "ck_record_name"
        case ckChangeTag = "ck_change_tag"
        case ckSystemFields = "ck_system_fields"
        case needsPush = "needs_push"
        case deletedAt = "deleted_at"
    }

    public init(
        id: String = UUID().uuidString,
        itemId: String,
        startedAt: Int = Int(Date().timeIntervalSince1970),
        endedAt: Int? = nil,
        duration: Int? = nil,
        modifiedAt: Int? = nil,
        ckRecordName: String? = nil,
        ckChangeTag: String? = nil,
        ckSystemFields: Data? = nil,
        needsPush: Int? = 1,
        deletedAt: Int? = nil
    ) {
        self.id = id
        self.itemId = itemId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.duration = duration
        self.modifiedAt = modifiedAt ?? startedAt
        self.ckRecordName = ckRecordName ?? "TimeEntry_\(id)"
        self.ckChangeTag = ckChangeTag
        self.ckSystemFields = ckSystemFields
        self.needsPush = needsPush
        self.deletedAt = deletedAt
    }

    /// Returns true if this entry is still running (no end time)
    public var isRunning: Bool {
        endedAt == nil
    }

    /// Calculates elapsed seconds from startedAt to now (for running entries) or returns stored duration
    public func elapsedSeconds(now: Int = Int(Date().timeIntervalSince1970)) -> Int {
        if let duration = duration {
            return duration
        }
        return now - startedAt
    }

    /// Whether this entry is soft-deleted
    public var isDeleted: Bool {
        deletedAt != nil
    }
}

// MARK: - Tag Model
public struct Tag: Codable, FetchableRecord, PersistableRecord, Sendable {
    public var id: String
    public var name: String
    public var color: String?
    public var createdAt: Int?
    public var modifiedAt: Int?

    // CloudKit sync fields
    public var ckRecordName: String?
    public var ckChangeTag: String?
    public var ckSystemFields: Data?
    public var needsPush: Int?
    public var deletedAt: Int?

    public static let databaseTableName = "tags"

    public enum CodingKeys: String, CodingKey {
        case id
        case name
        case color
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
        case ckRecordName = "ck_record_name"
        case ckChangeTag = "ck_change_tag"
        case ckSystemFields = "ck_system_fields"
        case needsPush = "needs_push"
        case deletedAt = "deleted_at"
    }

    public init(
        id: String = UUID().uuidString,
        name: String,
        color: String? = nil,
        createdAt: Int? = nil,
        modifiedAt: Int? = nil,
        ckRecordName: String? = nil,
        ckChangeTag: String? = nil,
        ckSystemFields: Data? = nil,
        needsPush: Int? = 1,
        deletedAt: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.color = color
        let now = Int(Date().timeIntervalSince1970)
        self.createdAt = createdAt ?? now
        self.modifiedAt = modifiedAt ?? now
        self.ckRecordName = ckRecordName ?? "Tag_\(id)"
        self.ckChangeTag = ckChangeTag
        self.ckSystemFields = ckSystemFields
        self.needsPush = needsPush
        self.deletedAt = deletedAt
    }

    /// Whether this tag is soft-deleted
    public var isDeleted: Bool {
        deletedAt != nil
    }
}

// MARK: - Tag Identifiable & Equatable Conformance
extension Tag: Identifiable, Equatable {
    // Tag already has 'id' property, just need to declare conformance
    // Equatable conformance is synthesized automatically since all properties are Equatable
}

// MARK: - ItemTag Model (junction table)
public struct ItemTag: Codable, FetchableRecord, PersistableRecord, Sendable {
    public var itemId: String
    public var tagId: String
    public var createdAt: Int?
    public var modifiedAt: Int?

    // CloudKit sync fields
    public var ckRecordName: String?
    public var ckChangeTag: String?
    public var ckSystemFields: Data?
    public var needsPush: Int?
    public var deletedAt: Int?

    public static let databaseTableName = "item_tags"

    public enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case tagId = "tag_id"
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
        case ckRecordName = "ck_record_name"
        case ckChangeTag = "ck_change_tag"
        case ckSystemFields = "ck_system_fields"
        case needsPush = "needs_push"
        case deletedAt = "deleted_at"
    }

    public init(
        itemId: String,
        tagId: String,
        createdAt: Int? = nil,
        modifiedAt: Int? = nil,
        ckRecordName: String? = nil,
        ckChangeTag: String? = nil,
        ckSystemFields: Data? = nil,
        needsPush: Int? = 1,
        deletedAt: Int? = nil
    ) {
        self.itemId = itemId
        self.tagId = tagId
        let now = Int(Date().timeIntervalSince1970)
        self.createdAt = createdAt ?? now
        self.modifiedAt = modifiedAt ?? now
        self.ckRecordName = ckRecordName ?? "ItemTag_\(itemId)_\(tagId)"
        self.ckChangeTag = ckChangeTag
        self.ckSystemFields = ckSystemFields
        self.needsPush = needsPush
        self.deletedAt = deletedAt
    }

    /// Whether this item-tag association is soft-deleted
    public var isDeleted: Bool {
        deletedAt != nil
    }
}

// MARK: - SavedSearch Model
public struct SavedSearch: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var sql: String
    public var sortOrder: Int
    public var createdAt: Int
    public var modifiedAt: Int

    // CloudKit sync fields
    public var ckRecordName: String?
    public var ckChangeTag: String?
    public var ckSystemFields: Data?
    public var needsPush: Int?
    public var deletedAt: Int?

    public static let databaseTableName = "saved_searches"

    public enum CodingKeys: String, CodingKey {
        case id
        case name
        case sql
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
        case ckRecordName = "ck_record_name"
        case ckChangeTag = "ck_change_tag"
        case ckSystemFields = "ck_system_fields"
        case needsPush = "needs_push"
        case deletedAt = "deleted_at"
    }

    public init(
        id: String = UUID().uuidString,
        name: String,
        sql: String,
        sortOrder: Int = 0,
        createdAt: Int = Int(Date().timeIntervalSince1970),
        modifiedAt: Int = Int(Date().timeIntervalSince1970),
        ckRecordName: String? = nil,
        ckChangeTag: String? = nil,
        ckSystemFields: Data? = nil,
        needsPush: Int? = 1,
        deletedAt: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.sql = sql
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.ckRecordName = ckRecordName ?? "SavedSearch_\(id)"
        self.ckChangeTag = ckChangeTag
        self.ckSystemFields = ckSystemFields
        self.needsPush = needsPush
        self.deletedAt = deletedAt
    }

    /// Whether this saved search is soft-deleted
    public var isDeleted: Bool {
        deletedAt != nil
    }
}

// MARK: - SyncMetadata Model
public struct SyncMetadata: Codable, FetchableRecord, PersistableRecord, Sendable {
    public var key: String
    public var value: Data?

    public static let databaseTableName = "sync_metadata"

    public enum CodingKeys: String, CodingKey {
        case key
        case value
    }

    public init(key: String, value: Data? = nil) {
        self.key = key
        self.value = value
    }
}
