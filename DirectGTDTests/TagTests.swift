import DirectGTDCore
import XCTest
@testable import DirectGTD

final class TagTests: XCTestCase {

    // MARK: - Initialization Tests

    func testTagInitializationWithRequiredFields() {
        // Given
        let tagName = "Work"

        // When
        let tag = Tag(name: tagName)

        // Then
        XCTAssertFalse(tag.id.isEmpty, "Tag should have a non-empty ID")
        XCTAssertEqual(tag.name, tagName)
        XCTAssertNil(tag.color, "Color should be nil by default")
    }

    func testTagInitializationWithAllFields() {
        // Given
        let customId = "tag-123"
        let tagName = "Personal"
        let tagColor = "#FF5733"

        // When
        let tag = Tag(id: customId, name: tagName, color: tagColor)

        // Then
        XCTAssertEqual(tag.id, customId)
        XCTAssertEqual(tag.name, tagName)
        XCTAssertEqual(tag.color, tagColor)
    }

    func testTagGeneratesUniqueIds() {
        // Given/When
        let tag1 = Tag(name: "Tag 1")
        let tag2 = Tag(name: "Tag 2")

        // Then
        XCTAssertNotEqual(tag1.id, tag2.id, "Each tag should have a unique ID")
    }

    // MARK: - Codable Tests

    func testTagEncoding() throws {
        // Given
        let tag = Tag(id: "test-tag", name: "Important", color: "#FF0000")

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(tag)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["id"] as? String, "test-tag")
        XCTAssertEqual(json?["name"] as? String, "Important")
        XCTAssertEqual(json?["color"] as? String, "#FF0000")
    }

    func testTagDecoding() throws {
        // Given
        let jsonString = """
        {
            "id": "tag-456",
            "name": "Urgent",
            "color": "#00FF00"
        }
        """
        let data = jsonString.data(using: .utf8)!

        // When
        let decoder = JSONDecoder()
        let tag = try decoder.decode(Tag.self, from: data)

        // Then
        XCTAssertEqual(tag.id, "tag-456")
        XCTAssertEqual(tag.name, "Urgent")
        XCTAssertEqual(tag.color, "#00FF00")
    }

    func testTagDecodingWithoutColor() throws {
        // Given - JSON without optional color field
        let jsonString = """
        {
            "id": "tag-789",
            "name": "Project"
        }
        """
        let data = jsonString.data(using: .utf8)!

        // When
        let decoder = JSONDecoder()
        let tag = try decoder.decode(Tag.self, from: data)

        // Then
        XCTAssertEqual(tag.id, "tag-789")
        XCTAssertEqual(tag.name, "Project")
        XCTAssertNil(tag.color)
    }

    func testTagRoundTripEncoding() throws {
        // Given
        let originalTag = Tag(id: "round-trip", name: "Test Tag", color: "#0000FF")

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalTag)
        let decoder = JSONDecoder()
        let decodedTag = try decoder.decode(Tag.self, from: data)

        // Then
        XCTAssertEqual(decodedTag.id, originalTag.id)
        XCTAssertEqual(decodedTag.name, originalTag.name)
        XCTAssertEqual(decodedTag.color, originalTag.color)
    }
}
