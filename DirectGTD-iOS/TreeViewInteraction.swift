import Foundation

/// Pure logic for TreeView interactions, exposed for unit testing.
/// Phase 5: Centralizes expand/collapse behavior.
enum TreeViewInteraction {

    /// Result of a toggle expansion operation.
    struct ToggleExpansionResult {
        let expanded: Set<String>
        let selectedId: String?
    }

    /// Toggles expansion state for an item.
    /// - Parameters:
    ///   - itemId: The item being toggled.
    ///   - isFocusedItem: Whether this item is currently focused (focused items can't collapse).
    ///   - hasChildren: Whether the item has visible children.
    ///   - selectedId: The currently selected item ID.
    ///   - expanded: The current set of expanded item IDs.
    ///   - isDescendant: A function to check if `childId` is a descendant of `parentId`.
    /// - Returns: Updated expanded set and selected ID.
    static func toggleExpansion(
        itemId: String,
        isFocusedItem: Bool,
        hasChildren: Bool,
        selectedId: String?,
        expanded: Set<String>,
        isDescendant: (_ childId: String, _ parentId: String) -> Bool
    ) -> ToggleExpansionResult {
        // No-op if item has no children
        guard hasChildren else {
            return ToggleExpansionResult(expanded: expanded, selectedId: selectedId)
        }

        // No-op if this is the focused item (always expanded)
        guard !isFocusedItem else {
            return ToggleExpansionResult(expanded: expanded, selectedId: selectedId)
        }

        var newExpanded = expanded
        var newSelectedId = selectedId

        if expanded.contains(itemId) {
            // Collapsing: if selection is a descendant, move selection to this item
            if let currentSelection = selectedId, isDescendant(currentSelection, itemId) {
                newSelectedId = itemId
            }
            newExpanded.remove(itemId)
        } else {
            // Expanding
            newExpanded.insert(itemId)
        }

        return ToggleExpansionResult(expanded: newExpanded, selectedId: newSelectedId)
    }

    // MARK: - Phase 6: Completion Toggle

    /// Determines the new selection after a completion toggle.
    /// - Parameters:
    ///   - isTask: Whether the toggled item is a task.
    ///   - wasCompleted: Whether the item was completed before the toggle.
    ///   - filtersActive: Whether filters (hide completed, tag filter, SQL search) might hide the item.
    ///   - selectedId: The currently selected item ID.
    ///   - toggledId: The item being toggled.
    ///   - isVisibleAfterToggle: A closure to check if the toggled item will still be visible.
    ///   - fallbackVisibleId: A closure to find a fallback visible item if needed.
    /// - Returns: The new selected item ID, or nil if selection should be cleared.
    static func handleCompletionToggle(
        isTask: Bool,
        wasCompleted: Bool,
        filtersActive: Bool,
        selectedId: String?,
        toggledId: String,
        isVisibleAfterToggle: (String) -> Bool,
        fallbackVisibleId: () -> String?
    ) -> String? {
        // No-op for non-tasks
        guard isTask else { return selectedId }

        // If no filters active, item will remain visible
        guard filtersActive else { return selectedId }

        // If the toggled item is still visible, keep selection
        if isVisibleAfterToggle(toggledId) {
            return selectedId
        }

        // Item became hidden, need to update selection if it was selected
        if selectedId == toggledId {
            return fallbackVisibleId()
        }

        return selectedId
    }
}
