# Request: Clarification on Undo Coalescing Behavior

**To:** Dev Team
**From:** Test Team
**Date:** 2025-11-19
**Priority:** Medium
**Related:** Undo coalescing feature implementation

## Summary

We've added tests for the new undo coalescing feature (create + first edit). 4/8 tests pass, but 4 are failing, suggesting our understanding of the expected behavior needs clarification.

## Current Understanding

Based on code review, we understand the coalescing works as follows:

1. When `createItemAfterSelected()` is called, it creates an item and sets `coalesceWithFirstTitleEdit: true`
2. The item ID is added to `pendingCreatedItemIds` set
3. When `updateItemTitle()` is called on a pending item:
   - It removes the item from `pendingCreatedItemIds`
   - It does NOT register a separate undo for the title change
   - Only the creation undo exists (which deletes the item)
4. Result: Undo deletes the entire item, not just the title

## Failing Test Scenarios

### Test 1: Basic Coalescing
```swift
// Create empty item
itemStore.createItemAfterSelected()
let itemId = itemStore.editingItemId

// Type first title
itemStore.updateItemTitle(id: itemId, title: "My New Item")

// Undo once
undoManager.undo()

// EXPECTED: Item completely deleted
// ACTUAL: Test fails - what actually happens?
```

### Test 2: Second Edit After Coalescing
```swift
// Create and type first title (coalesced)
itemStore.createItemAfterSelected()
let itemId = itemStore.editingItemId
itemStore.updateItemTitle(id: itemId, title: "First Title")

// Edit title again
itemStore.updateItemTitle(id: itemId, title: "Second Title")

// Undo once
undoManager.undo()

// EXPECTED: Reverts to "First Title" (second edit undone)
// ACTUAL: Test fails - does it delete the item instead?

// Undo again
undoManager.undo()

// EXPECTED: Item deleted (creation undone)
// ACTUAL: ?
```

### Test 3: createItem() vs createItemAfterSelected()
```swift
// Using createItem (not createItemAfterSelected)
itemStore.createItem(title: "Direct Create")
let itemId = itemStore.selectedItemId

// Edit the title
itemStore.updateItemTitle(id: itemId, title: "Edited Title")

// Undo once
undoManager.undo()

// EXPECTED: Does this coalesce too? Or separate operations?
// ACTUAL: Test fails
```

### Test 4: Delete Clears Pending State
```swift
// Create and edit (pending state)
itemStore.createItemAfterSelected()
let itemId = itemStore.editingItemId
itemStore.updateItemTitle(id: itemId, title: "To Delete")

// Delete it
itemStore.deleteSelectedItem()

// Undo (restore)
undoManager.undo()

// Edit the restored item
itemStore.updateItemTitle(id: itemId, title: "Edited After Restore")

// Undo
undoManager.undo()

// EXPECTED: Reverts to "To Delete" (not delete item)
// ACTUAL: Test fails - does pending state persist after delete/restore?
```

## Questions for Dev Team

1. **First Edit Coalescing**: When a pending item's title is edited for the first time, should undo delete the entire item? (We think: YES)

2. **Second Edit**: After the first edit on a pending item, is the item no longer "pending"? Should subsequent edits create normal undo entries? (We think: YES, but test fails)

3. **createItem() Behavior**: Does `createItem(title: "...")` use coalescing? Looking at the code, it calls `registerCreationUndo()` but without `coalesceWithFirstTitleEdit: true`. What's the expected undo behavior?

4. **Pending State Persistence**: After delete → undo → restore, is the item still in `pendingCreatedItemIds`? Should it be? The code calls `pendingCreatedItemIds.remove(itemId)` in `deleteItem()`, but what about after restore?

5. **NSUndoManager Grouping**: Do we need explicit `endUndoGrouping()`/`beginUndoGrouping()` calls between operations in tests? Or does `loadItems()` or some other operation handle this?

## What We Need

1. **Expected behavior** for each of the 4 failing test scenarios above
2. **Confirmation or correction** of our understanding of the coalescing mechanism
3. **Any edge cases** we should be testing that we haven't considered

## Test Files

- `DirectGTDTests/UndoCoalescingTests.swift` - New coalescing tests (4 passing, 4 failing)
- `DirectGTDTests/UndoTests.swift` - Original undo tests (13 passing, no breakage)

## Current Status

- 58/62 tests passing overall
- All original functionality tests still pass
- Only new coalescing behavior tests are failing

---

**We can adjust the tests once we understand the intended behavior. Please let us know the expected outcomes for the scenarios above.**
