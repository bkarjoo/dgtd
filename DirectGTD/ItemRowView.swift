import DirectGTDCore
import SwiftUI
import UniformTypeIdentifiers

/// Phase 10: Presentational row view - reads all visuals from RowProps.
/// Only store access is for editing (isEditing, commitEdit, cancelEdit) and draggedItemId for DnD.
struct ItemRowView: View {
    let item: Item
    @ObservedObject var store: ItemStore
    @FocusState.Binding var editFieldFocused: Bool
    let fontSize: CGFloat

    let rowProps: RowProps
    var callbacks: ItemRowCallbacks = .noop

    @State private var editText: String = ""
    @State private var rowHeight: CGFloat = 0

    var body: some View {
        HStack(spacing: 4) {
            // Fixed-width chevron area
            Button(action: {
                callbacks.onChevronTap(item.id)
            }) {
                if rowProps.childCount > 0 {
                    let showExpanded = rowProps.isFocusedItem || rowProps.isExpanded
                    Image(systemName: showExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: fontSize * 0.8))
                        .frame(width: fontSize, height: fontSize)
                        .contentShape(Rectangle())
                } else {
                    Color.clear
                        .frame(width: fontSize, height: fontSize)
                }
            }
            .buttonStyle(.plain)

            if isEditing {
                TextField("", text: $editText)
                    .focused($editFieldFocused)
                    .textFieldStyle(.plain)
                    .font(.system(size: fontSize))
                    .onSubmit {
                        commitEdit()
                    }
                    .onAppear {
                        editText = item.title ?? ""
                    }
                    .onExitCommand {
                        cancelEdit()
                    }
            } else {
                // Icon
                if item.itemType == .task {
                    Image(systemName: item.completedAt == nil ? "square" : "checkmark.square.fill")
                        .font(.system(size: fontSize))
                        .onTapGesture {
                            callbacks.onToggleComplete(item.id)
                        }
                } else {
                    Image(systemName: item.itemType.defaultIcon)
                        .font(.system(size: fontSize))
                }

                Text(item.title ?? "Untitled")
                    .font(.system(size: fontSize))

                Spacer()

                // Date badges
                if let dueDate = item.dueDate {
                    let dueDateObj = Date(timeIntervalSince1970: TimeInterval(dueDate))
                    let isOverdue = dueDateObj < Date()
                    let isToday = Calendar.current.isDateInToday(dueDateObj)
                    let isTomorrow = Calendar.current.isDateInTomorrow(dueDateObj)

                    Text(isToday ? "Today" : isTomorrow ? "Tomorrow" : formatDate(dueDateObj))
                        .font(.system(size: fontSize * 0.8))
                        .foregroundColor(isOverdue ? .red : isToday ? .orange : .secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background((isOverdue ? Color.red : isToday ? Color.orange : Color.secondary).opacity(0.1))
                        .cornerRadius(4)
                }

                if let startTime = item.earliestStartTime {
                    let startDateObj = Date(timeIntervalSince1970: TimeInterval(startTime))
                    let isDeferred = startDateObj > Date()

                    if isDeferred {
                        Text(formatDate(startDateObj))
                            .font(.system(size: fontSize * 0.8))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }

                // Tag count badge
                if rowProps.tagCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: fontSize * 0.7))
                        Text("\(rowProps.tagCount)")
                            .font(.system(size: fontSize * 0.8))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
                }

                // Children count
                if rowProps.childCount > 0 {
                    Text("\(rowProps.childCount)")
                        .font(.system(size: fontSize * 0.9))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            rowProps.isDropTargetInto ? Color.accentColor.opacity(0.25) :
            rowProps.isSelected ? Color.accentColor.opacity(0.2) :
            Color.clear
        )
        .overlay(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: ItemHeightPreferenceKey.self, value: geometry.size.height)
                    .onAppear {
                        rowHeight = geometry.size.height
                    }
            }
        )
        .onPreferenceChange(ItemHeightPreferenceKey.self) { height in
            rowHeight = height
        }
        .overlay(alignment: .top) {
            if rowProps.isDropTargetAbove {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2)
            }
        }
        .overlay(alignment: .bottom) {
            if rowProps.isDropTargetBelow {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            callbacks.onTap(item.id)
        }
        .onDrag {
            callbacks.onDragStart(item.id)
            let provider = NSItemProvider()
            provider.registerDataRepresentation(forTypeIdentifier: UTType.directGTDItem.identifier, visibility: .all) { completion in
                let data = item.id.data(using: .utf8)
                completion(data, nil)
                return nil
            }
            return provider
        }
        .onDrop(of: [.directGTDItem], delegate: ItemDropDelegate(
            item: item,
            rowHeight: rowHeight > 0 ? rowHeight : fontSize * 2.5,
            callbacks: callbacks,
            draggedItemId: store.draggedItemId
        ))
    }

    private var isEditing: Bool {
        store.editingItemId == item.id
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func commitEdit() {
        if editText.isEmpty {
            store.cancelEditing()
        } else {
            store.updateItemTitle(id: item.id, title: editText)
            store.editingItemId = nil
        }
    }

    private func cancelEdit() {
        store.cancelEditing()
    }
}
