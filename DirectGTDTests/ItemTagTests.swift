import DirectGTDCore
import XCTest
@testable import DirectGTD

final class ItemTagTests: XCTestCase {

    // MARK: - Initialization Tests

    func testItemTagInitialization() {
        // Given
        let itemId = "item-123"
        let tagId = "tag-456"

        // When
        let itemTag = ItemTag(itemId: itemId, tagId: tagId)

        // Then
        XCTAssertEqual(itemTag.itemId, itemId)
        XCTAssertEqual(itemTag.tagId, tagId)
    }

    func testItemTagWithDifferentIds() {
        // Given
        let itemId1 = "item-abc"
        let tagId1 = "tag-xyz"
        let itemId2 = "item-def"
        let tagId2 = "tag-uvw"

        // When
        let itemTag1 = ItemTag(itemId: itemId1, tagId: tagId1)
        let itemTag2 = ItemTag(itemId: itemId2, tagId: tagId2)

        // Then
        XCTAssertEqual(itemTag1.itemId, itemId1)
        XCTAssertEqual(itemTag1.tagId, tagId1)
        XCTAssertEqual(itemTag2.itemId, itemId2)
        XCTAssertEqual(itemTag2.tagId, tagId2)
        XCTAssertNotEqual(itemTag1.itemId, itemTag2.itemId)
        XCTAssertNotEqual(itemTag1.tagId, itemTag2.tagId)
    }

    // MARK: - Codable Tests

    func testItemTagEncodingWithSnakeCaseKeys() throws {
        // Given
        let itemTag = ItemTag(itemId: "item-999", tagId: "tag-888")

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(itemTag)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["item_id"] as? String, "item-999", "itemId should encode as item_id")
        XCTAssertEqual(json?["tag_id"] as? String, "tag-888", "tagId should encode as tag_id")
    }

    func testItemTagDecodingWithSnakeCaseKeys() throws {
        // Given
        let jsonString = """
        {
            "item_id": "item-111",
            "tag_id": "tag-222"
        }
        """
        let data = jsonString.data(using: .utf8)!

        // When
        let decoder = JSONDecoder()
        let itemTag = try decoder.decode(ItemTag.self, from: data)

        // Then
        XCTAssertEqual(itemTag.itemId, "item-111")
        XCTAssertEqual(itemTag.tagId, "tag-222")
    }

    func testItemTagRoundTripEncoding() throws {
        // Given
        let originalItemTag = ItemTag(itemId: "round-trip-item", tagId: "round-trip-tag")

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalItemTag)
        let decoder = JSONDecoder()
        let decodedItemTag = try decoder.decode(ItemTag.self, from: data)

        // Then
        XCTAssertEqual(decodedItemTag.itemId, originalItemTag.itemId)
        XCTAssertEqual(decodedItemTag.tagId, originalItemTag.tagId)
    }

    func testMultipleItemTagsForSameItem() {
        // Given - One item can have multiple tags
        let itemId = "item-shared"
        let tag1 = "tag-work"
        let tag2 = "tag-urgent"
        let tag3 = "tag-project"

        // When
        let itemTag1 = ItemTag(itemId: itemId, tagId: tag1)
        let itemTag2 = ItemTag(itemId: itemId, tagId: tag2)
        let itemTag3 = ItemTag(itemId: itemId, tagId: tag3)

        // Then
        XCTAssertEqual(itemTag1.itemId, itemId)
        XCTAssertEqual(itemTag2.itemId, itemId)
        XCTAssertEqual(itemTag3.itemId, itemId)
        XCTAssertNotEqual(itemTag1.tagId, itemTag2.tagId)
        XCTAssertNotEqual(itemTag2.tagId, itemTag3.tagId)
    }

    func testMultipleItemsWithSameTag() {
        // Given - One tag can be applied to multiple items
        let tagId = "tag-shared"
        let item1 = "item-a"
        let item2 = "item-b"
        let item3 = "item-c"

        // When
        let itemTag1 = ItemTag(itemId: item1, tagId: tagId)
        let itemTag2 = ItemTag(itemId: item2, tagId: tagId)
        let itemTag3 = ItemTag(itemId: item3, tagId: tagId)

        // Then
        XCTAssertEqual(itemTag1.tagId, tagId)
        XCTAssertEqual(itemTag2.tagId, tagId)
        XCTAssertEqual(itemTag3.tagId, tagId)
        XCTAssertNotEqual(itemTag1.itemId, itemTag2.itemId)
        XCTAssertNotEqual(itemTag2.itemId, itemTag3.itemId)
    }
}
