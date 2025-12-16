import XCTest
@testable import DirectGTD
import DirectGTDCore
import GRDB

/// Tests for ItemStore query, action, ordering, and tree functions
class ItemStoreQueryTests: XCTestCase {
    var testDB: TestDatabaseWrapper!
    var repository: ItemRepository!
    var settings: UserSettings!
    var store: ItemStore!
    var softDeleteService: SoftDeleteService!

    override func setUp() {
        super.setUp()

        testDB = TestDatabaseWrapper()
        repository = ItemRepository(database: testDB)
        settings = UserSettings()
        store = ItemStore(settings: settings, repository: repository, database: testDB)
        softDeleteService = SoftDeleteService(database: testDB)
        store.loadItems()
    }

    override func tearDown() {
        store = nil
        settings = nil
        repository = nil
        softDeleteService = nil
        testDB = nil
        super.tearDown()
    }

    // MARK: - Helper Functions

    private func createTestItem(title: String, itemType: ItemType = .task, parentId: String? = nil, dueDate: Int? = nil, earliestStartTime: Int? = nil, completedAt: Int? = nil) -> Item {
        var item = Item(title: title, itemType: itemType)
        item.parentId = parentId
        item.dueDate = dueDate
        item.earliestStartTime = earliestStartTime
        item.completedAt = completedAt
        try! repository.create(item)
        store.loadItems()
        return store.items.first { $0.id == item.id }!
    }

    private func createTestTag(name: String) -> Tag {
        return store.createTag(name: name, color: "#FF0000")!
    }

    private func addTagToItem(itemId: String, tag: Tag) {
        store.addTagToItem(itemId: itemId, tag: tag)
    }

    // MARK: - getDashboard() Tests

    func testGetDashboard_EmptyDatabase() {
        let dashboard = store.getDashboard()

        XCTAssertEqual(dashboard.nextTaggedItems.count, 0)
        XCTAssertEqual(dashboard.urgentItems.count, 0)
        XCTAssertEqual(dashboard.overdueItems.count, 0)
    }

    func testGetDashboard_WithNextTaggedItems() {
        let nextTag = createTestTag(name: "Next")
        let item1 = createTestItem(title: "Next Action 1")
        let item2 = createTestItem(title: "Next Action 2")
        let item3 = createTestItem(title: "Not Tagged")

        addTagToItem(itemId: item1.id, tag: nextTag)
        addTagToItem(itemId: item2.id, tag: nextTag)

        let dashboard = store.getDashboard()

        XCTAssertEqual(dashboard.nextTaggedItems.count, 2)
        XCTAssertTrue(dashboard.nextTaggedItems.contains { $0.id == item1.id })
        XCTAssertTrue(dashboard.nextTaggedItems.contains { $0.id == item2.id })
        XCTAssertFalse(dashboard.nextTaggedItems.contains { $0.id == item3.id })
    }

    func testGetDashboard_WithOverdueItems() {
        let now = Int(Date().timeIntervalSince1970)
        let yesterday = now - 86400
        let lastWeek = now - (7 * 86400)

        let overdueItem1 = createTestItem(title: "Overdue 1", dueDate: yesterday)
        let overdueItem2 = createTestItem(title: "Overdue 2", dueDate: lastWeek)
        let futureItem = createTestItem(title: "Future", dueDate: now + 86400)

        let dashboard = store.getDashboard()

        XCTAssertEqual(dashboard.overdueItems.count, 2)
        XCTAssertTrue(dashboard.overdueItems.contains { $0.id == overdueItem1.id })
        XCTAssertTrue(dashboard.overdueItems.contains { $0.id == overdueItem2.id })
        XCTAssertFalse(dashboard.overdueItems.contains { $0.id == futureItem.id })

        // Verify sorted by due date (oldest first)
        XCTAssertEqual(dashboard.overdueItems[0].id, overdueItem2.id)
        XCTAssertEqual(dashboard.overdueItems[1].id, overdueItem1.id)
    }

    func testGetDashboard_WithUrgentItems() {
        let now = Int(Date().timeIntervalSince1970)
        let in6Hours = now + (6 * 3600)
        let in12Hours = now + (12 * 3600)
        let tomorrow = now + (26 * 3600) // Beyond 24 hours

        let urgentItem1 = createTestItem(title: "Urgent 1", dueDate: in6Hours)
        let urgentItem2 = createTestItem(title: "Urgent 2", dueDate: in12Hours)
        let notUrgent = createTestItem(title: "Not Urgent", dueDate: tomorrow)

        let dashboard = store.getDashboard()

        XCTAssertEqual(dashboard.urgentItems.count, 2)
        XCTAssertTrue(dashboard.urgentItems.contains { $0.id == urgentItem1.id })
        XCTAssertTrue(dashboard.urgentItems.contains { $0.id == urgentItem2.id })
        XCTAssertFalse(dashboard.urgentItems.contains { $0.id == notUrgent.id })
    }

    func testGetDashboard_ExcludesCompletedItems() {
        let now = Int(Date().timeIntervalSince1970)
        let nextTag = createTestTag(name: "next")

        let completedOverdue = createTestItem(title: "Completed Overdue", dueDate: now - 86400, completedAt: now)
        let completedUrgent = createTestItem(title: "Completed Urgent", dueDate: now + 3600, completedAt: now)
        let completedNext = createTestItem(title: "Completed Next", completedAt: now)
        addTagToItem(itemId: completedNext.id, tag: nextTag)

        let dashboard = store.getDashboard()

        XCTAssertEqual(dashboard.overdueItems.count, 0)
        XCTAssertEqual(dashboard.urgentItems.count, 0)
        XCTAssertEqual(dashboard.nextTaggedItems.count, 0)
    }

    func testGetDashboard_OnlyIncludesTasks() {
        let now = Int(Date().timeIntervalSince1970)
        let nextTag = createTestTag(name: "Next")

        let taskItem = createTestItem(title: "Task", itemType: .task, dueDate: now - 86400)
        let noteItem = createTestItem(title: "Note", itemType: .note, dueDate: now - 86400)
        let projectItem = createTestItem(title: "Project", itemType: .project, dueDate: now - 86400)

        addTagToItem(itemId: noteItem.id, tag: nextTag)

        let dashboard = store.getDashboard()

        XCTAssertEqual(dashboard.overdueItems.count, 1)
        XCTAssertEqual(dashboard.overdueItems[0].id, taskItem.id)
    }

    // MARK: - getOverdueItems() Tests

    func testGetOverdueItems_ReturnsOnlyOverdueItems() {
        let now = Int(Date().timeIntervalSince1970)
        let yesterday = now - 86400
        let tomorrow = now + 86400

        let overdueItem = createTestItem(title: "Overdue", dueDate: yesterday)
        let futureItem = createTestItem(title: "Future", dueDate: tomorrow)
        let noDueDate = createTestItem(title: "No Due Date")

        let overdue = store.getOverdueItems()

        XCTAssertEqual(overdue.count, 1)
        XCTAssertEqual(overdue[0].id, overdueItem.id)
    }

    func testGetOverdueItems_SortsByDueDate() {
        let now = Int(Date().timeIntervalSince1970)
        let item1 = createTestItem(title: "Recent", dueDate: now - 86400)
        let item2 = createTestItem(title: "Old", dueDate: now - (7 * 86400))
        let item3 = createTestItem(title: "Very Old", dueDate: now - (30 * 86400))

        let overdue = store.getOverdueItems()

        XCTAssertEqual(overdue.count, 3)
        XCTAssertEqual(overdue[0].id, item3.id) // Oldest first
        XCTAssertEqual(overdue[1].id, item2.id)
        XCTAssertEqual(overdue[2].id, item1.id)
    }

    func testGetOverdueItems_ExcludesCompleted() {
        let now = Int(Date().timeIntervalSince1970)
        let yesterday = now - 86400

        let overdueItem = createTestItem(title: "Overdue", dueDate: yesterday)
        let completedOverdue = createTestItem(title: "Completed", dueDate: yesterday, completedAt: now)

        let overdue = store.getOverdueItems()

        XCTAssertEqual(overdue.count, 1)
        XCTAssertEqual(overdue[0].id, overdueItem.id)
    }

    // MARK: - getItemsDueToday() Tests

    func testGetItemsDueToday_ReturnsTodayItems() {
        let calendar = Calendar.current
        let startOfDay = Int(calendar.startOfDay(for: Date()).timeIntervalSince1970)
        let noon = startOfDay + (12 * 3600)
        let endOfDay = startOfDay + 86399

        let todayMorning = createTestItem(title: "Today Morning", dueDate: startOfDay + 3600)
        let todayNoon = createTestItem(title: "Today Noon", dueDate: noon)
        let todayEvening = createTestItem(title: "Today Evening", dueDate: endOfDay)
        let yesterday = createTestItem(title: "Yesterday", dueDate: startOfDay - 86400)
        let tomorrow = createTestItem(title: "Tomorrow", dueDate: startOfDay + 86400)

        let dueToday = store.getItemsDueToday()

        XCTAssertEqual(dueToday.count, 3)
        XCTAssertTrue(dueToday.contains { $0.id == todayMorning.id })
        XCTAssertTrue(dueToday.contains { $0.id == todayNoon.id })
        XCTAssertTrue(dueToday.contains { $0.id == todayEvening.id })
    }

    // MARK: - getItemsDueTomorrow() Tests

    func testGetItemsDueTomorrow_ReturnsTomorrowItems() {
        let calendar = Calendar.current
        let startOfToday = Int(calendar.startOfDay(for: Date()).timeIntervalSince1970)
        let startOfTomorrow = startOfToday + 86400
        let tomorrowNoon = startOfTomorrow + (12 * 3600)

        let tomorrowItem = createTestItem(title: "Tomorrow", dueDate: tomorrowNoon)
        let todayItem = createTestItem(title: "Today", dueDate: startOfToday + 3600)
        let dayAfterTomorrow = createTestItem(title: "Day After", dueDate: startOfTomorrow + 86400)

        let dueTomorrow = store.getItemsDueTomorrow()

        XCTAssertEqual(dueTomorrow.count, 1)
        XCTAssertEqual(dueTomorrow[0].id, tomorrowItem.id)
    }

    // MARK: - getItemsDueThisWeek() Tests

    func testGetItemsDueThisWeek_ReturnsWeekItems() {
        let calendar = Calendar.current
        let today = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        let startOfWeekTimestamp = Int(startOfWeek.timeIntervalSince1970)
        let endOfWeekTimestamp = startOfWeekTimestamp + (7 * 86400)

        let thisWeekItem = createTestItem(title: "This Week", dueDate: startOfWeekTimestamp + (3 * 86400))
        let nextWeekItem = createTestItem(title: "Next Week", dueDate: endOfWeekTimestamp + 86400)
        let lastWeekItem = createTestItem(title: "Last Week", dueDate: startOfWeekTimestamp - 86400)

        let dueThisWeek = store.getItemsDueThisWeek()

        XCTAssertTrue(dueThisWeek.contains { $0.id == thisWeekItem.id })
        XCTAssertFalse(dueThisWeek.contains { $0.id == nextWeekItem.id })
        XCTAssertFalse(dueThisWeek.contains { $0.id == lastWeekItem.id })
    }

    // MARK: - getAvailableTasks() Tests

    func testGetAvailableTasks_ReturnsActionableItems() {
        let now = Int(Date().timeIntervalSince1970)

        let availableItem = createTestItem(title: "Available")
        let completedItem = createTestItem(title: "Completed", completedAt: now)
        let deferredItem = createTestItem(title: "Deferred", earliestStartTime: now + 86400)

        let available = store.getAvailableTasks()

        XCTAssertTrue(available.contains { $0.id == availableItem.id })
        XCTAssertFalse(available.contains { $0.id == completedItem.id })
        XCTAssertFalse(available.contains { $0.id == deferredItem.id })
    }

    func testGetAvailableTasks_IncludesPastEarliestStartTime() {
        let now = Int(Date().timeIntervalSince1970)
        let yesterday = now - 86400

        let pastStartTime = createTestItem(title: "Past Start", earliestStartTime: yesterday)

        let available = store.getAvailableTasks()

        XCTAssertTrue(available.contains { $0.id == pastStartTime.id })
    }

    // MARK: - getDeferredTasks() Tests

    func testGetDeferredTasks_ReturnsFutureDeferredItems() {
        let now = Int(Date().timeIntervalSince1970)
        let tomorrow = now + 86400
        let nextWeek = now + (7 * 86400)

        let deferredItem1 = createTestItem(title: "Deferred 1", earliestStartTime: tomorrow)
        let deferredItem2 = createTestItem(title: "Deferred 2", earliestStartTime: nextWeek)
        let availableItem = createTestItem(title: "Available")
        let pastDeferredItem = createTestItem(title: "Past Deferred", earliestStartTime: now - 86400)

        let deferred = store.getDeferredTasks()

        XCTAssertEqual(deferred.count, 2)
        XCTAssertTrue(deferred.contains { $0.id == deferredItem1.id })
        XCTAssertTrue(deferred.contains { $0.id == deferredItem2.id })

        // Verify sorted by earliestStartTime (soonest first)
        XCTAssertEqual(deferred[0].id, deferredItem1.id)
        XCTAssertEqual(deferred[1].id, deferredItem2.id)
    }

    // MARK: - getCompletedTasks() Tests

    func testGetCompletedTasks_ReturnsAllCompleted() {
        let now = Int(Date().timeIntervalSince1970)

        let completed1 = createTestItem(title: "Completed 1", completedAt: now - 86400)
        let completed2 = createTestItem(title: "Completed 2", completedAt: now)
        let incomplete = createTestItem(title: "Incomplete")

        let completed = store.getCompletedTasks()

        XCTAssertEqual(completed.count, 2)
        XCTAssertTrue(completed.contains { $0.id == completed1.id })
        XCTAssertTrue(completed.contains { $0.id == completed2.id })
    }

    func testGetCompletedTasks_FiltersBySinceDate() {
        let now = Int(Date().timeIntervalSince1970)
        let yesterday = now - 86400
        let lastWeek = now - (7 * 86400)

        let recentCompleted = createTestItem(title: "Recent", completedAt: now)
        let oldCompleted = createTestItem(title: "Old", completedAt: lastWeek)

        let completed = store.getCompletedTasks(since: yesterday)

        XCTAssertEqual(completed.count, 1)
        XCTAssertEqual(completed[0].id, recentCompleted.id)
    }

    func testGetCompletedTasks_SortsByCompletedAtDescending() {
        let now = Int(Date().timeIntervalSince1970)

        let item1 = createTestItem(title: "Item 1", completedAt: now - (2 * 86400))
        let item2 = createTestItem(title: "Item 2", completedAt: now - 86400)
        let item3 = createTestItem(title: "Item 3", completedAt: now)

        let completed = store.getCompletedTasks()

        XCTAssertEqual(completed[0].id, item3.id) // Most recent first
        XCTAssertEqual(completed[1].id, item2.id)
        XCTAssertEqual(completed[2].id, item1.id)
    }

    // MARK: - getOldestTasks() Tests

    func testGetOldestTasks_ReturnsOldestIncomplete() {
        let now = Int(Date().timeIntervalSince1970)

        let old1 = createTestItem(title: "Old 1")
        Thread.sleep(forTimeInterval: 0.01)
        let old2 = createTestItem(title: "Old 2")
        Thread.sleep(forTimeInterval: 0.01)
        let recent = createTestItem(title: "Recent")
        let completed = createTestItem(title: "Completed", completedAt: now)

        let oldest = store.getOldestTasks(limit: 2)

        XCTAssertEqual(oldest.count, 2)
        XCTAssertEqual(oldest[0].id, old1.id)
        XCTAssertEqual(oldest[1].id, old2.id)
    }

    func testGetOldestTasks_RespectsLimit() {
        for i in 1...30 {
            _ = createTestItem(title: "Item \(i)")
            Thread.sleep(forTimeInterval: 0.001)
        }

        let oldest = store.getOldestTasks(limit: 10)

        XCTAssertEqual(oldest.count, 10)
    }

    // MARK: - getStuckProjects() Tests

    func testGetStuckProjects_FindsProjectsWithoutNextTag() {
        let nextTag = createTestTag(name: "Next")

        let project1 = createTestItem(title: "Stuck Project", itemType: .project)
        let project2 = createTestItem(title: "Active Project", itemType: .project)

        let task1 = createTestItem(title: "Next Task", itemType: .task, parentId: project2.id)
        addTagToItem(itemId: task1.id, tag: nextTag)

        let stuckProjects = store.getStuckProjects()

        XCTAssertTrue(stuckProjects.contains { $0.id == project1.id })
        XCTAssertFalse(stuckProjects.contains { $0.id == project2.id })
    }

    func testGetStuckProjects_ExcludesOnHoldProjects() {
        let onHoldTag = createTestTag(name: "on-hold")

        let stuckProject = createTestItem(title: "Stuck Project", itemType: .project)
        let onHoldProject = createTestItem(title: "On Hold Project", itemType: .project)
        addTagToItem(itemId: onHoldProject.id, tag: onHoldTag)

        let stuckProjects = store.getStuckProjects()

        XCTAssertTrue(stuckProjects.contains { $0.id == stuckProject.id })
        XCTAssertFalse(stuckProjects.contains { $0.id == onHoldProject.id })
    }

    // MARK: - getItemsByTagNames() Tests

    func testGetItemsByTagNames_FindsItemsWithAllTags() {
        let tag1 = createTestTag(name: "urgent")
        let tag2 = createTestTag(name: "home")

        let item1 = createTestItem(title: "Both Tags")
        let item2 = createTestItem(title: "One Tag")
        let item3 = createTestItem(title: "No Tags")

        addTagToItem(itemId: item1.id, tag: tag1)
        addTagToItem(itemId: item1.id, tag: tag2)
        addTagToItem(itemId: item2.id, tag: tag1)

        let items = store.getItemsByTagNames(["urgent", "home"])

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].id, item1.id)
    }

    func testGetItemsByTagNames_CaseInsensitive() {
        let tag = createTestTag(name: "Urgent")
        let item = createTestItem(title: "Tagged")
        addTagToItem(itemId: item.id, tag: tag)

        let items = store.getItemsByTagNames(["urgent"])

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].id, item.id)
    }

    // MARK: - getDescendants() Tests

    func testGetDescendants_ReturnsAllChildren() {
        let parent = createTestItem(title: "Parent")
        let child1 = createTestItem(title: "Child 1", parentId: parent.id)
        let child2 = createTestItem(title: "Child 2", parentId: parent.id)
        let grandchild = createTestItem(title: "Grandchild", parentId: child1.id)
        let unrelated = createTestItem(title: "Unrelated")

        let descendants = store.getDescendants(of: parent.id)

        XCTAssertEqual(descendants.count, 3)
        XCTAssertTrue(descendants.contains { $0.id == child1.id })
        XCTAssertTrue(descendants.contains { $0.id == child2.id })
        XCTAssertTrue(descendants.contains { $0.id == grandchild.id })
        XCTAssertFalse(descendants.contains { $0.id == unrelated.id })
    }

    func testGetDescendants_EmptyForLeafNode() {
        let leaf = createTestItem(title: "Leaf")

        let descendants = store.getDescendants(of: leaf.id)

        XCTAssertEqual(descendants.count, 0)
    }

    // MARK: - archiveItem() Tests

    func testArchiveItem_MovesToArchiveFolder() {
        // Create archive folder setting
        let archiveFolder = createTestItem(title: "Archive", itemType: .folder)
        try! repository.setSetting(key: "archive_folder_id", value: archiveFolder.id)

        let item = createTestItem(title: "To Archive")

        let success = store.archiveItem(id: item.id)

        XCTAssertTrue(success)

        // Verify item moved to archive
        store.loadItems()
        let archivedItem = store.items.first { $0.id == item.id }
        XCTAssertEqual(archivedItem?.parentId, archiveFolder.id)
    }

    func testArchiveItem_CreatesArchiveFolderIfNeeded() {
        let item = createTestItem(title: "To Archive")

        let success = store.archiveItem(id: item.id)

        XCTAssertTrue(success)

        // Verify Archive folder was created
        store.loadItems()
        let archiveFolder = store.items.first { $0.title == "Archive" && $0.itemType == .folder }
        XCTAssertNotNil(archiveFolder)
    }

    func testArchiveItem_ReturnsFalseForNonExistentItem() {
        let success = store.archiveItem(id: "non-existent-id")

        XCTAssertFalse(success)
    }

    // MARK: - completeMultiple() Tests

    func testCompleteMultiple_CompletesAllTasks() {
        let task1 = createTestItem(title: "Task 1")
        let task2 = createTestItem(title: "Task 2")
        let task3 = createTestItem(title: "Task 3")

        let count = store.completeMultiple(ids: [task1.id, task2.id, task3.id])

        XCTAssertEqual(count, 3)

        store.loadItems()
        XCTAssertNotNil(store.items.first { $0.id == task1.id }?.completedAt)
        XCTAssertNotNil(store.items.first { $0.id == task2.id }?.completedAt)
        XCTAssertNotNil(store.items.first { $0.id == task3.id }?.completedAt)
    }

    func testCompleteMultiple_IgnoresInvalidIds() {
        let task = createTestItem(title: "Task")

        let count = store.completeMultiple(ids: [task.id, "invalid-id-1", "invalid-id-2"])

        XCTAssertEqual(count, 1)
    }

    func testCompleteMultiple_HandlesEmptyArray() {
        let count = store.completeMultiple(ids: [])

        XCTAssertEqual(count, 0)
    }

    // MARK: - instantiateTemplate() Tests

    func testInstantiateTemplate_CopiesTemplateStructure() {
        let template = createTestItem(title: "Template", itemType: .template)
        let child1 = createTestItem(title: "Child 1", itemType: .task, parentId: template.id)
        let child2 = createTestItem(title: "Child 2", itemType: .task, parentId: template.id)

        let instance = store.instantiateTemplate(templateId: template.id, parentId: nil)

        XCTAssertNotNil(instance)
        XCTAssertNotEqual(instance?.id, template.id) // New ID

        // Verify children were copied
        store.loadItems()
        let instanceChildren = store.items.filter { $0.parentId == instance?.id }
        XCTAssertEqual(instanceChildren.count, 2)
    }

    func testInstantiateTemplate_CopiesTags() {
        let tag = createTestTag(name: "template-tag")
        let template = createTestItem(title: "Template", itemType: .template)
        addTagToItem(itemId: template.id, tag: tag)

        let instance = store.instantiateTemplate(templateId: template.id)

        XCTAssertNotNil(instance)

        // Verify tags copied
        let instanceTags = store.getTagsForItem(itemId: instance!.id)
        XCTAssertEqual(instanceTags.count, 1)
        XCTAssertEqual(instanceTags[0].id, tag.id)
    }

    func testInstantiateTemplate_ReturnsNilForInvalidTemplate() {
        let instance = store.instantiateTemplate(templateId: "invalid-id")

        XCTAssertNil(instance)
    }

    // MARK: - emptyTrash() Tests

    func testEmptyTrash_DeletesSoftDeletedItems() {
        let now = Int(Date().timeIntervalSince1970)

        // Soft delete items
        let item1 = createTestItem(title: "Deleted 1")
        let item2 = createTestItem(title: "Deleted 2")
        try! softDeleteService.softDeleteItem(id: item1.id)
        try! softDeleteService.softDeleteItem(id: item2.id)

        store.loadItems()
        let beforeCount = store.items.count

        let deletedCount = store.emptyTrash()

        XCTAssertEqual(deletedCount, 2)

        // Verify items permanently deleted
        store.loadItems()
        XCTAssertFalse(store.items.contains { $0.id == item1.id })
        XCTAssertFalse(store.items.contains { $0.id == item2.id })
    }

    func testEmptyTrash_RespectsKeepSinceDate() {
        let now = Int(Date().timeIntervalSince1970)
        let oldDeletionTime = now - 120  // 2 minutes ago

        let item1 = createTestItem(title: "Old Deleted")
        let item2 = createTestItem(title: "Recent Deleted")

        // Soft delete both items
        try! softDeleteService.softDeleteItem(id: item1.id)
        try! softDeleteService.softDeleteItem(id: item2.id)

        // Manually set item1's deleted_at to simulate an old deletion
        try! testDB.getQueue()!.write { db in
            try db.execute(
                sql: "UPDATE items SET deleted_at = ? WHERE id = ?",
                arguments: [oldDeletionTime, item1.id]
            )
        }

        // keepSince = now - 60 means keep items deleted after (now - 60)
        // item1 was deleted at (now - 120), which is before (now - 60), so it should be deleted
        // item2 was deleted at ~now, which is after (now - 60), so it should be kept
        let deletedCount = store.emptyTrash(keepSince: now - 60)

        // Should only delete item1 (deleted before keepSince)
        XCTAssertEqual(deletedCount, 1)
    }

    // MARK: - swapItemOrder() Tests

    func testSwapItemOrder_SwapsSortOrder() {
        let parent = createTestItem(title: "Parent")
        let child1 = createTestItem(title: "Child 1", parentId: parent.id)
        let child2 = createTestItem(title: "Child 2", parentId: parent.id)

        let order1Before = store.items.first { $0.id == child1.id }?.sortOrder
        let order2Before = store.items.first { $0.id == child2.id }?.sortOrder

        let success = store.swapItemOrder(id1: child1.id, id2: child2.id)

        XCTAssertTrue(success)

        store.loadItems()
        let order1After = store.items.first { $0.id == child1.id }?.sortOrder
        let order2After = store.items.first { $0.id == child2.id }?.sortOrder

        XCTAssertEqual(order1After, order2Before)
        XCTAssertEqual(order2After, order1Before)
    }

    func testSwapItemOrder_ReturnsFalseForDifferentParents() {
        let parent1 = createTestItem(title: "Parent 1")
        let parent2 = createTestItem(title: "Parent 2")
        let child1 = createTestItem(title: "Child 1", parentId: parent1.id)
        let child2 = createTestItem(title: "Child 2", parentId: parent2.id)

        let success = store.swapItemOrder(id1: child1.id, id2: child2.id)

        XCTAssertFalse(success)
    }

    // MARK: - moveToPosition() Tests

    func testMoveToPosition_MovesItemToPosition() {
        let parent = createTestItem(title: "Parent")
        let child1 = createTestItem(title: "Child 1", parentId: parent.id)
        let child2 = createTestItem(title: "Child 2", parentId: parent.id)
        let child3 = createTestItem(title: "Child 3", parentId: parent.id)

        let success = store.moveToPosition(id: child3.id, position: 0)

        XCTAssertTrue(success)

        store.loadItems()
        let children = store.items.filter { $0.parentId == parent.id }.sorted { $0.sortOrder < $1.sortOrder }

        XCTAssertEqual(children[0].id, child3.id)
        XCTAssertEqual(children[1].id, child1.id)
        XCTAssertEqual(children[2].id, child2.id)
    }

    func testMoveToPosition_ReturnsFalseForInvalidItem() {
        let success = store.moveToPosition(id: "invalid-id", position: 0)

        XCTAssertFalse(success)
    }

    // MARK: - reorderChildren() Tests

    func testReorderChildren_ReordersAllChildren() {
        let parent = createTestItem(title: "Parent")
        let child1 = createTestItem(title: "Child 1", parentId: parent.id)
        let child2 = createTestItem(title: "Child 2", parentId: parent.id)
        let child3 = createTestItem(title: "Child 3", parentId: parent.id)

        let newOrder = [child3.id, child1.id, child2.id]
        let success = store.reorderChildren(parentId: parent.id, orderedIds: newOrder)

        XCTAssertTrue(success)

        store.loadItems()
        let children = store.items.filter { $0.parentId == parent.id }.sorted { $0.sortOrder < $1.sortOrder }

        XCTAssertEqual(children[0].id, child3.id)
        XCTAssertEqual(children[1].id, child1.id)
        XCTAssertEqual(children[2].id, child2.id)
    }

    func testReorderChildren_ReturnsFalseForMismatchedChildren() {
        let parent = createTestItem(title: "Parent")
        let child1 = createTestItem(title: "Child 1", parentId: parent.id)
        let child2 = createTestItem(title: "Child 2", parentId: parent.id)

        // Missing child2 in ordered list
        let success = store.reorderChildren(parentId: parent.id, orderedIds: [child1.id])

        XCTAssertFalse(success)
    }

    // MARK: - getTree() Tests

    func testGetTree_BuildsFullTree() {
        let root1 = createTestItem(title: "Root 1")
        let root2 = createTestItem(title: "Root 2")
        let child1 = createTestItem(title: "Child 1", parentId: root1.id)
        let grandchild = createTestItem(title: "Grandchild", parentId: child1.id)

        let tree = store.getTree()

        XCTAssertEqual(tree.count, 2) // Two root nodes

        let root1Node = tree.first { $0.item.id == root1.id }
        XCTAssertNotNil(root1Node)
        XCTAssertEqual(root1Node?.children.count, 1)
        XCTAssertEqual(root1Node?.children[0].children.count, 1)
    }

    func testGetTree_RespectsMaxDepth() {
        let root = createTestItem(title: "Root")
        let level1 = createTestItem(title: "Level 1", parentId: root.id)
        let level2 = createTestItem(title: "Level 2", parentId: level1.id)
        let level3 = createTestItem(title: "Level 3", parentId: level2.id)

        let tree = store.getTree(maxDepth: 2)

        let rootNode = tree[0]
        XCTAssertEqual(rootNode.children.count, 1) // Level 1
        XCTAssertEqual(rootNode.children[0].children.count, 1) // Level 2
        XCTAssertEqual(rootNode.children[0].children[0].children.count, 0) // Depth limit
    }

    func testGetTree_WithSpecificRoot() {
        let root = createTestItem(title: "Root")
        let child = createTestItem(title: "Child", parentId: root.id)
        let sibling = createTestItem(title: "Sibling")

        let tree = store.getTree(rootId: root.id)

        XCTAssertEqual(tree.count, 1)
        XCTAssertEqual(tree[0].item.id, root.id)
        XCTAssertEqual(tree[0].children.count, 1)
    }

    func testGetTree_IncludesTagsForEachNode() {
        let tag = createTestTag(name: "test-tag")
        let item = createTestItem(title: "Tagged Item")
        addTagToItem(itemId: item.id, tag: tag)

        let tree = store.getTree()

        let node = tree.first { $0.item.id == item.id }
        XCTAssertNotNil(node)
        XCTAssertEqual(node?.tags.count, 1)
        XCTAssertEqual(node?.tags[0].id, tag.id)
    }
}
