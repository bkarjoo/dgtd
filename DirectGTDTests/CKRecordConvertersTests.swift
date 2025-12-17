import XCTest
import CloudKit
import DirectGTDCore
@testable import DirectGTD

/// Comprehensive tests for CKRecordConverters - CloudKit sync serialization
/// Tests all model <-> CKRecord conversions for correctness
final class CKRecordConvertersTests: XCTestCase {
    var mockManager: MockCloudKitManager!

    override func setUp() {
        super.setUp()
        mockManager = MockCloudKitManager()
    }

    override func tearDown() {
        mockManager = nil
        super.tearDown()
    }

    // MARK: - System Fields Tests

    func testEncodeSystemFieldsReturnsData() {
        let record = mockManager.newRecord(type: CloudKitRecordType.item, recordName: "test")

        let data = CKRecordConverters.encodeSystemFields(record)

        XCTAssertFalse(data.isEmpty, "Encoded system fields should not be empty")
    }

    func testDecodeSystemFieldsReturnsNilForNilData() {
        let result = CKRecordConverters.decodeSystemFields(nil, manager: mockManager)

        XCTAssertNil(result, "Decoding nil data should return nil")
    }

    func testDecodeSystemFieldsReturnsNilForInvalidData() {
        let invalidData = "not a valid archive".data(using: .utf8)!

        let result = CKRecordConverters.decodeSystemFields(invalidData, manager: mockManager)

        XCTAssertNil(result, "Decoding invalid data should return nil")
    }

    func testSystemFieldsRoundTrip() {
        let originalRecord = mockManager.newRecord(type: CloudKitRecordType.item, recordName: "test_item")
        originalRecord["testField"] = "test value" as CKRecordValue

        // Encode
        let encoded = CKRecordConverters.encodeSystemFields(originalRecord)

        // Decode
        let decoded = CKRecordConverters.decodeSystemFields(encoded, manager: mockManager)

        XCTAssertNotNil(decoded, "Should decode successfully")
        XCTAssertEqual(decoded?.recordID.recordName, originalRecord.recordID.recordName)
    }

    // MARK: - Item Conversion Tests

    func testItemToRecordNewItem() {
        var item = Item(id: "test-id")
        item.title = "Test Item"
        item.itemType = .task
        item.notes = "Test notes"
        item.parentId = "parent-id"
        item.sortOrder = 5
        item.createdAt = 1000
        item.modifiedAt = 2000
        item.completedAt = 3000
        item.dueDate = 4000
        item.earliestStartTime = 5000

        let record = CKRecordConverters.record(from: item, manager: mockManager)

        XCTAssertEqual(record.recordType, CloudKitRecordType.item)
        XCTAssertEqual(record["localId"] as? String, "test-id")
        XCTAssertEqual(record["title"] as? String, "Test Item")
        XCTAssertEqual(record["itemType"] as? String, "Task")
        XCTAssertEqual(record["notes"] as? String, "Test notes")
        XCTAssertEqual(record["parentId"] as? String, "parent-id")
        XCTAssertEqual(record["sortOrder"] as? Int, 5)
        XCTAssertEqual(record["createdAt"] as? Int, 1000)
        XCTAssertEqual(record["modifiedAt"] as? Int, 2000)
        XCTAssertEqual(record["completedAt"] as? Int, 3000)
        XCTAssertEqual(record["dueDate"] as? Int, 4000)
        XCTAssertEqual(record["earliestStartTime"] as? Int, 5000)
    }

    func testItemToRecordWithNilFields() {
        var item = Item(id: "test-id")
        item.title = "Test"
        item.createdAt = 1000
        item.modifiedAt = 1000
        // All optional fields nil

        let record = CKRecordConverters.record(from: item, manager: mockManager)

        XCTAssertNil(record["notes"] as? String)
        XCTAssertNil(record["parentId"] as? String)
        XCTAssertNil(record["completedAt"] as? Int)
        XCTAssertNil(record["dueDate"] as? Int)
        XCTAssertNil(record["earliestStartTime"] as? Int)
        XCTAssertNil(record["deletedAt"] as? Int)
    }

    func testItemToRecordNormalizesEmptyParentId() {
        var item = Item(id: "test-id")
        item.title = "Test"
        item.parentId = "   " // Whitespace only
        item.createdAt = 1000
        item.modifiedAt = 1000

        let record = CKRecordConverters.record(from: item, manager: mockManager)

        XCTAssertNil(record["parentId"] as? String, "Empty/whitespace parentId should be normalized to nil")
    }

    func testItemToRecordWithExistingSystemFields() {
        // Create initial record to get system fields
        var item = Item(id: "test-id")
        item.title = "Original"
        item.ckRecordName = "Item_test-id"
        item.createdAt = 1000
        item.modifiedAt = 1000

        let originalRecord = mockManager.newRecord(type: CloudKitRecordType.item, recordName: "Item_test-id")
        let systemFields = CKRecordConverters.encodeSystemFields(originalRecord)

        // Update item with system fields
        item.ckSystemFields = systemFields
        item.title = "Updated"

        let record = CKRecordConverters.record(from: item, manager: mockManager)

        XCTAssertEqual(record["title"] as? String, "Updated", "Should update title on existing record")
        XCTAssertEqual(record.recordID.recordName, "Item_test-id", "Should preserve record name")
    }

    func testRecordToItem() {
        let record = mockManager.newRecord(type: CloudKitRecordType.item, recordName: "Item_123")
        record["localId"] = "123" as CKRecordValue
        record["title"] = "Test Title" as CKRecordValue
        record["itemType"] = "Task" as CKRecordValue
        record["notes"] = "Notes" as CKRecordValue
        record["parentId"] = "parent-123" as CKRecordValue
        record["sortOrder"] = 10 as CKRecordValue
        record["createdAt"] = 1000 as CKRecordValue
        record["modifiedAt"] = 2000 as CKRecordValue
        record["completedAt"] = 3000 as CKRecordValue
        record["dueDate"] = 4000 as CKRecordValue
        record["earliestStartTime"] = 5000 as CKRecordValue

        let item = CKRecordConverters.item(from: record)

        XCTAssertNotNil(item)
        XCTAssertEqual(item?.id, "123")
        XCTAssertEqual(item?.title, "Test Title")
        XCTAssertEqual(item?.itemType, .task)
        XCTAssertEqual(item?.notes, "Notes")
        XCTAssertEqual(item?.parentId, "parent-123")
        XCTAssertEqual(item?.sortOrder, 10)
        XCTAssertEqual(item?.createdAt, 1000)
        XCTAssertEqual(item?.modifiedAt, 2000)
        XCTAssertEqual(item?.completedAt, 3000)
        XCTAssertEqual(item?.dueDate, 4000)
        XCTAssertEqual(item?.earliestStartTime, 5000)
        XCTAssertEqual(item?.ckRecordName, "Item_123")
        XCTAssertEqual(item?.needsPush, 0, "Should not need push after pulling from server")
    }

    func testRecordToItemWithMissingOptionalFields() {
        let record = mockManager.newRecord(type: CloudKitRecordType.item, recordName: "Item_123")
        record["localId"] = "123" as CKRecordValue
        // Minimal required fields only

        let item = CKRecordConverters.item(from: record)

        XCTAssertNotNil(item)
        XCTAssertNil(item?.title)
        XCTAssertNil(item?.notes)
        XCTAssertNil(item?.parentId)
        XCTAssertNil(item?.completedAt)
        XCTAssertNil(item?.dueDate)
        XCTAssertNil(item?.earliestStartTime)
    }

    func testRecordToItemReturnsNilForInvalidRecordType() {
        let record = mockManager.newRecord(type: CloudKitRecordType.tag, recordName: "Tag_123")
        record["localId"] = "123" as CKRecordValue

        let item = CKRecordConverters.item(from: record)

        XCTAssertNil(item, "Should return nil for wrong record type")
    }

    func testRecordToItemReturnsNilForMissingLocalId() {
        let record = mockManager.newRecord(type: CloudKitRecordType.item, recordName: "Item_123")
        // Missing localId field

        let item = CKRecordConverters.item(from: record)

        XCTAssertNil(item, "Should return nil without localId")
    }

    func testRecordToItemHandlesUnknownItemType() {
        let record = mockManager.newRecord(type: CloudKitRecordType.item, recordName: "Item_123")
        record["localId"] = "123" as CKRecordValue
        record["itemType"] = "InvalidType" as CKRecordValue

        let item = CKRecordConverters.item(from: record)

        XCTAssertNotNil(item)
        XCTAssertEqual(item?.itemType, .unknown, "Should default to unknown for invalid type")
    }

    // MARK: - Tag Conversion Tests

    func testTagToRecord() {
        var tag = Tag(id: "tag-id", name: "Test Tag", createdAt: 1000)
        tag.color = "#FF0000"
        tag.modifiedAt = 2000

        let record = CKRecordConverters.record(from: tag, manager: mockManager)

        XCTAssertEqual(record.recordType, CloudKitRecordType.tag)
        XCTAssertEqual(record["localId"] as? String, "tag-id")
        XCTAssertEqual(record["name"] as? String, "Test Tag")
        XCTAssertEqual(record["color"] as? String, "#FF0000")
        XCTAssertEqual(record["createdAt"] as? Int, 1000)
        XCTAssertEqual(record["modifiedAt"] as? Int, 2000)
    }

    func testRecordToTag() {
        let record = mockManager.newRecord(type: CloudKitRecordType.tag, recordName: "Tag_123")
        record["localId"] = "123" as CKRecordValue
        record["name"] = "Test Tag" as CKRecordValue
        record["color"] = "#00FF00" as CKRecordValue
        record["createdAt"] = 1000 as CKRecordValue
        record["modifiedAt"] = 2000 as CKRecordValue

        let tag = CKRecordConverters.tag(from: record)

        XCTAssertNotNil(tag)
        XCTAssertEqual(tag?.id, "123")
        XCTAssertEqual(tag?.name, "Test Tag")
        XCTAssertEqual(tag?.color, "#00FF00")
        XCTAssertEqual(tag?.createdAt, 1000)
        XCTAssertEqual(tag?.modifiedAt, 2000)
        XCTAssertEqual(tag?.needsPush, 0)
    }

    func testRecordToTagReturnsNilForInvalidType() {
        let record = mockManager.newRecord(type: CloudKitRecordType.item, recordName: "Item_123")
        record["localId"] = "123" as CKRecordValue
        record["name"] = "Test" as CKRecordValue

        let tag = CKRecordConverters.tag(from: record)

        XCTAssertNil(tag, "Should return nil for wrong record type")
    }

    func testRecordToTagReturnsNilForMissingRequiredFields() {
        let record = mockManager.newRecord(type: CloudKitRecordType.tag, recordName: "Tag_123")
        record["localId"] = "123" as CKRecordValue
        // Missing name field

        let tag = CKRecordConverters.tag(from: record)

        XCTAssertNil(tag, "Should return nil without required name field")
    }

    // MARK: - ItemTag Conversion Tests

    func testItemTagToRecord() {
        var itemTag = ItemTag(itemId: "item-123", tagId: "tag-456", createdAt: 1000)
        itemTag.modifiedAt = 2000

        let record = CKRecordConverters.record(from: itemTag, manager: mockManager)

        XCTAssertEqual(record.recordType, CloudKitRecordType.itemTag)
        XCTAssertEqual(record["itemId"] as? String, "item-123")
        XCTAssertEqual(record["tagId"] as? String, "tag-456")
        XCTAssertEqual(record["createdAt"] as? Int, 1000)
        XCTAssertEqual(record["modifiedAt"] as? Int, 2000)
    }

    func testRecordToItemTag() {
        let record = mockManager.newRecord(type: CloudKitRecordType.itemTag, recordName: "ItemTag_123_456")
        record["itemId"] = "item-123" as CKRecordValue
        record["tagId"] = "tag-456" as CKRecordValue
        record["createdAt"] = 1000 as CKRecordValue
        record["modifiedAt"] = 2000 as CKRecordValue

        let itemTag = CKRecordConverters.itemTag(from: record)

        XCTAssertNotNil(itemTag)
        XCTAssertEqual(itemTag?.itemId, "item-123")
        XCTAssertEqual(itemTag?.tagId, "tag-456")
        XCTAssertEqual(itemTag?.createdAt, 1000)
        XCTAssertEqual(itemTag?.modifiedAt, 2000)
        XCTAssertEqual(itemTag?.needsPush, 0)
    }

    func testRecordToItemTagReturnsNilForMissingFields() {
        let record = mockManager.newRecord(type: CloudKitRecordType.itemTag, recordName: "ItemTag_123")
        record["itemId"] = "item-123" as CKRecordValue
        // Missing tagId

        let itemTag = CKRecordConverters.itemTag(from: record)

        XCTAssertNil(itemTag, "Should return nil without required fields")
    }

    // MARK: - TimeEntry Conversion Tests

    func testTimeEntryToRecord() {
        var entry = TimeEntry(id: "entry-id", itemId: "item-id", startedAt: 1000)
        entry.endedAt = 2000
        entry.duration = 1000
        entry.modifiedAt = 2000

        let record = CKRecordConverters.record(from: entry, manager: mockManager)

        XCTAssertEqual(record.recordType, CloudKitRecordType.timeEntry)
        XCTAssertEqual(record["localId"] as? String, "entry-id")
        XCTAssertEqual(record["itemId"] as? String, "item-id")
        XCTAssertEqual(record["startedAt"] as? Int, 1000)
        XCTAssertEqual(record["endedAt"] as? Int, 2000)
        XCTAssertEqual(record["duration"] as? Int, 1000)
        XCTAssertEqual(record["modifiedAt"] as? Int, 2000)
    }

    func testRecordToTimeEntry() {
        let record = mockManager.newRecord(type: CloudKitRecordType.timeEntry, recordName: "TimeEntry_123")
        record["localId"] = "123" as CKRecordValue
        record["itemId"] = "item-456" as CKRecordValue
        record["startedAt"] = 1000 as CKRecordValue
        record["endedAt"] = 2000 as CKRecordValue
        record["duration"] = 1000 as CKRecordValue
        record["modifiedAt"] = 2000 as CKRecordValue

        let entry = CKRecordConverters.timeEntry(from: record)

        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.id, "123")
        XCTAssertEqual(entry?.itemId, "item-456")
        XCTAssertEqual(entry?.startedAt, 1000)
        XCTAssertEqual(entry?.endedAt, 2000)
        XCTAssertEqual(entry?.duration, 1000)
        XCTAssertEqual(entry?.modifiedAt, 2000)
        XCTAssertEqual(entry?.needsPush, 0)
    }

    func testRecordToTimeEntryReturnsNilForMissingRequiredFields() {
        let record = mockManager.newRecord(type: CloudKitRecordType.timeEntry, recordName: "TimeEntry_123")
        record["localId"] = "123" as CKRecordValue
        record["itemId"] = "item-456" as CKRecordValue
        // Missing startedAt

        let entry = CKRecordConverters.timeEntry(from: record)

        XCTAssertNil(entry, "Should return nil without required startedAt field")
    }

    // MARK: - SavedSearch Conversion Tests

    func testSavedSearchToRecord() {
        var search = SavedSearch(
            id: "search-id",
            name: "My Search",
            sql: "SELECT * FROM items"
        )
        search.sortOrder = 5
        search.createdAt = 1000
        search.modifiedAt = 2000

        let record = CKRecordConverters.record(from: search, manager: mockManager)

        XCTAssertEqual(record.recordType, CloudKitRecordType.savedSearch)
        XCTAssertEqual(record["localId"] as? String, "search-id")
        XCTAssertEqual(record["name"] as? String, "My Search")
        XCTAssertEqual(record["sql"] as? String, "SELECT * FROM items")
        XCTAssertEqual(record["sortOrder"] as? Int, 5)
        XCTAssertEqual(record["createdAt"] as? Int, 1000)
        XCTAssertEqual(record["modifiedAt"] as? Int, 2000)
    }

    func testRecordToSavedSearch() {
        let record = mockManager.newRecord(type: CloudKitRecordType.savedSearch, recordName: "SavedSearch_123")
        record["localId"] = "123" as CKRecordValue
        record["name"] = "Test Search" as CKRecordValue
        record["sql"] = "SELECT id FROM items WHERE completed_at IS NOT NULL" as CKRecordValue
        record["sortOrder"] = 3 as CKRecordValue
        record["createdAt"] = 1000 as CKRecordValue
        record["modifiedAt"] = 2000 as CKRecordValue

        let search = CKRecordConverters.savedSearch(from: record)

        XCTAssertNotNil(search)
        XCTAssertEqual(search?.id, "123")
        XCTAssertEqual(search?.name, "Test Search")
        XCTAssertEqual(search?.sql, "SELECT id FROM items WHERE completed_at IS NOT NULL")
        XCTAssertEqual(search?.sortOrder, 3)
        XCTAssertEqual(search?.createdAt, 1000)
        XCTAssertEqual(search?.modifiedAt, 2000)
        XCTAssertEqual(search?.needsPush, 0)
    }

    func testRecordToSavedSearchReturnsNilForMissingFields() {
        let record = mockManager.newRecord(type: CloudKitRecordType.savedSearch, recordName: "SavedSearch_123")
        record["localId"] = "123" as CKRecordValue
        record["name"] = "Test" as CKRecordValue
        // Missing sql field

        let search = CKRecordConverters.savedSearch(from: record)

        XCTAssertNil(search, "Should return nil without required sql field")
    }

    func testRecordToSavedSearchUsesDefaults() {
        let record = mockManager.newRecord(type: CloudKitRecordType.savedSearch, recordName: "SavedSearch_123")
        record["localId"] = "123" as CKRecordValue
        record["name"] = "Test" as CKRecordValue
        record["sql"] = "SELECT *" as CKRecordValue
        // Missing sortOrder, createdAt, modifiedAt

        let search = CKRecordConverters.savedSearch(from: record)

        XCTAssertNotNil(search)
        XCTAssertEqual(search?.sortOrder, 0, "Should default sortOrder to 0")
        XCTAssertNotNil(search?.createdAt, "Should default createdAt to current time")
        XCTAssertNotNil(search?.modifiedAt, "Should default modifiedAt to current time")
    }

    // MARK: - Update Helper Tests

    func testUpdateRecordWithItem() {
        let record = mockManager.newRecord(type: CloudKitRecordType.item, recordName: "Item_123")

        var item = Item(id: "123")
        item.title = "Updated Title"
        item.itemType = .project
        item.notes = "Updated notes"
        item.sortOrder = 99
        item.createdAt = 1000
        item.modifiedAt = 3000

        CKRecordConverters.update(record: record, with: item)

        XCTAssertEqual(record["title"] as? String, "Updated Title")
        XCTAssertEqual(record["itemType"] as? String, "Project")
        XCTAssertEqual(record["notes"] as? String, "Updated notes")
        XCTAssertEqual(record["sortOrder"] as? Int, 99)
        XCTAssertEqual(record["modifiedAt"] as? Int, 3000)
    }

    func testUpdateRecordWithTag() {
        let record = mockManager.newRecord(type: CloudKitRecordType.tag, recordName: "Tag_123")

        var tag = Tag(id: "123", name: "Updated Tag", createdAt: 1000)
        tag.color = "#0000FF"
        tag.modifiedAt = 2000

        CKRecordConverters.update(record: record, with: tag)

        XCTAssertEqual(record["name"] as? String, "Updated Tag")
        XCTAssertEqual(record["color"] as? String, "#0000FF")
        XCTAssertEqual(record["modifiedAt"] as? Int, 2000)
    }

    func testUpdateRecordWithItemTag() {
        let record = mockManager.newRecord(type: CloudKitRecordType.itemTag, recordName: "ItemTag_1_2")

        var itemTag = ItemTag(itemId: "item-1", tagId: "tag-2", createdAt: 1000)
        itemTag.modifiedAt = 2000

        CKRecordConverters.update(record: record, with: itemTag)

        XCTAssertEqual(record["itemId"] as? String, "item-1")
        XCTAssertEqual(record["tagId"] as? String, "tag-2")
        XCTAssertEqual(record["modifiedAt"] as? Int, 2000)
    }

    func testUpdateRecordWithTimeEntry() {
        let record = mockManager.newRecord(type: CloudKitRecordType.timeEntry, recordName: "TimeEntry_123")

        var entry = TimeEntry(id: "123", itemId: "item-456", startedAt: 1000)
        entry.endedAt = 2000
        entry.duration = 1000
        entry.modifiedAt = 2000

        CKRecordConverters.update(record: record, with: entry)

        XCTAssertEqual(record["startedAt"] as? Int, 1000)
        XCTAssertEqual(record["endedAt"] as? Int, 2000)
        XCTAssertEqual(record["duration"] as? Int, 1000)
        XCTAssertEqual(record["modifiedAt"] as? Int, 2000)
    }

    func testUpdateRecordWithSavedSearch() {
        let record = mockManager.newRecord(type: CloudKitRecordType.savedSearch, recordName: "SavedSearch_123")

        var search = SavedSearch(id: "123", name: "Updated", sql: "SELECT * FROM tags")
        search.sortOrder = 10
        search.createdAt = 1000
        search.modifiedAt = 3000

        CKRecordConverters.update(record: record, with: search)

        XCTAssertEqual(record["name"] as? String, "Updated")
        XCTAssertEqual(record["sql"] as? String, "SELECT * FROM tags")
        XCTAssertEqual(record["sortOrder"] as? Int, 10)
        XCTAssertEqual(record["modifiedAt"] as? Int, 3000)
    }

    // MARK: - Deletion Tests

    func testItemWithDeletedAt() {
        var item = Item(id: "test-id")
        item.title = "Deleted Item"
        item.createdAt = 1000
        item.modifiedAt = 2000
        item.deletedAt = 2000

        let record = CKRecordConverters.record(from: item, manager: mockManager)

        XCTAssertEqual(record["deletedAt"] as? Int, 2000, "Should include deletedAt field")
    }

    func testRecordToItemPreservesDeletedAt() {
        let record = mockManager.newRecord(type: CloudKitRecordType.item, recordName: "Item_123")
        record["localId"] = "123" as CKRecordValue
        record["deletedAt"] = 5000 as CKRecordValue

        let item = CKRecordConverters.item(from: record)

        XCTAssertEqual(item?.deletedAt, 5000, "Should preserve deletedAt from record")
    }

    // MARK: - Edge Cases

    func testItemWithEmptyStringParentIdBecomesNil() {
        var item = Item(id: "test-id")
        item.title = "Test"
        item.parentId = ""
        item.createdAt = 1000
        item.modifiedAt = 1000

        let record = CKRecordConverters.record(from: item, manager: mockManager)

        XCTAssertNil(record["parentId"] as? String, "Empty string parentId should become nil")
    }

    func testItemWithWhitespaceOnlyParentIdBecomesNil() {
        var item = Item(id: "test-id")
        item.title = "Test"
        item.parentId = "  \t\n  "
        item.createdAt = 1000
        item.modifiedAt = 1000

        let record = CKRecordConverters.record(from: item, manager: mockManager)

        XCTAssertNil(record["parentId"] as? String, "Whitespace-only parentId should become nil")
    }

    func testRecordWithEmptyParentIdStringNormalizedToNil() {
        let record = mockManager.newRecord(type: CloudKitRecordType.item, recordName: "Item_123")
        record["localId"] = "123" as CKRecordValue
        record["parentId"] = "   " as CKRecordValue

        let item = CKRecordConverters.item(from: record)

        XCTAssertNil(item?.parentId, "Should normalize whitespace parentId to nil")
    }
}
