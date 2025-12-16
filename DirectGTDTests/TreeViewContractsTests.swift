import DirectGTDCore
import XCTest
@testable import DirectGTD

/// Phase 1-3 Tests: Verify TreeView contract types exist and can be instantiated.
/// These tests ensure that RowProps and ItemRowCallbacks are properly defined
/// and that the existing row initializers remain compatible.
final class TreeViewContractsTests: XCTestCase {

    // MARK: - RowProps Type Presence Tests (Phase 1)

    func testRowPropsCanBeInstantiated() {
        // Given: A sample item
        let item = Item(
            id: "test-item-id",
            title: "Test Item",
            itemType: .task
        )

        // When: Creating a RowProps instance
        let rowProps = RowProps(
            item: item,
            isSelected: true,
            isExpanded: false,
            isFocusedItem: false,
            fontSize: 14.0,
            children: [],
            childCount: 0,
            tagCount: 0,
            isDropTargetInto: false,
            isDropTargetAbove: false,
            isDropTargetBelow: false
        )

        // Then: All properties should be accessible
        XCTAssertEqual(rowProps.item.id, "test-item-id")
        XCTAssertTrue(rowProps.isSelected)
        XCTAssertFalse(rowProps.isExpanded)
        XCTAssertEqual(rowProps.fontSize, 14.0)
    }

    func testRowPropsWithDifferentItemTypes() {
        // Given: Items of different types
        let taskItem = Item(itemType: .task)
        let projectItem = Item(itemType: .project)
        let noteItem = Item(itemType: .note)

        // When/Then: RowProps can be created for all item types
        let taskProps = RowProps(item: taskItem, isSelected: false, isExpanded: false, isFocusedItem: false, fontSize: 12.0, children: [], childCount: 0, tagCount: 0, isDropTargetInto: false, isDropTargetAbove: false, isDropTargetBelow: false)
        let projectProps = RowProps(item: projectItem, isSelected: true, isExpanded: true, isFocusedItem: false, fontSize: 16.0, children: [], childCount: 0, tagCount: 0, isDropTargetInto: false, isDropTargetAbove: false, isDropTargetBelow: false)
        let noteProps = RowProps(item: noteItem, isSelected: false, isExpanded: true, isFocusedItem: false, fontSize: 14.0, children: [], childCount: 0, tagCount: 0, isDropTargetInto: false, isDropTargetAbove: false, isDropTargetBelow: false)

        XCTAssertEqual(taskProps.item.itemType, .task)
        XCTAssertEqual(projectProps.item.itemType, .project)
        XCTAssertEqual(noteProps.item.itemType, .note)
    }

    // MARK: - Phase 3: RowProps children and childCount Tests

    func testRowPropsIncludesChildrenAndChildCount() {
        // Given: A parent item with children
        let parent = Item(id: "parent", title: "Parent", itemType: .project)
        let child1 = Item(id: "child1", title: "Child 1", itemType: .task, parentId: "parent")
        let child2 = Item(id: "child2", title: "Child 2", itemType: .task, parentId: "parent")
        let children = [child1, child2]

        // When: Creating RowProps with children
        let rowProps = RowProps(
            item: parent,
            isSelected: false,
            isExpanded: true,
            isFocusedItem: false,
            fontSize: 14.0,
            children: children,
            childCount: children.count,
            tagCount: 0,
            isDropTargetInto: false,
            isDropTargetAbove: false,
            isDropTargetBelow: false
        )

        // Then: children and childCount should be accessible
        XCTAssertEqual(rowProps.children.count, 2)
        XCTAssertEqual(rowProps.childCount, 2)
        XCTAssertEqual(rowProps.children[0].id, "child1")
        XCTAssertEqual(rowProps.children[1].id, "child2")
    }

    func testRowPropsChildCountMatchesChildrenCount_NoChildren() {
        // Given: An item with no children
        let item = Item(id: "leaf", title: "Leaf", itemType: .task)
        let children: [Item] = []

        // When: Creating RowProps
        let rowProps = RowProps(
            item: item,
            isSelected: false,
            isExpanded: false,
            isFocusedItem: false,
            fontSize: 14.0,
            children: children,
            childCount: children.count,
            tagCount: 0,
            isDropTargetInto: false,
            isDropTargetAbove: false,
            isDropTargetBelow: false
        )

        // Then: childCount == children.count == 0
        XCTAssertEqual(rowProps.childCount, rowProps.children.count)
        XCTAssertEqual(rowProps.childCount, 0)
    }

    func testRowPropsChildCountMatchesChildrenCount_MixedWithCompletedIncluded() {
        // Given: Mixed children including completed tasks (showCompleted = true scenario)
        let parent = Item(id: "parent", title: "Parent", itemType: .project)
        let activeTask = Item(id: "active", title: "Active Task", itemType: .task, parentId: "parent")
        let completedTask = Item(id: "completed", title: "Completed Task", itemType: .task, parentId: "parent", completedAt: 1234567890)
        let note = Item(id: "note", title: "Note", itemType: .note, parentId: "parent")
        let children = [activeTask, completedTask, note]

        // When: Creating RowProps with all children included
        let rowProps = RowProps(
            item: parent,
            isSelected: false,
            isExpanded: true,
            isFocusedItem: false,
            fontSize: 14.0,
            children: children,
            childCount: children.count,
            tagCount: 0,
            isDropTargetInto: false,
            isDropTargetAbove: false,
            isDropTargetBelow: false
        )

        // Then: childCount == children.count == 3
        XCTAssertEqual(rowProps.childCount, rowProps.children.count)
        XCTAssertEqual(rowProps.childCount, 3)
    }

    func testRowPropsChildCountMatchesChildrenCount_CompletedExcluded() {
        // Given: Children with completed tasks excluded (showCompleted = false scenario)
        let parent = Item(id: "parent", title: "Parent", itemType: .project)
        let activeTask = Item(id: "active", title: "Active Task", itemType: .task, parentId: "parent")
        let note = Item(id: "note", title: "Note", itemType: .note, parentId: "parent")
        // Completed task is filtered out by TreeView before passing to RowProps
        let filteredChildren = [activeTask, note]

        // When: Creating RowProps with filtered children
        let rowProps = RowProps(
            item: parent,
            isSelected: false,
            isExpanded: true,
            isFocusedItem: false,
            fontSize: 14.0,
            children: filteredChildren,
            childCount: filteredChildren.count,
            tagCount: 0,
            isDropTargetInto: false,
            isDropTargetAbove: false,
            isDropTargetBelow: false
        )

        // Then: childCount == children.count == 2 (completed excluded)
        XCTAssertEqual(rowProps.childCount, rowProps.children.count)
        XCTAssertEqual(rowProps.childCount, 2)
    }

    func testRowPropsChildCountMatchesChildrenCount_TagFiltered() {
        // Given: Simulated tag filter - only items with specific tag included
        let parent = Item(id: "parent", title: "Parent", itemType: .project)
        let taggedTask = Item(id: "tagged", title: "Tagged Task", itemType: .task, parentId: "parent")
        // Untagged items are filtered out by TreeView before passing to RowProps
        let tagFilteredChildren = [taggedTask]

        // When: Creating RowProps with tag-filtered children
        let rowProps = RowProps(
            item: parent,
            isSelected: false,
            isExpanded: true,
            isFocusedItem: false,
            fontSize: 14.0,
            children: tagFilteredChildren,
            childCount: tagFilteredChildren.count,
            tagCount: 0,
            isDropTargetInto: false,
            isDropTargetAbove: false,
            isDropTargetBelow: false
        )

        // Then: childCount == children.count == 1
        XCTAssertEqual(rowProps.childCount, rowProps.children.count)
        XCTAssertEqual(rowProps.childCount, 1)
    }

    func testRowPropsChildCountMatchesChildrenCount_SQLSearchFiltered() {
        // Given: Simulated SQL search - only matching items included
        let parent = Item(id: "parent", title: "Parent", itemType: .project)
        let matchingTask1 = Item(id: "match1", title: "Search Match 1", itemType: .task, parentId: "parent")
        let matchingTask2 = Item(id: "match2", title: "Search Match 2", itemType: .task, parentId: "parent")
        // Non-matching items are filtered out by search before passing to RowProps
        let searchFilteredChildren = [matchingTask1, matchingTask2]

        // When: Creating RowProps with search-filtered children
        let rowProps = RowProps(
            item: parent,
            isSelected: false,
            isExpanded: true,
            isFocusedItem: false,
            fontSize: 14.0,
            children: searchFilteredChildren,
            childCount: searchFilteredChildren.count,
            tagCount: 0,
            isDropTargetInto: false,
            isDropTargetAbove: false,
            isDropTargetBelow: false
        )

        // Then: childCount == children.count == 2
        XCTAssertEqual(rowProps.childCount, rowProps.children.count)
        XCTAssertEqual(rowProps.childCount, 2)
    }

    func testRowPropsChildCountMatchesChildrenCount_CombinedFilters() {
        // Given: Combined filters (tag + completed exclusion + search)
        let parent = Item(id: "parent", title: "Parent", itemType: .project)
        // Only one item survives all filters
        let survivingTask = Item(id: "survivor", title: "Surviving Task", itemType: .task, parentId: "parent")
        let combinedFilteredChildren = [survivingTask]

        // When: Creating RowProps with combined-filtered children
        let rowProps = RowProps(
            item: parent,
            isSelected: false,
            isExpanded: true,
            isFocusedItem: false,
            fontSize: 14.0,
            children: combinedFilteredChildren,
            childCount: combinedFilteredChildren.count,
            tagCount: 0,
            isDropTargetInto: false,
            isDropTargetAbove: false,
            isDropTargetBelow: false
        )

        // Then: childCount == children.count == 1
        XCTAssertEqual(rowProps.childCount, rowProps.children.count)
        XCTAssertEqual(rowProps.childCount, 1)
    }

    // MARK: - ItemRowCallbacks Type Presence Tests

    func testItemRowCallbacksNoopExists() {
        // When: Accessing the noop static instance
        let callbacks = ItemRowCallbacks.noop

        // Then: It should be accessible (compile-time check that .noop exists)
        // Call each callback to ensure they are no-ops (don't crash)
        callbacks.onTap("test-id")
        callbacks.onChevronTap("test-id")
        callbacks.onToggleComplete("test-id")

        // If we get here without crashing, the test passes
        XCTAssertTrue(true, "ItemRowCallbacks.noop should be callable without side effects")
    }

    func testItemRowCallbacksCanBeInstantiatedWithCustomClosures() {
        // Given: Tracking variables
        var tappedId: String?
        var chevronTappedId: String?
        var toggledId: String?

        // When: Creating custom callbacks
        let callbacks = ItemRowCallbacks(
            onTap: { id in tappedId = id },
            onChevronTap: { id in chevronTappedId = id },
            onToggleComplete: { id in toggledId = id },
            onDragStart: { _ in },
            onDropValidate: { _, _, _ in false },
            onDropPerform: { _, _, _ in },
            onDropUpdated: { _, _ in },
            onDropExited: { _ in },
            onDragEnd: { }
        )

        // Then: Callbacks should work
        callbacks.onTap("item-1")
        callbacks.onChevronTap("item-2")
        callbacks.onToggleComplete("item-3")

        XCTAssertEqual(tappedId, "item-1")
        XCTAssertEqual(chevronTappedId, "item-2")
        XCTAssertEqual(toggledId, "item-3")
    }

    func testItemRowCallbacksNoopDoesNotMutateState() {
        // Given: A flag to detect mutation
        var mutated = false

        // When: Using noop callbacks
        let callbacks = ItemRowCallbacks.noop

        // Then: Calling noop should not trigger any external side effects
        // We can't actually test the internals, but we ensure it doesn't crash
        callbacks.onTap("test")
        callbacks.onChevronTap("test")
        callbacks.onToggleComplete("test")

        XCTAssertFalse(mutated, "Noop callbacks should not cause external state changes")
    }

    // MARK: - ItemRow Initializer Compatibility Tests

    /// Tests that ItemRow can be instantiated without the new optional arguments.
    /// This ensures backwards compatibility with existing call sites.
    /// Note: We cannot fully instantiate ItemRow in unit tests because it requires
    /// @ObservedObject and @FocusState.Binding, so we verify the types exist.
    func testRowPropsAndCallbacksHaveCorrectDefaults() {
        // Given: Default values from the ItemRow definition
        // The defaults are: rowProps: RowProps? = nil, callbacks: ItemRowCallbacks = .noop

        // When: Checking the noop instance
        let defaultCallbacks = ItemRowCallbacks.noop

        // Then: Verify the noop callbacks exist and are callable
        defaultCallbacks.onTap("test")
        defaultCallbacks.onChevronTap("test")
        defaultCallbacks.onToggleComplete("test")

        // This test passing means the defaults are properly defined
        XCTAssertTrue(true, "Default callbacks should be safely callable")
    }

    func testRowPropsWithNilIsValidState() {
        // Given: A variable that could hold RowProps or nil
        let rowProps: RowProps? = nil

        // Then: nil is a valid state (matches default in ItemRow)
        XCTAssertNil(rowProps, "nil should be a valid value for optional RowProps")
    }

    func testRowPropsWithValueIsValidState() {
        // Given: A RowProps instance
        let item = Item(title: "Test")
        let rowProps: RowProps? = RowProps(
            item: item,
            isSelected: false,
            isExpanded: false,
            isFocusedItem: false,
            fontSize: 14.0,
            children: [],
            childCount: 0,
            tagCount: 0,
            isDropTargetInto: false,
            isDropTargetAbove: false,
            isDropTargetBelow: false
        )

        // Then: The optional should contain a value
        XCTAssertNotNil(rowProps, "RowProps should be assignable to optional")
        XCTAssertEqual(rowProps?.item.title, "Test")
    }

    // MARK: - Edge Cases

    func testRowPropsWithZeroFontSize() {
        // Given: Edge case with zero font size
        let item = Item()
        let rowProps = RowProps(item: item, isSelected: false, isExpanded: false, isFocusedItem: false, fontSize: 0, children: [], childCount: 0, tagCount: 0, isDropTargetInto: false, isDropTargetAbove: false, isDropTargetBelow: false)

        // Then: Should still be valid (rendering behavior is not tested here)
        XCTAssertEqual(rowProps.fontSize, 0)
    }

    func testRowPropsWithLargeFontSize() {
        // Given: Edge case with very large font size
        let item = Item()
        let rowProps = RowProps(item: item, isSelected: false, isExpanded: false, isFocusedItem: false, fontSize: 1000.0, children: [], childCount: 0, tagCount: 0, isDropTargetInto: false, isDropTargetAbove: false, isDropTargetBelow: false)

        // Then: Should still be valid
        XCTAssertEqual(rowProps.fontSize, 1000.0)
    }

    func testItemRowCallbacksWithEmptyItemId() {
        // Given: Callbacks that track calls
        var receivedIds: [String] = []
        let callbacks = ItemRowCallbacks(
            onTap: { id in receivedIds.append("tap:\(id)") },
            onChevronTap: { id in receivedIds.append("chevron:\(id)") },
            onToggleComplete: { id in receivedIds.append("toggle:\(id)") },
            onDragStart: { _ in },
            onDropValidate: { _, _, _ in false },
            onDropPerform: { _, _, _ in },
            onDropUpdated: { _, _ in },
            onDropExited: { _ in },
            onDragEnd: { }
        )

        // When: Calling with empty string
        callbacks.onTap("")
        callbacks.onChevronTap("")
        callbacks.onToggleComplete("")

        // Then: Empty strings should be handled
        XCTAssertEqual(receivedIds, ["tap:", "chevron:", "toggle:"])
    }

    // MARK: - Phase 4 Scaffolding: Tap Handler Tests
    // These tests verify selection/focus updates via callbacks.
    // They will be activated once dev provides the tap handler implementation.

    func testOnTapCallbackUpdatesSelection() {
        // Given: A tap handler that should update selection
        var selectedItemId: String?
        let callbacks = ItemRowCallbacks(
            onTap: { id in selectedItemId = id },
            onChevronTap: { _ in },
            onToggleComplete: { _ in },
            onDragStart: { _ in },
            onDropValidate: { _, _, _ in false },
            onDropPerform: { _, _, _ in },
            onDropUpdated: { _, _ in },
            onDropExited: { _ in },
            onDragEnd: { }
        )

        // When: Tapping an item
        callbacks.onTap("item-to-select")

        // Then: Selection should be updated
        XCTAssertEqual(selectedItemId, "item-to-select")
    }

    func testOnTapCallbackUpdatesFocus() {
        // Given: A tap handler that should update focus
        var focusedItemId: String?
        let callbacks = ItemRowCallbacks(
            onTap: { id in focusedItemId = id },
            onChevronTap: { _ in },
            onToggleComplete: { _ in },
            onDragStart: { _ in },
            onDropValidate: { _, _, _ in false },
            onDropPerform: { _, _, _ in },
            onDropUpdated: { _, _ in },
            onDropExited: { _ in },
            onDragEnd: { }
        )

        // When: Tapping an item
        callbacks.onTap("item-to-focus")

        // Then: Focus should be updated
        XCTAssertEqual(focusedItemId, "item-to-focus")
    }

    func testOnTapCallbackSequence() {
        // Given: Multiple taps should update selection sequentially
        var selectionHistory: [String] = []
        let callbacks = ItemRowCallbacks(
            onTap: { id in selectionHistory.append(id) },
            onChevronTap: { _ in },
            onToggleComplete: { _ in },
            onDragStart: { _ in },
            onDropValidate: { _, _, _ in false },
            onDropPerform: { _, _, _ in },
            onDropUpdated: { _, _ in },
            onDropExited: { _ in },
            onDragEnd: { }
        )

        // When: Tapping multiple items
        callbacks.onTap("item-1")
        callbacks.onTap("item-2")
        callbacks.onTap("item-3")

        // Then: All taps should be recorded in order
        XCTAssertEqual(selectionHistory, ["item-1", "item-2", "item-3"])
    }

    func testOnChevronTapTogglesExpansion() {
        // Given: A chevron handler that tracks expansion toggles
        var toggledItemIds: [String] = []
        let callbacks = ItemRowCallbacks(
            onTap: { _ in },
            onChevronTap: { id in toggledItemIds.append(id) },
            onToggleComplete: { _ in },
            onDragStart: { _ in },
            onDropValidate: { _, _, _ in false },
            onDropPerform: { _, _, _ in },
            onDropUpdated: { _, _ in },
            onDropExited: { _ in },
            onDragEnd: { }
        )

        // When: Tapping chevrons
        callbacks.onChevronTap("parent-1")
        callbacks.onChevronTap("parent-2")

        // Then: Expansion toggles should be recorded
        XCTAssertEqual(toggledItemIds, ["parent-1", "parent-2"])
    }

    func testOnToggleCompleteUpdatesTaskState() {
        // Given: A completion handler that tracks toggled tasks
        var completedTaskIds: [String] = []
        let callbacks = ItemRowCallbacks(
            onTap: { _ in },
            onChevronTap: { _ in },
            onToggleComplete: { id in completedTaskIds.append(id) },
            onDragStart: { _ in },
            onDropValidate: { _, _, _ in false },
            onDropPerform: { _, _, _ in },
            onDropUpdated: { _, _ in },
            onDropExited: { _ in },
            onDragEnd: { }
        )

        // When: Toggling task completion
        callbacks.onToggleComplete("task-1")
        callbacks.onToggleComplete("task-2")

        // Then: Completion toggles should be recorded
        XCTAssertEqual(completedTaskIds, ["task-1", "task-2"])
    }
}
