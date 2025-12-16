import XCTest
import Network
import DirectGTDCore
@testable import DirectGTD

/// Comprehensive tests for APIServer REST API
/// Tests all endpoints for correctness, error handling, and edge cases
final class APIServerTests: XCTestCase {
    var testDB: TestDatabaseWrapper!
    var repository: ItemRepository!
    var settings: UserSettings!
    var itemStore: ItemStore!
    var apiServer: APIServer!
    let testPort: UInt16 = 19876 // Different from default to avoid conflicts

    override func setUp() {
        super.setUp()

        testDB = TestDatabaseWrapper()
        repository = ItemRepository(database: testDB)
        settings = UserSettings()
        itemStore = ItemStore(settings: settings, repository: repository, database: testDB)
        itemStore.loadItems()

        apiServer = APIServer(itemStore: itemStore, port: testPort)
        try! apiServer.start()

        // Give server time to start
        Thread.sleep(forTimeInterval: 0.2)
    }

    override func tearDown() {
        // Stop server synchronously
        let expectation = XCTestExpectation(description: "Server stopped")
        Task {
            await apiServer.stop()
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        apiServer = nil
        itemStore = nil
        settings = nil
        repository = nil
        testDB = nil

        super.tearDown()
    }

    // MARK: - Helper Methods

    private func makeRequest(
        method: String,
        path: String,
        body: [String: Any]? = nil
    ) async throws -> (statusCode: Int, response: [String: Any]) {
        let url = "http://localhost:\(testPort)\(path)"

        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "APIServerTests", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not HTTP response"])
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        return (httpResponse.statusCode, json)
    }

    // MARK: - Health Check Tests

    func testHealthEndpoint() async throws {
        let (status, response) = try await makeRequest(method: "GET", path: "/health")

        XCTAssertEqual(status, 200)
        XCTAssertEqual(response["status"] as? String, "ok")
        XCTAssertNotNil(response["itemCount"])
    }

    // MARK: - Items CRUD Tests

    func testCreateItem() async throws {
        let body = ["title": "Test Item"]
        let (status, response) = try await makeRequest(method: "POST", path: "/items", body: body)

        print("DEBUG testCreateItem: status=\(status), response=\(response)")

        XCTAssertEqual(status, 200, "Expected status 200, got \(status). Response: \(response)")

        guard let item = response["item"] as? [String: Any] else {
            XCTFail("No item in response. Full response: \(response)")
            return
        }

        XCTAssertEqual(item["title"] as? String, "Test Item")
        XCTAssertNotNil(item["id"])
        XCTAssertEqual(item["itemType"] as? String, "Task") // Default type (capitalized per ItemType enum)
    }

    func testCreateItemWithParent() async throws {
        // Create parent first
        let parentBody = ["title": "Parent Item"]
        let (_, parentResponse) = try await makeRequest(method: "POST", path: "/items", body: parentBody)

        guard let parentItem = parentResponse["item"] as? [String: Any],
              let parentId = parentItem["id"] as? String else {
            XCTFail("Failed to create parent")
            return
        }

        // Create child
        let childBody: [String: Any] = [
            "title": "Child Item",
            "parentId": parentId
        ]
        let (status, response) = try await makeRequest(method: "POST", path: "/items", body: childBody)

        XCTAssertEqual(status, 200)

        guard let item = response["item"] as? [String: Any] else {
            XCTFail("No item in response")
            return
        }

        XCTAssertEqual(item["title"] as? String, "Child Item")
        XCTAssertEqual(item["parentId"] as? String, parentId)
    }

    func testCreateItemWithAllFields() async throws {
        let body: [String: Any] = [
            "title": "Complete Item",
            "itemType": "Project",
            "notes": "Test notes"
        ]
        let (status, response) = try await makeRequest(method: "POST", path: "/items", body: body)

        XCTAssertEqual(status, 200)

        guard let item = response["item"] as? [String: Any] else {
            XCTFail("No item in response")
            return
        }

        XCTAssertEqual(item["title"] as? String, "Complete Item")
        XCTAssertEqual(item["itemType"] as? String, "Project")
        XCTAssertEqual(item["notes"] as? String, "Test notes")
    }

    func testCreateItemMissingTitle() async throws {
        let body: [String: Any] = [:] // No title
        let (status, response) = try await makeRequest(method: "POST", path: "/items", body: body)

        XCTAssertEqual(status, 400)
        XCTAssertNotNil(response["error"])
        XCTAssertTrue((response["error"] as? String)?.contains("title") ?? false)
    }

    func testGetAllItems() async throws {
        // Create a few items
        _ = try await makeRequest(method: "POST", path: "/items", body: ["title": "Item 1"])
        _ = try await makeRequest(method: "POST", path: "/items", body: ["title": "Item 2"])

        let (status, response) = try await makeRequest(method: "GET", path: "/items")

        XCTAssertEqual(status, 200)

        guard let items = response["items"] as? [[String: Any]] else {
            XCTFail("No items array in response")
            return
        }

        XCTAssertGreaterThanOrEqual(items.count, 2)
    }

    func testGetSingleItem() async throws {
        // Create item
        let (_, createResponse) = try await makeRequest(method: "POST", path: "/items", body: ["title": "Single Item"])

        guard let item = createResponse["item"] as? [String: Any],
              let itemId = item["id"] as? String else {
            XCTFail("Failed to create item")
            return
        }

        // Get item
        let (status, response) = try await makeRequest(method: "GET", path: "/items/\(itemId)")

        XCTAssertEqual(status, 200)

        guard let fetchedItem = response["item"] as? [String: Any] else {
            XCTFail("No item in response")
            return
        }

        XCTAssertEqual(fetchedItem["id"] as? String, itemId)
        XCTAssertEqual(fetchedItem["title"] as? String, "Single Item")
    }

    func testGetNonExistentItem() async throws {
        let (status, response) = try await makeRequest(method: "GET", path: "/items/nonexistent-id")

        XCTAssertEqual(status, 404)
        XCTAssertNotNil(response["error"])
    }

    func testUpdateItem() async throws {
        // Create item
        let (_, createResponse) = try await makeRequest(method: "POST", path: "/items", body: ["title": "Original"])

        guard let item = createResponse["item"] as? [String: Any],
              let itemId = item["id"] as? String else {
            XCTFail("Failed to create item")
            return
        }

        // Update item
        let updateBody = ["title": "Updated Title"]
        let (status, response) = try await makeRequest(method: "PUT", path: "/items/\(itemId)", body: updateBody)

        XCTAssertEqual(status, 200)

        guard let updatedItem = response["item"] as? [String: Any] else {
            XCTFail("No item in response")
            return
        }

        XCTAssertEqual(updatedItem["title"] as? String, "Updated Title")
    }

    func testUpdateItemMultipleFields() async throws {
        // Create item
        let (_, createResponse) = try await makeRequest(method: "POST", path: "/items", body: ["title": "Original"])

        guard let item = createResponse["item"] as? [String: Any],
              let itemId = item["id"] as? String else {
            XCTFail("Failed to create item")
            return
        }

        // Update multiple fields
        let now = Int(Date().timeIntervalSince1970)
        let updateBody: [String: Any] = [
            "title": "New Title",
            "notes": "New notes",
            "itemType": "Note",
            "dueDate": now + 86400 // Tomorrow
        ]
        let (status, response) = try await makeRequest(method: "PUT", path: "/items/\(itemId)", body: updateBody)

        XCTAssertEqual(status, 200)

        guard let updatedItem = response["item"] as? [String: Any] else {
            XCTFail("No item in response")
            return
        }

        XCTAssertEqual(updatedItem["title"] as? String, "New Title")
        XCTAssertEqual(updatedItem["notes"] as? String, "New notes")
        XCTAssertEqual(updatedItem["itemType"] as? String, "Note")
        XCTAssertNotNil(updatedItem["dueDate"])
    }

    func testUpdateNonExistentItem() async throws {
        let (status, response) = try await makeRequest(
            method: "PUT",
            path: "/items/nonexistent-id",
            body: ["title": "New Title"]
        )

        XCTAssertEqual(status, 404)
        XCTAssertNotNil(response["error"])
    }

    func testDeleteItem() async throws {
        // Create item
        let (_, createResponse) = try await makeRequest(method: "POST", path: "/items", body: ["title": "To Delete"])

        guard let item = createResponse["item"] as? [String: Any],
              let itemId = item["id"] as? String else {
            XCTFail("Failed to create item")
            return
        }

        // Delete item
        let (status, response) = try await makeRequest(method: "DELETE", path: "/items/\(itemId)")

        XCTAssertEqual(status, 200)
        XCTAssertEqual(response["deleted"] as? Bool, true)
        XCTAssertEqual(response["id"] as? String, itemId)

        // Verify deleted
        let (getStatus, _) = try await makeRequest(method: "GET", path: "/items/\(itemId)")
        XCTAssertEqual(getStatus, 404)
    }

    func testDeleteNonExistentItem() async throws {
        let (status, response) = try await makeRequest(method: "DELETE", path: "/items/nonexistent-id")

        XCTAssertEqual(status, 404)
        XCTAssertNotNil(response["error"])
    }

    // MARK: - Item Hierarchy Tests

    func testGetRootItems() async throws {
        // Create root items
        _ = try await makeRequest(method: "POST", path: "/items", body: ["title": "Root 1"])
        _ = try await makeRequest(method: "POST", path: "/items", body: ["title": "Root 2"])

        let (status, response) = try await makeRequest(method: "GET", path: "/root-items")

        XCTAssertEqual(status, 200)

        guard let items = response["items"] as? [[String: Any]] else {
            XCTFail("No items array in response")
            return
        }

        XCTAssertGreaterThanOrEqual(items.count, 2)

        // Verify all are root items
        for item in items {
            XCTAssertNil(item["parentId"])
        }
    }

    func testGetItemChildren() async throws {
        // Create parent
        let (_, parentResponse) = try await makeRequest(method: "POST", path: "/items", body: ["title": "Parent"])

        guard let parentItem = parentResponse["item"] as? [String: Any],
              let parentId = parentItem["id"] as? String else {
            XCTFail("Failed to create parent")
            return
        }

        // Create children
        _ = try await makeRequest(method: "POST", path: "/items", body: ["title": "Child 1", "parentId": parentId])
        _ = try await makeRequest(method: "POST", path: "/items", body: ["title": "Child 2", "parentId": parentId])

        let (status, response) = try await makeRequest(method: "GET", path: "/items/\(parentId)/children")

        XCTAssertEqual(status, 200)

        guard let children = response["items"] as? [[String: Any]] else {
            XCTFail("No items array in response")
            return
        }

        XCTAssertEqual(children.count, 2)

        // Verify all have correct parent
        for child in children {
            XCTAssertEqual(child["parentId"] as? String, parentId)
        }
    }

    // MARK: - Task Completion Tests

    func testToggleTaskCompletion() async throws {
        // Create task
        let (_, createResponse) = try await makeRequest(method: "POST", path: "/items", body: ["title": "Task"])

        guard let item = createResponse["item"] as? [String: Any],
              let itemId = item["id"] as? String else {
            XCTFail("Failed to create task")
            return
        }

        // Toggle completion
        let (status, response) = try await makeRequest(method: "POST", path: "/items/\(itemId)/complete")

        XCTAssertEqual(status, 200)

        guard let updatedItem = response["item"] as? [String: Any] else {
            XCTFail("No item in response")
            return
        }

        XCTAssertNotNil(updatedItem["completedAt"])
    }

    // MARK: - Move Operation Tests

    func testMoveItemInto() async throws {
        // Create two items
        let (_, item1Response) = try await makeRequest(method: "POST", path: "/items", body: ["title": "Item 1"])
        let (_, item2Response) = try await makeRequest(method: "POST", path: "/items", body: ["title": "Item 2"])

        guard let item1 = item1Response["item"] as? [String: Any],
              let item1Id = item1["id"] as? String,
              let item2 = item2Response["item"] as? [String: Any],
              let item2Id = item2["id"] as? String else {
            XCTFail("Failed to create items")
            return
        }

        // Move item1 into item2
        let moveBody: [String: Any] = [
            "targetId": item2Id,
            "position": "into"
        ]
        let (status, response) = try await makeRequest(method: "POST", path: "/items/\(item1Id)/move", body: moveBody)

        XCTAssertEqual(status, 200)

        guard let movedItem = response["item"] as? [String: Any] else {
            XCTFail("No item in response")
            return
        }

        XCTAssertEqual(movedItem["parentId"] as? String, item2Id)
    }

    func testMoveItemInvalidOperation() async throws {
        // Try to move item into itself
        let (_, createResponse) = try await makeRequest(method: "POST", path: "/items", body: ["title": "Item"])

        guard let item = createResponse["item"] as? [String: Any],
              let itemId = item["id"] as? String else {
            XCTFail("Failed to create item")
            return
        }

        let moveBody: [String: Any] = [
            "targetId": itemId,
            "position": "into"
        ]
        let (status, response) = try await makeRequest(method: "POST", path: "/items/\(itemId)/move", body: moveBody)

        XCTAssertEqual(status, 400)
        XCTAssertNotNil(response["error"])
    }

    // MARK: - Search Tests

    func testTextSearch() async throws {
        // Create items with searchable text
        _ = try await makeRequest(method: "POST", path: "/items", body: ["title": "Find this item"])
        _ = try await makeRequest(method: "POST", path: "/items", body: ["title": "Other item"])

        let (status, response) = try await makeRequest(method: "GET", path: "/search?q=Find")

        XCTAssertEqual(status, 200)

        guard let items = response["items"] as? [[String: Any]] else {
            XCTFail("No items array in response")
            return
        }

        XCTAssertGreaterThanOrEqual(items.count, 1)
        XCTAssertTrue(items.contains { ($0["title"] as? String)?.contains("Find") ?? false })
    }

    func testSearchMissingQuery() async throws {
        let (status, response) = try await makeRequest(method: "GET", path: "/search")

        XCTAssertEqual(status, 400)
        XCTAssertNotNil(response["error"])
    }

    // MARK: - Tags Tests

    func testCreateTag() async throws {
        let body = ["name": "Test Tag", "color": "#FF0000"]
        let (status, response) = try await makeRequest(method: "POST", path: "/tags", body: body)

        XCTAssertEqual(status, 200)

        guard let tag = response["tag"] as? [String: Any] else {
            XCTFail("No tag in response")
            return
        }

        XCTAssertEqual(tag["name"] as? String, "Test Tag")
        XCTAssertEqual(tag["color"] as? String, "#FF0000")
        XCTAssertNotNil(tag["id"])
    }

    func testCreateTagMissingName() async throws {
        let body: [String: Any] = [:] // No name
        let (status, response) = try await makeRequest(method: "POST", path: "/tags", body: body)

        XCTAssertEqual(status, 400)
        XCTAssertNotNil(response["error"])
    }

    func testGetAllTags() async throws {
        // Create tags
        _ = try await makeRequest(method: "POST", path: "/tags", body: ["name": "Tag 1"])
        _ = try await makeRequest(method: "POST", path: "/tags", body: ["name": "Tag 2"])

        let (status, response) = try await makeRequest(method: "GET", path: "/tags")

        XCTAssertEqual(status, 200)

        guard let tags = response["tags"] as? [[String: Any]] else {
            XCTFail("No tags array in response")
            return
        }

        XCTAssertGreaterThanOrEqual(tags.count, 2)
    }

    func testUpdateTag() async throws {
        // Create tag
        let (_, createResponse) = try await makeRequest(method: "POST", path: "/tags", body: ["name": "Original"])

        guard let tag = createResponse["tag"] as? [String: Any],
              let tagId = tag["id"] as? String else {
            XCTFail("Failed to create tag")
            return
        }

        // Update tag
        let updateBody = ["name": "Updated Tag", "color": "#00FF00"]
        let (status, response) = try await makeRequest(method: "PUT", path: "/tags/\(tagId)", body: updateBody)

        XCTAssertEqual(status, 200)

        guard let updatedTag = response["tag"] as? [String: Any] else {
            XCTFail("No tag in response")
            return
        }

        XCTAssertEqual(updatedTag["name"] as? String, "Updated Tag")
        XCTAssertEqual(updatedTag["color"] as? String, "#00FF00")
    }

    func testDeleteTag() async throws {
        // Create tag
        let (_, createResponse) = try await makeRequest(method: "POST", path: "/tags", body: ["name": "To Delete"])

        guard let tag = createResponse["tag"] as? [String: Any],
              let tagId = tag["id"] as? String else {
            XCTFail("Failed to create tag")
            return
        }

        // Delete tag
        let (status, response) = try await makeRequest(method: "DELETE", path: "/tags/\(tagId)")

        XCTAssertEqual(status, 200)
        XCTAssertEqual(response["deleted"] as? Bool, true)
    }

    // MARK: - Item-Tag Association Tests

    func testAddTagToItem() async throws {
        // Create item and tag
        let (_, itemResponse) = try await makeRequest(method: "POST", path: "/items", body: ["title": "Item"])
        let (_, tagResponse) = try await makeRequest(method: "POST", path: "/tags", body: ["name": "Tag"])

        guard let item = itemResponse["item"] as? [String: Any],
              let itemId = item["id"] as? String,
              let tag = tagResponse["tag"] as? [String: Any],
              let tagId = tag["id"] as? String else {
            XCTFail("Failed to create item or tag")
            return
        }

        // Add tag to item
        let addBody = ["tagId": tagId]
        let (status, response) = try await makeRequest(method: "POST", path: "/items/\(itemId)/tags", body: addBody)

        XCTAssertEqual(status, 200)

        guard let tags = response["tags"] as? [[String: Any]] else {
            XCTFail("No tags array in response")
            return
        }

        XCTAssertTrue(tags.contains { ($0["id"] as? String) == tagId })
    }

    func testGetItemTags() async throws {
        // Create item and tag
        let (_, itemResponse) = try await makeRequest(method: "POST", path: "/items", body: ["title": "Item"])
        let (_, tagResponse) = try await makeRequest(method: "POST", path: "/tags", body: ["name": "Tag"])

        guard let item = itemResponse["item"] as? [String: Any],
              let itemId = item["id"] as? String,
              let tag = tagResponse["tag"] as? [String: Any],
              let tagId = tag["id"] as? String else {
            XCTFail("Failed to create item or tag")
            return
        }

        // Add tag to item
        _ = try await makeRequest(method: "POST", path: "/items/\(itemId)/tags", body: ["tagId": tagId])

        // Get tags
        let (status, response) = try await makeRequest(method: "GET", path: "/items/\(itemId)/tags")

        XCTAssertEqual(status, 200)

        guard let tags = response["tags"] as? [[String: Any]] else {
            XCTFail("No tags array in response")
            return
        }

        XCTAssertEqual(tags.count, 1)
        XCTAssertEqual(tags.first?["id"] as? String, tagId)
    }

    func testRemoveTagFromItem() async throws {
        // Create item and tag
        let (_, itemResponse) = try await makeRequest(method: "POST", path: "/items", body: ["title": "Item"])
        let (_, tagResponse) = try await makeRequest(method: "POST", path: "/tags", body: ["name": "Tag"])

        guard let item = itemResponse["item"] as? [String: Any],
              let itemId = item["id"] as? String,
              let tag = tagResponse["tag"] as? [String: Any],
              let tagId = tag["id"] as? String else {
            XCTFail("Failed to create item or tag")
            return
        }

        // Add tag to item
        _ = try await makeRequest(method: "POST", path: "/items/\(itemId)/tags", body: ["tagId": tagId])

        // Remove tag from item
        let (status, response) = try await makeRequest(method: "DELETE", path: "/items/\(itemId)/tags/\(tagId)")

        XCTAssertEqual(status, 200)

        guard let tags = response["tags"] as? [[String: Any]] else {
            XCTFail("No tags array in response")
            return
        }

        XCTAssertEqual(tags.count, 0)
    }

    // MARK: - Time Tracking Tests

    func testStartTimer() async throws {
        // Create item
        let (_, itemResponse) = try await makeRequest(method: "POST", path: "/items", body: ["title": "Task"])

        guard let item = itemResponse["item"] as? [String: Any],
              let itemId = item["id"] as? String else {
            XCTFail("Failed to create item")
            return
        }

        // Start timer
        let (status, response) = try await makeRequest(method: "POST", path: "/items/\(itemId)/timer/start")

        XCTAssertEqual(status, 200)

        guard let entry = response["entry"] as? [String: Any] else {
            XCTFail("No entry in response")
            return
        }

        XCTAssertEqual(entry["itemId"] as? String, itemId)
        XCTAssertNotNil(entry["startedAt"])
        XCTAssertNil(entry["endedAt"])
    }

    func testStopTimer() async throws {
        // Create item
        let (_, itemResponse) = try await makeRequest(method: "POST", path: "/items", body: ["title": "Task"])

        guard let item = itemResponse["item"] as? [String: Any],
              let itemId = item["id"] as? String else {
            XCTFail("Failed to create item")
            return
        }

        // Start timer
        _ = try await makeRequest(method: "POST", path: "/items/\(itemId)/timer/start")

        // Stop timer
        let (status, response) = try await makeRequest(method: "POST", path: "/items/\(itemId)/timer/stop")

        XCTAssertEqual(status, 200)

        guard let entry = response["entry"] as? [String: Any] else {
            XCTFail("No entry in response")
            return
        }

        XCTAssertNotNil(entry["endedAt"])
        XCTAssertNotNil(entry["duration"])
    }

    func testToggleTimer() async throws {
        // Create item
        let (_, itemResponse) = try await makeRequest(method: "POST", path: "/items", body: ["title": "Task"])

        guard let item = itemResponse["item"] as? [String: Any],
              let itemId = item["id"] as? String else {
            XCTFail("Failed to create item")
            return
        }

        // Toggle on
        let (status1, response1) = try await makeRequest(method: "POST", path: "/items/\(itemId)/timer/toggle")

        XCTAssertEqual(status1, 200)
        XCTAssertEqual(response1["isRunning"] as? Bool, true)

        // Toggle off
        let (status2, response2) = try await makeRequest(method: "POST", path: "/items/\(itemId)/timer/toggle")

        XCTAssertEqual(status2, 200)
        XCTAssertEqual(response2["isRunning"] as? Bool, false)
    }

    func testGetTimeEntries() async throws {
        // Create item
        let (_, itemResponse) = try await makeRequest(method: "POST", path: "/items", body: ["title": "Task"])

        guard let item = itemResponse["item"] as? [String: Any],
              let itemId = item["id"] as? String else {
            XCTFail("Failed to create item")
            return
        }

        // Start and stop timer
        _ = try await makeRequest(method: "POST", path: "/items/\(itemId)/timer/start")
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        _ = try await makeRequest(method: "POST", path: "/items/\(itemId)/timer/stop")

        // Get entries
        let (status, response) = try await makeRequest(method: "GET", path: "/items/\(itemId)/time-entries")

        XCTAssertEqual(status, 200)

        guard let entries = response["entries"] as? [[String: Any]] else {
            XCTFail("No entries array in response")
            return
        }

        XCTAssertEqual(entries.count, 1)
        XCTAssertNotNil(response["totalSeconds"])
        XCTAssertEqual(response["hasActiveTimer"] as? Bool, false)
    }

    // MARK: - Utility Endpoint Tests

    func testReloadEndpoint() async throws {
        let (status, response) = try await makeRequest(method: "POST", path: "/reload")

        XCTAssertEqual(status, 200)
        XCTAssertEqual(response["reloaded"] as? Bool, true)
        XCTAssertNotNil(response["itemCount"])
    }

    func testSyncEndpoint() async throws {
        let (status, response) = try await makeRequest(method: "POST", path: "/sync")

        XCTAssertEqual(status, 200)
        XCTAssertEqual(response["requested"] as? Bool, true)
    }

    // MARK: - Error Handling Tests

    func testInvalidRoute() async throws {
        let (status, response) = try await makeRequest(method: "GET", path: "/nonexistent")

        XCTAssertEqual(status, 404)
        XCTAssertNotNil(response["error"])
    }

    func testInvalidJSON() async throws {
        let url = "http://localhost:\(testPort)/items"
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "invalid json".data(using: .utf8)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            XCTFail("Not HTTP response")
            return
        }

        XCTAssertEqual(httpResponse.statusCode, 400)
    }
}
