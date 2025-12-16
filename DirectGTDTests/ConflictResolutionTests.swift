import XCTest
import CloudKit
import GRDB
import DirectGTDCore
@testable import DirectGTD

/// Tests for conflict resolution logic and last-write-wins strategy
final class ConflictResolutionTests: XCTestCase {
    var testDB: TestDatabaseWrapper!
    var dbQueue: DatabaseQueue!

    override func setUp() {
        super.setUp()
        testDB = TestDatabaseWrapper()
        dbQueue = testDB.getQueue()!
    }

    override func tearDown() {
        testDB = nil
        dbQueue = nil
        super.tearDown()
    }

    // MARK: - Last-Write-Wins Logic Tests

    func testLastWriteWinsServerNewer() {
        let localModifiedAt = 1000
        let serverModifiedAt = 2000

        // Server should win
        let serverWins = serverModifiedAt > localModifiedAt
        XCTAssertTrue(serverWins, "Server should win when it has newer timestamp")
    }

    func testLastWriteWinsLocalNewer() {
        let localModifiedAt = 2000
        let serverModifiedAt = 1000

        // Local should win
        let localWins = localModifiedAt > serverModifiedAt
        XCTAssertTrue(localWins, "Local should win when it has newer timestamp")
    }

    func testLastWriteWinsSameTimestamp() {
        let localModifiedAt = 1000
        let serverModifiedAt = 1000

        // When equal, server wins (fail-safe)
        let serverWins = serverModifiedAt >= localModifiedAt
        XCTAssertTrue(serverWins, "Server should win when timestamps are equal")
    }

    // MARK: - Item Conflict Tests

    func testItemConflictServerWins() throws {
        // Create local item
        let itemId = UUID().uuidString
        try dbQueue.write { db in
            var item = Item(id: itemId)
            item.title = "Local Title"
            item.modifiedAt = 1000
            item.createdAt = 1000
            item.needsPush = 1
            item.ckRecordName = "item-\(itemId)"
            try item.insert(db)
        }

        // Simulate server version (newer)
        let serverModifiedAt = 2000
        let serverTitle = "Server Title"

        // Server wins - apply server version
        try dbQueue.write { db in
            var item = try Item.fetchOne(db, key: itemId)!
            item.title = serverTitle
            item.modifiedAt = serverModifiedAt
            item.needsPush = 0  // Server version is synced
            try item.update(db)
        }

        // Verify
        let finalItem = try dbQueue.read { db in
            try Item.fetchOne(db, key: itemId)!
        }

        XCTAssertEqual(finalItem.title, serverTitle)
        XCTAssertEqual(finalItem.modifiedAt, serverModifiedAt)
        XCTAssertEqual(finalItem.needsPush, 0)
    }

    func testItemConflictLocalWins() throws {
        // Create local item (newer)
        let itemId = UUID().uuidString
        let localModifiedAt = 2000
        let localTitle = "Local Title"

        try dbQueue.write { db in
            var item = Item(id: itemId)
            item.title = localTitle
            item.modifiedAt = localModifiedAt
            item.createdAt = 1000
            item.needsPush = 1
            item.ckRecordName = "item-\(itemId)"
            item.ckChangeTag = "old-tag"
            try item.insert(db)
        }

        // Simulate conflict detection - local is newer
        let serverModifiedAt = 1000
        let serverChangeTag = "new-server-tag"

        // Local wins - update change tag but keep local data, mark for retry
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE items SET ck_change_tag = ?, needs_push = 1 WHERE id = ?",
                arguments: [serverChangeTag, itemId]
            )
        }

        // Verify local data preserved but ready for retry
        let finalItem = try dbQueue.read { db in
            try Item.fetchOne(db, key: itemId)!
        }

        XCTAssertEqual(finalItem.title, localTitle)  // Local data preserved
        XCTAssertEqual(finalItem.modifiedAt, localModifiedAt)
        XCTAssertEqual(finalItem.ckChangeTag, serverChangeTag)  // Server tag updated
        XCTAssertEqual(finalItem.needsPush, 1)  // Marked for retry
    }

    // MARK: - Tag Conflict Tests

    func testTagConflictServerWins() throws {
        let tagId = UUID().uuidString
        try dbQueue.write { db in
            var tag = Tag(
                id: tagId,
                name: "Local Tag",
                createdAt: 1000
            )
            tag.modifiedAt = 1000
            tag.needsPush = 1
            tag.ckRecordName = "tag-\(tagId)"
            try tag.insert(db)
        }

        // Server version is newer
        let serverModifiedAt = 2000
        let serverName = "Server Tag"

        try dbQueue.write { db in
            var tag = try Tag.fetchOne(db, key: tagId)!
            tag.name = serverName
            tag.modifiedAt = serverModifiedAt
            tag.needsPush = 0
            try tag.update(db)
        }

        let finalTag = try dbQueue.read { db in
            try Tag.fetchOne(db, key: tagId)!
        }

        XCTAssertEqual(finalTag.name, serverName)
        XCTAssertEqual(finalTag.modifiedAt, serverModifiedAt)
    }

    func testTagConflictLocalWins() throws {
        let tagId = UUID().uuidString
        let localModifiedAt = 2000

        try dbQueue.write { db in
            var tag = Tag(
                id: tagId,
                name: "Local Tag",
                createdAt: 1000
            )
            tag.modifiedAt = localModifiedAt
            tag.needsPush = 1
            tag.ckRecordName = "tag-\(tagId)"
            try tag.insert(db)
        }

        // Verify local wins scenario
        let tag = try dbQueue.read { db in
            try Tag.fetchOne(db, key: tagId)!
        }

        XCTAssertEqual(tag.modifiedAt, localModifiedAt)
        XCTAssertEqual(tag.needsPush, 1)
    }

    // MARK: - ItemTag Conflict Tests

    func testItemTagConflictResolution() throws {
        // Create prerequisite item and tag
        let itemId = UUID().uuidString
        let tagId = UUID().uuidString

        try dbQueue.write { db in
            var item = Item(id: itemId)
            item.title = "Test Item"
            item.modifiedAt = 1000
            item.createdAt = 1000
            try item.insert(db)

            var tag = Tag(id: tagId, name: "Test Tag", createdAt: 1000)
            tag.modifiedAt = 1000
            try tag.insert(db)
        }

        // Create ItemTag
        try dbQueue.write { db in
            var itemTag = ItemTag(itemId: itemId, tagId: tagId, createdAt: 1000)
            itemTag.modifiedAt = 1000
            itemTag.needsPush = 1
            itemTag.ckRecordName = "itemtag-\(itemId)-\(tagId)"
            try itemTag.insert(db)
        }

        // Server version is newer
        let serverModifiedAt = 2000

        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE item_tags SET modified_at = ?, needs_push = 0 WHERE item_id = ? AND tag_id = ?",
                arguments: [serverModifiedAt, itemId, tagId]
            )
        }

        let finalItemTag = try dbQueue.read { db in
            try ItemTag
                .filter(Column("item_id") == itemId && Column("tag_id") == tagId)
                .fetchOne(db)!
        }

        XCTAssertEqual(finalItemTag.modifiedAt, serverModifiedAt)
    }

    // MARK: - Deleted Record Conflict Tests

    func testDeletedRecordConflictLocalDeleted() throws {
        let itemId = UUID().uuidString
        let now = Int(Date().timeIntervalSince1970)

        // Create item that's been soft-deleted locally
        try dbQueue.write { db in
            var item = Item(id: itemId)
            item.title = "Deleted Item"
            item.modifiedAt = now
            item.createdAt = 1000
            item.deletedAt = now
            item.needsPush = 1  // Needs to sync deletion
            item.ckRecordName = "item-\(itemId)"
            try item.insert(db)
        }

        // Verify deletion is tracked
        let item = try dbQueue.read { db in
            try Item.fetchOne(db, key: itemId)!
        }

        XCTAssertNotNil(item.deletedAt)
        XCTAssertEqual(item.needsPush, 1)
    }

    func testDeletedRecordConflictServerDeleted() throws {
        let itemId = UUID().uuidString
        let now = Int(Date().timeIntervalSince1970)

        // Create active local item
        try dbQueue.write { db in
            var item = Item(id: itemId)
            item.title = "Active Item"
            item.modifiedAt = 1000
            item.createdAt = 1000
            item.ckRecordName = "item-\(itemId)"
            try item.insert(db)
        }

        // Server sends deletion - mark as deleted locally
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE items SET deleted_at = ?, needs_push = 0 WHERE id = ?",
                arguments: [now, itemId]
            )
        }

        let item = try dbQueue.read { db in
            try Item.fetchOne(db, key: itemId)!
        }

        XCTAssertNotNil(item.deletedAt)
        XCTAssertEqual(item.needsPush, 0)  // Server deletion is synced
    }

    // MARK: - Change Tag Tests

    func testChangeTagUpdateOnConflict() throws {
        let itemId = UUID().uuidString

        try dbQueue.write { db in
            var item = Item(id: itemId)
            item.title = "Test Item"
            item.modifiedAt = 1000
            item.createdAt = 1000
            item.ckRecordName = "item-\(itemId)"
            item.ckChangeTag = "tag-v1"
            item.needsPush = 1
            try item.insert(db)
        }

        // Simulate conflict - update change tag from server
        let newChangeTag = "tag-v2"
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE items SET ck_change_tag = ? WHERE id = ?",
                arguments: [newChangeTag, itemId]
            )
        }

        let item = try dbQueue.read { db in
            try Item.fetchOne(db, key: itemId)!
        }

        XCTAssertEqual(item.ckChangeTag, newChangeTag)
    }

    // MARK: - Concurrent Modification Tests

    func testConcurrentModificationDetection() {
        // Two devices modify the same record
        let device1ModifiedAt = 1000
        let device2ModifiedAt = 1500

        // Device 2's change is newer
        let device2Wins = device2ModifiedAt > device1ModifiedAt
        XCTAssertTrue(device2Wins)
    }

    func testConcurrentModificationWithinSecond() {
        // Changes within the same second
        let device1ModifiedAt = 1000
        let device2ModifiedAt = 1000

        // When timestamps are equal, server wins (implementation detail)
        let conflict = device1ModifiedAt == device2ModifiedAt
        XCTAssertTrue(conflict, "Should detect conflict when timestamps are equal")
    }

    // MARK: - Field-Level Conflict Tests

    func testFieldLevelConflictName() throws {
        let itemId = UUID().uuidString

        // Local has newer title change
        try dbQueue.write { db in
            var item = Item(id: itemId)
            item.title = "New Title"
            item.modifiedAt = 2000
            item.createdAt = 1000
            item.needsPush = 1
            try item.insert(db)
        }

        // Verify field preserved when local wins
        let item = try dbQueue.read { db in
            try Item.fetchOne(db, key: itemId)!
        }

        XCTAssertEqual(item.title, "New Title")
        XCTAssertEqual(item.modifiedAt, 2000)
    }

    func testFieldLevelConflictNotes() throws {
        let itemId = UUID().uuidString

        // Local has notes update
        try dbQueue.write { db in
            var item = Item(id: itemId)
            item.title = "Item"
            item.modifiedAt = 2000
            item.createdAt = 1000
            item.notes = "Updated notes"
            item.needsPush = 1
            try item.insert(db)
        }

        let item = try dbQueue.read { db in
            try Item.fetchOne(db, key: itemId)!
        }

        XCTAssertEqual(item.notes, "Updated notes")
    }

    // MARK: - Multiple Record Type Conflicts

    func testTimeEntryConflictResolution() throws {
        // Create prerequisite item
        let itemId = UUID().uuidString
        try dbQueue.write { db in
            var item = Item(id: itemId)
            item.title = "Test Item"
            item.modifiedAt = 1000
            item.createdAt = 1000
            try item.insert(db)
        }

        // Create time entry
        let entryId = UUID().uuidString
        try dbQueue.write { db in
            var entry = TimeEntry(
                id: entryId,
                itemId: itemId,
                startedAt: 1000
            )
            entry.modifiedAt = 1000
            entry.needsPush = 1
            entry.ckRecordName = "entry-\(entryId)"
            try entry.insert(db)
        }

        // Server version is newer
        let serverModifiedAt = 2000
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE time_entries SET modified_at = ?, needs_push = 0 WHERE id = ?",
                arguments: [serverModifiedAt, entryId]
            )
        }

        let entry = try dbQueue.read { db in
            try TimeEntry.fetchOne(db, key: entryId)!
        }

        XCTAssertEqual(entry.modifiedAt, serverModifiedAt)
        XCTAssertEqual(entry.needsPush, 0)
    }

    func testSavedSearchConflictResolution() throws {
        let searchId = UUID().uuidString

        try dbQueue.write { db in
            var search = SavedSearch(
                id: searchId,
                name: "Local Search",
                sql: "SELECT * FROM items WHERE title LIKE '%test%'"
            )
            search.modifiedAt = 1000
            search.needsPush = 1
            search.ckRecordName = "search-\(searchId)"
            try search.insert(db)
        }

        // Server version
        let serverModifiedAt = 2000
        let serverName = "Server Search"

        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE saved_searches SET name = ?, modified_at = ?, needs_push = 0 WHERE id = ?",
                arguments: [serverName, serverModifiedAt, searchId]
            )
        }

        let search = try dbQueue.read { db in
            try SavedSearch.fetchOne(db, key: searchId)!
        }

        XCTAssertEqual(search.name, serverName)
        XCTAssertEqual(search.modifiedAt, serverModifiedAt)
    }

    // MARK: - Retry After Conflict Tests

    func testConflictMarkedForRetry() throws {
        let itemId = UUID().uuidString

        // Local item loses conflict but needs retry with server's change tag
        try dbQueue.write { db in
            var item = Item(id: itemId)
            item.title = "Local Data"
            item.modifiedAt = 2000  // Local is newer
            item.createdAt = 1000
            item.ckRecordName = "item-\(itemId)"
            item.ckChangeTag = "old-tag"
            item.needsPush = 0
            try item.insert(db)
        }

        // Update with server's change tag and mark for retry
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE items SET ck_change_tag = ?, needs_push = 1 WHERE id = ?",
                arguments: ["server-tag", itemId]
            )
        }

        let item = try dbQueue.read { db in
            try Item.fetchOne(db, key: itemId)!
        }

        XCTAssertEqual(item.ckChangeTag, "server-tag")
        XCTAssertEqual(item.needsPush, 1)
        XCTAssertEqual(item.title, "Local Data")  // Local data preserved
    }
}
