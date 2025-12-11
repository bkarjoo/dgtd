import DirectGTDCore
import XCTest
@testable import DirectGTD

final class ItemTests: XCTestCase {

    // MARK: - Initialization Tests

    func testItemInitializationWithDefaults() {
        // Given/When
        let item = Item()

        // Then
        XCTAssertFalse(item.id.isEmpty, "Item should have a non-empty ID")
        XCTAssertNil(item.title, "Title should be nil by default")
        XCTAssertEqual(item.itemType, .unknown, "Item type should be .unknown by default")
        XCTAssertNil(item.parentId, "Parent ID should be nil by default")
        XCTAssertEqual(item.sortOrder, 0, "Sort order should be 0 by default")
        XCTAssertNil(item.completedAt, "Completed at should be nil by default")
        XCTAssertNil(item.dueDate, "Due date should be nil by default")
        XCTAssertNil(item.earliestStartTime, "Earliest start time should be nil by default")
    }

    func testItemInitializationWithCustomValues() {
        // Given
        let customId = "test-id-123"
        let customTitle = "Test Item"
        let customItemType = ItemType.task
        let customParentId = "parent-123"
        let customSortOrder = 5
        let customCreatedAt = 1234567890
        let customModifiedAt = 1234567900
        let customCompletedAt = 1234567910
        let customDueDate = 1234567920
        let customEarliestStartTime = 1234567930

        // When
        let item = Item(
            id: customId,
            title: customTitle,
            itemType: customItemType,
            parentId: customParentId,
            sortOrder: customSortOrder,
            createdAt: customCreatedAt,
            modifiedAt: customModifiedAt,
            completedAt: customCompletedAt,
            dueDate: customDueDate,
            earliestStartTime: customEarliestStartTime
        )

        // Then
        XCTAssertEqual(item.id, customId)
        XCTAssertEqual(item.title, customTitle)
        XCTAssertEqual(item.itemType, customItemType)
        XCTAssertEqual(item.parentId, customParentId)
        XCTAssertEqual(item.sortOrder, customSortOrder)
        XCTAssertEqual(item.createdAt, customCreatedAt)
        XCTAssertEqual(item.modifiedAt, customModifiedAt)
        XCTAssertEqual(item.completedAt, customCompletedAt)
        XCTAssertEqual(item.dueDate, customDueDate)
        XCTAssertEqual(item.earliestStartTime, customEarliestStartTime)
    }

    // MARK: - Codable Tests

    func testItemEncodingWithSnakeCaseKeys() throws {
        // Given
        let item = Item(
            id: "test-id",
            title: "Test",
            itemType: .task,
            parentId: "parent-id",
            sortOrder: 1,
            createdAt: 1000,
            modifiedAt: 2000
        )

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(item)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["item_type"] as? String, "Task", "itemType should encode as item_type")
        XCTAssertEqual(json?["parent_id"] as? String, "parent-id", "parentId should encode as parent_id")
        XCTAssertEqual(json?["sort_order"] as? Int, 1, "sortOrder should encode as sort_order")
        XCTAssertEqual(json?["created_at"] as? Int, 1000, "createdAt should encode as created_at")
        XCTAssertEqual(json?["modified_at"] as? Int, 2000, "modifiedAt should encode as modified_at")
    }

    func testItemDecodingWithSnakeCaseKeys() throws {
        // Given
        let jsonString = """
        {
            "id": "test-id",
            "title": "Test Item",
            "item_type": "Project",
            "parent_id": "parent-123",
            "sort_order": 3,
            "created_at": 1500,
            "modified_at": 1600,
            "completed_at": 1700,
            "due_date": 1800,
            "earliest_start_time": 1900
        }
        """
        let data = jsonString.data(using: .utf8)!

        // When
        let decoder = JSONDecoder()
        let item = try decoder.decode(Item.self, from: data)

        // Then
        XCTAssertEqual(item.id, "test-id")
        XCTAssertEqual(item.title, "Test Item")
        XCTAssertEqual(item.itemType, .project)
        XCTAssertEqual(item.parentId, "parent-123")
        XCTAssertEqual(item.sortOrder, 3)
        XCTAssertEqual(item.createdAt, 1500)
        XCTAssertEqual(item.modifiedAt, 1600)
        XCTAssertEqual(item.completedAt, 1700)
        XCTAssertEqual(item.dueDate, 1800)
        XCTAssertEqual(item.earliestStartTime, 1900)
    }

    func testItemDecodingWithMissingOptionalFields() throws {
        // Given - JSON with only required fields
        let jsonString = """
        {
            "id": "test-id",
            "item_type": "Unknown",
            "sort_order": 0,
            "created_at": 1000,
            "modified_at": 1000
        }
        """
        let data = jsonString.data(using: .utf8)!

        // When
        let decoder = JSONDecoder()
        let item = try decoder.decode(Item.self, from: data)

        // Then
        XCTAssertEqual(item.id, "test-id")
        XCTAssertEqual(item.itemType, .unknown)
        XCTAssertNil(item.title)
        XCTAssertNil(item.parentId)
        XCTAssertNil(item.completedAt)
        XCTAssertNil(item.dueDate)
        XCTAssertNil(item.earliestStartTime)
    }
}
