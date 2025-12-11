//
//  ItemDetailView.swift
//  DirectGTD-iOS
//
//  Created by Behrooz Karjoo on 12/9/25.
//

import SwiftUI
import DirectGTDCore

struct ItemDetailView: View {
    let item: Item
    @EnvironmentObject var viewModel: TreeViewModel
    @Environment(\.dismiss) private var dismiss

    // Editable state
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var itemType: ItemType = .task
    @State private var dueDate: Date? = nil
    @State private var hasDueDate: Bool = false
    @State private var earliestStartTime: Date? = nil
    @State private var hasEarliestStart: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                // Title Section
                Section {
                    TextField("Title", text: $title)
                        .font(.title3)
                }

                // Type Section
                Section {
                    Picker("Type", selection: $itemType) {
                        ForEach([ItemType.task, .note, .project, .folder], id: \.self) { type in
                            Label(type.rawValue, systemImage: type.defaultIcon)
                                .tag(type)
                        }
                    }

                    if itemType == .task {
                        HStack {
                            Label("Status", systemImage: item.completedAt != nil ? "checkmark.circle.fill" : "circle")
                            Spacer()
                            Text(item.completedAt != nil ? "Completed" : "Incomplete")
                                .foregroundStyle(item.completedAt != nil ? .green : .secondary)
                        }
                    }
                }

                // Dates Section
                Section("Dates") {
                    Toggle(isOn: $hasDueDate) {
                        Label("Due Date", systemImage: "calendar")
                    }
                    .onChange(of: hasDueDate) { _, newValue in
                        if newValue && dueDate == nil {
                            dueDate = Date()
                        }
                    }

                    if hasDueDate {
                        DatePicker(
                            "Due",
                            selection: Binding(
                                get: { dueDate ?? Date() },
                                set: { dueDate = $0 }
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }

                    Toggle(isOn: $hasEarliestStart) {
                        Label("Earliest Start", systemImage: "clock")
                    }
                    .onChange(of: hasEarliestStart) { _, newValue in
                        if newValue && earliestStartTime == nil {
                            earliestStartTime = Date()
                        }
                    }

                    if hasEarliestStart {
                        DatePicker(
                            "Start",
                            selection: Binding(
                                get: { earliestStartTime ?? Date() },
                                set: { earliestStartTime = $0 }
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                // Info Section (read-only)
                Section("Info") {
                    HStack {
                        Label("Created", systemImage: "plus.circle")
                        Spacer()
                        Text(formatDate(timestamp: item.createdAt))
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Modified", systemImage: "pencil.circle")
                        Spacer()
                        Text(formatDate(timestamp: item.modifiedAt))
                            .foregroundStyle(.secondary)
                    }

                    if let completedAt = item.completedAt {
                        HStack {
                            Label("Completed", systemImage: "checkmark.circle")
                            Spacer()
                            Text(formatDate(timestamp: completedAt))
                                .foregroundStyle(.green)
                        }
                    }
                }

                // Notes Section
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 150)
                }
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // Initialize state from item
            title = item.title ?? ""
            notes = item.notes ?? ""
            itemType = item.itemType

            if let due = item.dueDate {
                dueDate = Date(timeIntervalSince1970: TimeInterval(due))
                hasDueDate = true
            }

            if let earliest = item.earliestStartTime {
                earliestStartTime = Date(timeIntervalSince1970: TimeInterval(earliest))
                hasEarliestStart = true
            }
        }
    }

    private func saveChanges() {
        var updatedItem = item
        updatedItem.title = title.isEmpty ? nil : title
        updatedItem.notes = notes.isEmpty ? nil : notes
        updatedItem.itemType = itemType
        updatedItem.dueDate = hasDueDate ? Int(dueDate?.timeIntervalSince1970 ?? 0) : nil
        updatedItem.earliestStartTime = hasEarliestStart ? Int(earliestStartTime?.timeIntervalSince1970 ?? 0) : nil
        updatedItem.modifiedAt = Int(Date().timeIntervalSince1970)

        viewModel.updateItem(updatedItem)

        Task {
            await viewModel.syncAndReload()
        }
    }

    private func formatDate(timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()

        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if Calendar.current.isDateInTomorrow(date) {
            formatter.dateFormat = "'Tomorrow at' h:mm a"
        } else if Calendar.current.isDateInYesterday(date) {
            formatter.dateFormat = "'Yesterday at' h:mm a"
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
        }

        return formatter.string(from: date)
    }
}

#Preview {
    let now = Int(Date().timeIntervalSince1970)
    let item = Item(
        id: "preview",
        title: "Sample Task",
        itemType: .task,
        notes: "This is a sample note for the task.\n\nIt can have multiple paragraphs.",
        parentId: nil,
        sortOrder: 0,
        createdAt: now - 86400,
        modifiedAt: now,
        completedAt: nil,
        dueDate: now + 3600,
        earliestStartTime: now
    )
    return ItemDetailView(item: item)
        .environmentObject(TreeViewModel())
}
