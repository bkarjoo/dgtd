import DirectGTDCore
import SwiftUI
import UniformTypeIdentifiers

/// Phase 7: DropDelegate that forwards all decisions to callbacks
struct ItemDropDelegate: DropDelegate {
    let item: Item
    let rowHeight: CGFloat
    let callbacks: ItemRowCallbacks
    let draggedItemId: String?

    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.directGTDItem]).first else {
            // Clear drop indicators on failure
            callbacks.onDragEnd()
            return false
        }

        itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.directGTDItem.identifier) { data, error in
            guard let data = data,
                  let draggedId = String(data: data, encoding: .utf8) else {
                // Clear drop indicators on decode failure
                DispatchQueue.main.async {
                    callbacks.onDragEnd()
                }
                return
            }

            DispatchQueue.main.async {
                let position = getDropPosition(info: info)
                callbacks.onDropPerform(draggedId, item.id, position)
            }
        }

        return true
    }

    func validateDrop(info: DropInfo) -> Bool {
        // Only accept drops with our custom type (rejects external drags automatically)
        guard info.itemProviders(for: [.directGTDItem]).first != nil else {
            return false
        }

        // Validate using tracked draggedItemId (synchronous)
        // Custom UTType ensures this is always a real in-app drag, never spoofed
        let position = getDropPosition(info: info)
        return callbacks.onDropValidate(draggedItemId, item.id, position)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let position = getDropPosition(info: info)
        callbacks.onDropUpdated(item.id, position)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        callbacks.onDropExited(item.id)
    }

    private func getDropPosition(info: DropInfo) -> DropPosition {
        // Divide the item into three zones: top 25%, middle 50%, bottom 25%
        let y = info.location.y

        // Calculate relative position within the row (0-1)
        // DropInfo.location gives us coordinates within the drop target view
        let relativeY = y / rowHeight

        if relativeY < 0.25 {
            return .above
        } else if relativeY > 0.75 {
            return .below
        } else {
            return .into
        }
    }
}
