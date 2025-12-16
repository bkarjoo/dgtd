import CoreGraphics
import DirectGTDCore
import Foundation

/// Presentational properties for rendering an item row.
/// Phase 8: All visual state derived by TreeView, rows are purely presentational.
struct RowProps {
    let item: Item
    let isSelected: Bool
    let isExpanded: Bool
    let isFocusedItem: Bool
    let fontSize: CGFloat
    let children: [Item]
    let childCount: Int
    let tagCount: Int
    let isDropTargetInto: Bool
    let isDropTargetAbove: Bool
    let isDropTargetBelow: Bool
}

/// Callbacks for item row interactions.
/// Phase 1: Defined but ItemRow continues to handle interactions internally.
/// Phase 7: Added drag-and-drop callbacks.
struct ItemRowCallbacks {
    var onTap: (String) -> Void
    var onChevronTap: (String) -> Void
    var onToggleComplete: (String) -> Void

    // Phase 7: Drag-and-drop callbacks
    var onDragStart: (String) -> Void
    var onDropValidate: (_ draggedId: String?, _ targetId: String, _ position: DropPosition) -> Bool
    var onDropPerform: (_ draggedId: String, _ targetId: String, _ position: DropPosition) -> Void
    var onDropUpdated: (_ targetId: String, _ position: DropPosition) -> Void
    var onDropExited: (_ targetId: String) -> Void
    var onDragEnd: () -> Void

    static let noop = ItemRowCallbacks(
        onTap: { _ in },
        onChevronTap: { _ in },
        onToggleComplete: { _ in },
        onDragStart: { _ in },
        onDropValidate: { _, _, _ in false },
        onDropPerform: { _, _, _ in },
        onDropUpdated: { _, _ in },
        onDropExited: { _ in },
        onDragEnd: { }
    )
}
