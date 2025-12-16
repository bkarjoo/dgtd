import XCTest
import GRDB
import DirectGTDCore
@testable import DirectGTD

/// Comprehensive tests for SoftDeleteService - cascading soft deletes and tombstone management
final class SoftDeleteServiceTests: XCTestCase {
    var testDB: TestDatabaseWrapper!
    var dbQueue: DatabaseQueue!
    var service: SoftDeleteService!

    override func setUp() {
        super.setUp()
        testDB = TestDatabaseWrapper()
        dbQueue = testDB.getQueue()!
        service = SoftDeleteService(database: testDB)
    }

    override func tearDown() {
        service = nil
        dbQueue = nil
        testDB = nil
        super.tearDown()
    }

    // MARK: - Item Soft Delete Tests

    func testSoftDeleteSingleItem() throws {
        // Create item
        let itemId = UUID().uuidString
        try dbQueue.write { db in
            var item = Item(id: itemId)
            item.title = "Test Item"
            item.createdAt = 1000
            item.modifiedAt = 1000
            try item.insert(db)
        }

        // Soft delete
        try service.softDeleteItem(id: itemId)

        // Verify
        let item = try dbQueue.read { db in
            try Item.fetchOne(db, key: itemId)
        }

        XCTAssertNotNil(item?.deletedAt, "Should have deletedAt set")
        XCTAssertEqual(item?.needsPush, 1, "Should be marked for push")
        XCTAssertNotNil(item?.ckRecordName, "Should have ckRecordName set")
        XCTAssertEqual(item?.ckRecordName, "Item_\(itemId)")
    }

    func testSoftDeleteItemWithChildren() throws {
        // Create parent and 2 children
        let parentId = UUID().uuidString
        let child1Id = UUID().uuidString
        let child2Id = UUID().uuidString

        try dbQueue.write { db in
            var parent = Item(id: parentId)
            parent.title = "Parent"
            parent.createdAt = 1000
            parent.modifiedAt = 1000
            try parent.insert(db)

            var child1 = Item(id: child1Id)
            child1.title = "Child 1"
            child1.parentId = parentId
            child1.createdAt = 1000
            child1.modifiedAt = 1000
            try child1.insert(db)

            var child2 = Item(id: child2Id)
            child2.title = "Child 2"
            child2.parentId = parentId
            child2.createdAt = 1000
            child2.modifiedAt = 1000
            try child2.insert(db)
        }

        // Soft delete parent
        try service.softDeleteItem(id: parentId)

        // Verify all marked as deleted
        let items = try dbQueue.read { db in
            try Item.fetchAll(db, keys: [parentId, child1Id, child2Id])
        }

        XCTAssertEqual(items.count, 3)
        for item in items {
            XCTAssertNotNil(item.deletedAt, "\(item.title ?? "unknown") should be deleted")
            XCTAssertEqual(item.needsPush, 1, "\(item.title ?? "unknown") should need push")
            XCTAssertNotNil(item.ckRecordName, "\(item.title ?? "unknown") should have record name")
        }
    }

    func testSoftDeleteItemWithNestedChildren() throws {
        // Create: parent -> child -> grandchild
        let parentId = UUID().uuidString
        let childId = UUID().uuidString
        let grandchildId = UUID().uuidString

        try dbQueue.write { db in
            var parent = Item(id: parentId)
            parent.title = "Parent"
            parent.createdAt = 1000
            parent.modifiedAt = 1000
            try parent.insert(db)

            var child = Item(id: childId)
            child.title = "Child"
            child.parentId = parentId
            child.createdAt = 1000
            child.modifiedAt = 1000
            try child.insert(db)

            var grandchild = Item(id: grandchildId)
            grandchild.title = "Grandchild"
            grandchild.parentId = childId
            grandchild.createdAt = 1000
            grandchild.modifiedAt = 1000
            try grandchild.insert(db)
        }

        // Soft delete parent
        try service.softDeleteItem(id: parentId)

        // Verify all 3 levels deleted
        let items = try dbQueue.read { db in
            try Item.fetchAll(db, keys: [parentId, childId, grandchildId])
        }

        XCTAssertEqual(items.count, 3)
        for item in items {
            XCTAssertNotNil(item.deletedAt, "\(item.title ?? "unknown") should be deleted")
        }
    }

    func testSoftDeleteItemCascadesToItemTags() throws {
        // Create item and tag
        let itemId = UUID().uuidString
        let tagId = UUID().uuidString

        try dbQueue.write { db in
            var item = Item(id: itemId)
            item.title = "Test"
            item.createdAt = 1000
            item.modifiedAt = 1000
            try item.insert(db)

            var tag = Tag(id: tagId, name: "Test Tag", createdAt: 1000)
            tag.modifiedAt = 1000
            try tag.insert(db)

            var itemTag = ItemTag(itemId: itemId, tagId: tagId, createdAt: 1000)
            itemTag.modifiedAt = 1000
            try itemTag.insert(db)
        }

        // Soft delete item
        try service.softDeleteItem(id: itemId)

        // Verify item_tag also deleted
        let itemTag = try dbQueue.read { db in
            try ItemTag
                .filter(Column("item_id") == itemId && Column("tag_id") == tagId)
                .fetchOne(db)
        }

        XCTAssertNotNil(itemTag)
        XCTAssertNotNil(itemTag?.deletedAt, "ItemTag should be deleted")
        XCTAssertEqual(itemTag?.needsPush, 1, "ItemTag should need push")
        XCTAssertNotNil(itemTag?.ckRecordName, "ItemTag should have record name")
    }

    func testSoftDeleteItemCascadesToTimeEntries() throws {
        // Create item and time entry
        let itemId = UUID().uuidString
        let entryId = UUID().uuidString

        try dbQueue.write { db in
            var item = Item(id: itemId)
            item.title = "Test"
            item.createdAt = 1000
            item.modifiedAt = 1000
            try item.insert(db)

            var entry = TimeEntry(id: entryId, itemId: itemId, startedAt: 1000)
            entry.modifiedAt = 1000
            try entry.insert(db)
        }

        // Soft delete item
        try service.softDeleteItem(id: itemId)

        // Verify time entry also deleted
        let entry = try dbQueue.read { db in
            try TimeEntry.fetchOne(db, key: entryId)
        }

        XCTAssertNotNil(entry)
        XCTAssertNotNil(entry?.deletedAt, "TimeEntry should be deleted")
        XCTAssertEqual(entry?.needsPush, 1, "TimeEntry should need push")
        XCTAssertNotNil(entry?.ckRecordName, "TimeEntry should have record name")
    }

    func testSoftDeleteItemsMultiple() throws {
        // Create 3 items
        let ids = [UUID().uuidString, UUID().uuidString, UUID().uuidString]

        try dbQueue.write { db in
            for id in ids {
                var item = Item(id: id)
                item.title = "Item \(id)"
                item.createdAt = 1000
                item.modifiedAt = 1000
                try item.insert(db)
            }
        }

        // Soft delete all
        try service.softDeleteItems(ids: ids)

        // Verify all deleted
        let items = try dbQueue.read { db in
            try Item.fetchAll(db, keys: ids)
        }

        XCTAssertEqual(items.count, 3)
        for item in items {
            XCTAssertNotNil(item.deletedAt)
            XCTAssertEqual(item.needsPush, 1)
        }
    }

    func testSoftDeleteItemDoesNotDeleteAlreadyDeleted() throws {
        // Create and delete item
        let itemId = UUID().uuidString
        let firstDeleteTime = 1000

        try dbQueue.write { db in
            var item = Item(id: itemId)
            item.title = "Test"
            item.createdAt = 1000
            item.modifiedAt = 1000
            item.deletedAt = firstDeleteTime
            try item.insert(db)
        }

        // Try to delete again
        try service.softDeleteItem(id: itemId)

        // Verify deletedAt unchanged
        let item = try dbQueue.read { db in
            try Item.fetchOne(db, key: itemId)
        }

        XCTAssertEqual(item?.deletedAt, firstDeleteTime, "Should not update deletedAt if already set")
    }

    // MARK: - Tag Soft Delete Tests

    func testSoftDeleteTag() throws {
        let tagId = UUID().uuidString

        try dbQueue.write { db in
            var tag = Tag(id: tagId, name: "Test Tag", createdAt: 1000)
            tag.modifiedAt = 1000
            try tag.insert(db)
        }

        try service.softDeleteTag(id: tagId)

        let tag = try dbQueue.read { db in
            try Tag.fetchOne(db, key: tagId)
        }

        XCTAssertNotNil(tag?.deletedAt)
        XCTAssertEqual(tag?.needsPush, 1)
        XCTAssertEqual(tag?.ckRecordName, "Tag_\(tagId)")
    }

    func testSoftDeleteTagCascadesToItemTags() throws {
        // Create tag with 2 item associations
        let tagId = UUID().uuidString
        let item1Id = UUID().uuidString
        let item2Id = UUID().uuidString

        try dbQueue.write { db in
            var tag = Tag(id: tagId, name: "Test", createdAt: 1000)
            tag.modifiedAt = 1000
            try tag.insert(db)

            for itemId in [item1Id, item2Id] {
                var item = Item(id: itemId)
                item.title = "Item"
                item.createdAt = 1000
                item.modifiedAt = 1000
                try item.insert(db)

                var itemTag = ItemTag(itemId: itemId, tagId: tagId, createdAt: 1000)
                itemTag.modifiedAt = 1000
                try itemTag.insert(db)
            }
        }

        try service.softDeleteTag(id: tagId)

        // Verify all item_tags deleted
        let itemTags = try dbQueue.read { db in
            try ItemTag.filter(Column("tag_id") == tagId).fetchAll(db)
        }

        XCTAssertEqual(itemTags.count, 2)
        for itemTag in itemTags {
            XCTAssertNotNil(itemTag.deletedAt)
            XCTAssertEqual(itemTag.needsPush, 1)
        }
    }

    // MARK: - ItemTag Soft Delete Tests

    func testSoftDeleteItemTag() throws {
        let itemId = UUID().uuidString
        let tagId = UUID().uuidString

        try dbQueue.write { db in
            var item = Item(id: itemId)
            item.title = "Item"
            item.createdAt = 1000
            item.modifiedAt = 1000
            try item.insert(db)

            var tag = Tag(id: tagId, name: "Tag", createdAt: 1000)
            tag.modifiedAt = 1000
            try tag.insert(db)

            var itemTag = ItemTag(itemId: itemId, tagId: tagId, createdAt: 1000)
            itemTag.modifiedAt = 1000
            try itemTag.insert(db)
        }

        try service.softDeleteItemTag(itemId: itemId, tagId: tagId)

        let itemTag = try dbQueue.read { db in
            try ItemTag
                .filter(Column("item_id") == itemId && Column("tag_id") == tagId)
                .fetchOne(db)
        }

        XCTAssertNotNil(itemTag?.deletedAt)
        XCTAssertEqual(itemTag?.needsPush, 1)
        XCTAssertEqual(itemTag?.ckRecordName, "ItemTag_\(itemId)_\(tagId)")
    }

    // MARK: - TimeEntry Soft Delete Tests

    func testSoftDeleteTimeEntry() throws {
        let itemId = UUID().uuidString
        let entryId = UUID().uuidString

        try dbQueue.write { db in
            var item = Item(id: itemId)
            item.title = "Item"
            item.createdAt = 1000
            item.modifiedAt = 1000
            try item.insert(db)

            var entry = TimeEntry(id: entryId, itemId: itemId, startedAt: 1000)
            entry.modifiedAt = 1000
            try entry.insert(db)
        }

        try service.softDeleteTimeEntry(id: entryId)

        let entry = try dbQueue.read { db in
            try TimeEntry.fetchOne(db, key: entryId)
        }

        XCTAssertNotNil(entry?.deletedAt)
        XCTAssertEqual(entry?.needsPush, 1)
        XCTAssertEqual(entry?.ckRecordName, "TimeEntry_\(entryId)")
    }

    // MARK: - SavedSearch Soft Delete Tests

    func testSoftDeleteSavedSearch() throws {
        let searchId = UUID().uuidString

        try dbQueue.write { db in
            var search = SavedSearch(id: searchId, name: "Test", sql: "SELECT * FROM items")
            search.createdAt = 1000
            search.modifiedAt = 1000
            try search.insert(db)
        }

        try service.softDeleteSavedSearch(id: searchId)

        let search = try dbQueue.read { db in
            try SavedSearch.fetchOne(db, key: searchId)
        }

        XCTAssertNotNil(search?.deletedAt)
        XCTAssertEqual(search?.needsPush, 1)
        XCTAssertEqual(search?.ckRecordName, "SavedSearch_\(searchId)")
    }

    // MARK: - Tombstone Purge Tests

    func testPurgeSyncedTombstonesOlderThan30Days() throws {
        let now = Int(Date().timeIntervalSince1970)
        let oldTime = now - (31 * 24 * 60 * 60) // 31 days ago
        let recentTime = now - (10 * 24 * 60 * 60) // 10 days ago

        // Create old synced tombstone (should be purged)
        let oldItemId = UUID().uuidString
        try dbQueue.write { db in
            var item = Item(id: oldItemId)
            item.title = "Old"
            item.createdAt = oldTime
            item.modifiedAt = oldTime
            item.deletedAt = oldTime
            item.needsPush = 0 // Synced
            try item.insert(db)
        }

        // Create recent tombstone (should NOT be purged)
        let recentItemId = UUID().uuidString
        try dbQueue.write { db in
            var item = Item(id: recentItemId)
            item.title = "Recent"
            item.createdAt = recentTime
            item.modifiedAt = recentTime
            item.deletedAt = recentTime
            item.needsPush = 0
            try item.insert(db)
        }

        try service.purgeSyncedTombstones()

        // Verify old purged, recent kept
        let items = try dbQueue.read { db in
            try Item.fetchAll(db)
        }

        XCTAssertEqual(items.count, 1, "Should only keep recent tombstone")
        XCTAssertEqual(items.first?.id, recentItemId)
    }

    func testPurgeDoesNotDeleteUnsyncedTombstones() throws {
        let oldTime = Int(Date().timeIntervalSince1970) - (31 * 24 * 60 * 60)

        let itemId = UUID().uuidString
        try dbQueue.write { db in
            var item = Item(id: itemId)
            item.title = "Unsynced"
            item.createdAt = oldTime
            item.modifiedAt = oldTime
            item.deletedAt = oldTime
            item.needsPush = 1 // NOT synced
            try item.insert(db)
        }

        try service.purgeSyncedTombstones()

        let item = try dbQueue.read { db in
            try Item.fetchOne(db, key: itemId)
        }

        XCTAssertNotNil(item, "Should NOT purge unsynced tombstones")
    }

    func testPurgeItemTagsAndTimeEntriesTombstones() throws {
        let oldTime = Int(Date().timeIntervalSince1970) - (31 * 24 * 60 * 60)
        let itemId = UUID().uuidString
        let tagId = UUID().uuidString
        let entryId = UUID().uuidString

        try dbQueue.write { db in
            // Create prerequisites
            var item = Item(id: itemId)
            item.title = "Item"
            item.createdAt = oldTime
            item.modifiedAt = oldTime
            try item.insert(db)

            var tag = Tag(id: tagId, name: "Tag", createdAt: oldTime)
            tag.modifiedAt = oldTime
            try tag.insert(db)

            // Create old synced tombstones
            var itemTag = ItemTag(itemId: itemId, tagId: tagId, createdAt: oldTime)
            itemTag.modifiedAt = oldTime
            itemTag.deletedAt = oldTime
            itemTag.needsPush = 0
            try itemTag.insert(db)

            var entry = TimeEntry(id: entryId, itemId: itemId, startedAt: oldTime)
            entry.modifiedAt = oldTime
            entry.deletedAt = oldTime
            entry.needsPush = 0
            try entry.insert(db)
        }

        try service.purgeSyncedTombstones()

        // Verify purged
        let itemTags = try dbQueue.read { db in
            try ItemTag.fetchAll(db)
        }
        let entries = try dbQueue.read { db in
            try TimeEntry.fetchAll(db)
        }

        XCTAssertEqual(itemTags.count, 0, "Should purge old item_tags")
        XCTAssertEqual(entries.count, 0, "Should purge old time_entries")
    }

    func testPurgeDoesNotDeleteItemsWithChildren() throws {
        let oldTime = Int(Date().timeIntervalSince1970) - (31 * 24 * 60 * 60)
        let parentId = UUID().uuidString
        let childId = UUID().uuidString

        try dbQueue.write { db in
            // Create old deleted parent
            var parent = Item(id: parentId)
            parent.title = "Parent"
            parent.createdAt = oldTime
            parent.modifiedAt = oldTime
            parent.deletedAt = oldTime
            parent.needsPush = 0
            try parent.insert(db)

            // Create child still referencing parent
            var child = Item(id: childId)
            child.title = "Child"
            child.parentId = parentId
            child.createdAt = oldTime
            child.modifiedAt = oldTime
            try child.insert(db)
        }

        try service.purgeSyncedTombstones()

        // Parent should NOT be purged (child still references it)
        let parent = try dbQueue.read { db in
            try Item.fetchOne(db, key: parentId)
        }

        XCTAssertNotNil(parent, "Should not purge items with children")
    }

    func testPurgeDoesNotDeleteTagsWithItemTags() throws {
        let oldTime = Int(Date().timeIntervalSince1970) - (31 * 24 * 60 * 60)
        let tagId = UUID().uuidString
        let itemId = UUID().uuidString

        try dbQueue.write { db in
            // Create old deleted tag
            var tag = Tag(id: tagId, name: "Tag", createdAt: oldTime)
            tag.modifiedAt = oldTime
            tag.deletedAt = oldTime
            tag.needsPush = 0
            try tag.insert(db)

            // Create item
            var item = Item(id: itemId)
            item.title = "Item"
            item.createdAt = oldTime
            item.modifiedAt = oldTime
            try item.insert(db)

            // Create item_tag still referencing the tag
            var itemTag = ItemTag(itemId: itemId, tagId: tagId, createdAt: oldTime)
            itemTag.modifiedAt = oldTime
            try itemTag.insert(db)
        }

        try service.purgeSyncedTombstones()

        // Tag should NOT be purged (item_tag still references it)
        let tag = try dbQueue.read { db in
            try Tag.fetchOne(db, key: tagId)
        }

        XCTAssertNotNil(tag, "Should not purge tags with item_tags")
    }

    func testPurgeSavedSearchesTombstones() throws {
        let oldTime = Int(Date().timeIntervalSince1970) - (31 * 24 * 60 * 60)
        let searchId = UUID().uuidString

        try dbQueue.write { db in
            var search = SavedSearch(id: searchId, name: "Old", sql: "SELECT * FROM items")
            search.createdAt = oldTime
            search.modifiedAt = oldTime
            search.deletedAt = oldTime
            search.needsPush = 0
            try search.insert(db)
        }

        try service.purgeSyncedTombstones()

        let searches = try dbQueue.read { db in
            try SavedSearch.fetchAll(db)
        }

        XCTAssertEqual(searches.count, 0, "Should purge old saved_searches")
    }

    // MARK: - Edge Cases

    func testSoftDeleteNonExistentItem() throws {
        // Should not throw
        XCTAssertNoThrow(try service.softDeleteItem(id: "nonexistent"))
    }

    func testPreservesExistingCkRecordName() throws {
        let itemId = UUID().uuidString
        let customRecordName = "CustomRecord_123"

        try dbQueue.write { db in
            var item = Item(id: itemId)
            item.title = "Test"
            item.ckRecordName = customRecordName
            item.createdAt = 1000
            item.modifiedAt = 1000
            try item.insert(db)
        }

        try service.softDeleteItem(id: itemId)

        let item = try dbQueue.read { db in
            try Item.fetchOne(db, key: itemId)
        }

        XCTAssertEqual(item?.ckRecordName, customRecordName, "Should preserve existing ckRecordName")
    }
}
