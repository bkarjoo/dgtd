//
//  TreeView.swift
//  DirectGTD-iOS
//
//  Created by Behrooz Karjoo on 12/9/25.
//

import SwiftUI
import DirectGTDCore
import Combine
import GRDB

struct TreeView: View {
    @EnvironmentObject var viewModel: TreeViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Sync error banner
            if let error = viewModel.syncError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .lineLimit(2)
                    Spacer()
                    Button {
                        viewModel.syncError = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
            }

            // Loading indicator
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Syncing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            // Main content
            if viewModel.items.isEmpty && !viewModel.isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("No items")
                        .foregroundStyle(.secondary)
                    if viewModel.syncError != nil {
                        Text("Check your iCloud settings and try again")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.displayItems, id: \.id) { item in
                            ItemRowView(
                                item: item,
                                viewModel: viewModel,
                                depth: 0
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .refreshable {
                    await viewModel.syncAndReload()
                }
            }
        }
    }
}

// MARK: - Item Row View
struct ItemRowView: View {
    let item: Item
    @ObservedObject var viewModel: TreeViewModel
    let depth: Int
    @State private var showingDetails = false
    @State private var showingDeleteConfirmation = false

    private var isExpanded: Bool {
        viewModel.expandedItemIds.contains(item.id)
    }

    private var children: [Item] {
        viewModel.children(of: item.id)
    }

    private var hasChildren: Bool {
        !children.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row content
            HStack(spacing: 8) {
                // Item type icon - tappable for tasks to toggle completion
                if item.itemType == .task {
                    Button {
                        viewModel.toggleCompletion(item.id)
                    } label: {
                        itemIcon
                    }
                    .buttonStyle(.plain)
                } else {
                    itemIcon
                }

                // Title
                Text(item.title ?? "Untitled")
                    .font(.body)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                // Due date badge
                if let dueDate = item.dueDate {
                    dueDateBadge(timestamp: dueDate)
                }

                // Children count badge
                if hasChildren {
                    Text("\(children.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }

                // Chevron button - tap to expand/collapse
                Button {
                    // Don't toggle if this is the focused item (always expanded)
                    if hasChildren && viewModel.focusedItemId != item.id {
                        viewModel.toggleExpanded(item.id)
                    }
                } label: {
                    // Focused item always shows expanded chevron
                    let isFocusedItem = viewModel.focusedItemId == item.id
                    let showExpanded = isFocusedItem || isExpanded
                    Image(systemName: hasChildren ? (showExpanded ? "chevron.down" : "chevron.right") : "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(hasChildren ? .secondary : .tertiary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
            .padding(.leading, CGFloat(depth) * 20)
            .contentShape(Rectangle())
            .onTapGesture {
                if item.itemType == .note {
                    // Notes open in editor view
                    viewModel.editingNoteId = item.id
                } else {
                    // Other items focus in tree
                    viewModel.focusedItemId = item.id
                }
            }
            .background(viewModel.selectedItemId == item.id ? Color.accentColor.opacity(0.1) : Color.clear)
            .contextMenu {
                Button {
                    showingDetails = true
                } label: {
                    Label("Details", systemImage: "info.circle")
                }

                if item.itemType == .task {
                    Button {
                        viewModel.toggleCompletion(item.id)
                    } label: {
                        if item.completedAt != nil {
                            Label("Mark Incomplete", systemImage: "circle")
                        } else {
                            Label("Mark Complete", systemImage: "checkmark.circle")
                        }
                    }
                }

                Divider()

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .sheet(isPresented: $showingDetails) {
                ItemDetailView(item: item)
            }
            .confirmationDialog(
                "Delete \"\(item.title ?? "Untitled")\"?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    viewModel.deleteItem(item.id)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This item will be permanently deleted.")
            }

            // Divider
            Divider()
                .padding(.leading, CGFloat(depth) * 20 + 16)

            // Children (if expanded or this is the focused item)
            let shouldShowChildren = hasChildren && (isExpanded || viewModel.focusedItemId == item.id)
            if shouldShowChildren {
                ForEach(children, id: \.id) { child in
                    ItemRowView(
                        item: child,
                        viewModel: viewModel,
                        depth: depth + 1
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var itemIcon: some View {
        Group {
            switch item.itemType {
            case .task:
                Image(systemName: item.completedAt == nil ? "circle" : "checkmark.circle.fill")
            case .folder:
                Image(systemName: "folder.fill")
            case .project:
                Image(systemName: "folder")
            case .note:
                Image(systemName: "doc.text")
            default:
                Image(systemName: item.itemType.defaultIcon)
            }
        }
        .foregroundColor(.primary)
        .font(.system(size: 16))
    }

    @ViewBuilder
    private func dueDateBadge(timestamp: Int) -> some View {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let isOverdue = date < Date()
        let isToday = Calendar.current.isDateInToday(date)
        let isTomorrow = Calendar.current.isDateInTomorrow(date)

        let text: String = {
            if isToday { return "Today" }
            if isTomorrow { return "Tomorrow" }
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }()

        Text(text)
            .font(.caption)
            .foregroundStyle(isOverdue ? .red : isToday ? .orange : .secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((isOverdue ? Color.red : isToday ? Color.orange : Color.secondary).opacity(0.1))
            .clipShape(Capsule())
    }
}

// MARK: - Tree View Model
class TreeViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var expandedItemIds: Set<String> = []
    @Published var selectedItemId: String?
    @Published var focusedItemId: String?
    @Published var editingNoteId: String?  // When set, show note editor
    @Published var isLoading: Bool = false
    @Published var syncError: String?

    private let syncEngine = SyncEngine()
    private var hasLoadedInitially = false
    private var observationCancellable: AnyDatabaseCancellable?

    init() {
        startDatabaseObservation()
    }

    deinit {
        observationCancellable?.cancel()
    }

    /// Start observing database changes to auto-refresh the tree
    private func startDatabaseObservation() {
        guard let dbQueue = Database.shared.getQueue() else {
            NSLog("TreeViewModel: Cannot start observation - database not initialized")
            return
        }

        // Observe item count and max modified_at to detect any changes
        let observation = ValueObservation.tracking { db -> (Int, Int?) in
            let itemCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items WHERE deleted_at IS NULL") ?? 0
            let maxModified = try Int.fetchOne(db, sql: "SELECT MAX(modified_at) FROM items")
            return (itemCount, maxModified)
        }

        observationCancellable = observation.start(
            in: dbQueue,
            onError: { error in
                NSLog("TreeViewModel: Database observation error - \(error)")
            },
            onChange: { [weak self] _ in
                NSLog("TreeViewModel: Database changed, reloading items")
                DispatchQueue.main.async {
                    self?.loadFromDatabase()
                }
            }
        )

        NSLog("TreeViewModel: Database observation started")
    }

    /// Returns true if we're focused on an item (not at tree root)
    var isFocused: Bool {
        focusedItemId != nil
    }

    /// The currently focused item, if any
    var focusedItem: Item? {
        guard let id = focusedItemId else { return nil }
        return items.first { $0.id == id }
    }

    /// Title of the parent of the focused item (for back button label)
    var focusedItemParentTitle: String? {
        guard let focusedItem = focusedItem,
              let parentId = focusedItem.parentId,
              let parent = items.first(where: { $0.id == parentId }) else {
            return nil
        }
        return parent.title
    }

    /// Navigate to parent of focused item (or back to root)
    func goToParent() {
        guard let focusedId = focusedItemId,
              let focusedItem = items.first(where: { $0.id == focusedId }) else {
            focusedItemId = nil
            return
        }
        focusedItemId = focusedItem.parentId
    }

    /// Items to display at the current focus level
    var displayItems: [Item] {
        if let focusedId = focusedItemId {
            // In focus mode: show the focused item as the single root
            if let focusedItem = items.first(where: { $0.id == focusedId }) {
                return [focusedItem]
            }
        }
        // At tree root: show all root items
        return items
            .filter { $0.parentId == nil }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var rootItems: [Item] {
        items
            .filter { $0.parentId == nil }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func children(of parentId: String) -> [Item] {
        items
            .filter { $0.parentId == parentId }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func toggleExpanded(_ itemId: String) {
        if expandedItemIds.contains(itemId) {
            expandedItemIds.remove(itemId)
        } else {
            expandedItemIds.insert(itemId)
        }
    }

    /// Toggle completion status of a task
    func toggleCompletion(_ itemId: String) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        var item = items[index]

        // Only toggle for tasks
        guard item.itemType == .task else { return }

        let now = Int(Date().timeIntervalSince1970)

        // Toggle completion
        if item.completedAt != nil {
            item.completedAt = nil
        } else {
            item.completedAt = now
        }
        item.modifiedAt = now

        // Update in-memory
        items[index] = item

        // Persist to database
        do {
            try updateItemInDatabase(item)
            NSLog("TreeViewModel: Toggled completion for item \(itemId)")
        } catch {
            NSLog("TreeViewModel: Failed to toggle completion - \(error)")
            syncError = error.localizedDescription
        }
    }

    /// Delete an item (soft delete)
    func deleteItem(_ itemId: String) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        var item = items[index]

        let now = Int(Date().timeIntervalSince1970)
        item.deletedAt = now
        item.modifiedAt = now

        // Remove from in-memory list
        items.remove(at: index)

        // Persist to database
        do {
            try updateItemInDatabase(item)
            NSLog("TreeViewModel: Deleted item \(itemId)")
        } catch {
            NSLog("TreeViewModel: Failed to delete item - \(error)")
            syncError = error.localizedDescription
        }
    }

    /// Update an item (from detail view edits)
    func updateItem(_ item: Item) {
        // Update in-memory
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        }

        // Persist to database
        do {
            try updateItemInDatabase(item)
            NSLog("TreeViewModel: Updated item \(item.id)")
        } catch {
            NSLog("TreeViewModel: Failed to update item - \(error)")
            syncError = error.localizedDescription
        }
    }

    /// Update an item in the database and mark for sync
    private func updateItemInDatabase(_ item: Item) throws {
        guard let dbQueue = Database.shared.getQueue() else {
            throw DatabaseError.notInitialized
        }

        try dbQueue.write { db in
            // Update the item with needs_push = 1
            try db.execute(
                sql: """
                    UPDATE items SET
                        title = ?,
                        item_type = ?,
                        notes = ?,
                        parent_id = ?,
                        sort_order = ?,
                        modified_at = ?,
                        completed_at = ?,
                        due_date = ?,
                        earliest_start_time = ?,
                        deleted_at = ?,
                        needs_push = 1
                    WHERE id = ?
                """,
                arguments: [
                    item.title,
                    item.itemType.rawValue,
                    item.notes,
                    item.parentId,
                    item.sortOrder,
                    item.modifiedAt,
                    item.completedAt,
                    item.dueDate,
                    item.earliestStartTime,
                    item.deletedAt,
                    item.id
                ]
            )
        }
    }

    /// Add a new item to the quick capture folder (or root if not configured)
    func addQuickCaptureItem(title: String, itemType: ItemType = .task) {
        let now = Int(Date().timeIntervalSince1970)

        // Get quick capture folder ID from settings
        let quickCaptureFolderId = getQuickCaptureFolderId()

        // Calculate next sort order
        let siblings = items.filter { $0.parentId == quickCaptureFolderId }
        let maxSortOrder = siblings.map { $0.sortOrder }.max() ?? -1

        // Generate CloudKit record name for new item
        let recordName = "Item_\(UUID().uuidString)"

        let newItem = Item(
            title: title,
            itemType: itemType,
            parentId: quickCaptureFolderId,
            sortOrder: maxSortOrder + 1,
            createdAt: now,
            modifiedAt: now,
            ckRecordName: recordName,
            needsPush: 1
        )

        // Persist to database first
        do {
            try insertItemInDatabase(newItem)
            NSLog("TreeViewModel: Created new item \(newItem.id)")

            // Add to in-memory list
            items.append(newItem)

            // Auto-expand quick capture folder if item was added there
            if let folderId = quickCaptureFolderId {
                expandedItemIds.insert(folderId)
            }

            // Select the new item
            selectedItemId = newItem.id

        } catch {
            NSLog("TreeViewModel: Failed to create item - \(error)")
            syncError = error.localizedDescription
        }
    }

    /// Get quick capture folder ID from app settings, or fall back to Inbox folder
    private func getQuickCaptureFolderId() -> String? {
        guard let dbQueue = Database.shared.getQueue() else { return nil }

        // First try the configured setting
        if let settingValue = try? dbQueue.read({ db in
            try String.fetchOne(db, sql: "SELECT value FROM app_settings WHERE key = ?", arguments: ["quick_capture_folder_id"])
        }), !settingValue.isEmpty {
            return settingValue
        }

        // Fall back to Inbox folder by name
        return items.first(where: { $0.title == "Inbox" && $0.itemType == .folder })?.id
    }

    /// Insert a new item into the database
    private func insertItemInDatabase(_ item: Item) throws {
        guard let dbQueue = Database.shared.getQueue() else {
            throw DatabaseError.notInitialized
        }

        try dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO items (
                        id, title, item_type, notes, parent_id, sort_order,
                        created_at, modified_at, completed_at, due_date,
                        earliest_start_time, ck_record_name, needs_push, deleted_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    item.id,
                    item.title,
                    item.itemType.rawValue,
                    item.notes,
                    item.parentId,
                    item.sortOrder,
                    item.createdAt,
                    item.modifiedAt,
                    item.completedAt,
                    item.dueDate,
                    item.earliestStartTime,
                    item.ckRecordName,
                    1,  // needs_push
                    item.deletedAt
                ]
            )
        }
    }

    /// Load items from local database
    func loadFromDatabase() {
        do {
            items = try syncEngine.getAllItems()
            NSLog("TreeViewModel: Loaded \(items.count) items from database")

            // Auto-expand root level folders only on first load
            if !hasLoadedInitially {
                hasLoadedInitially = true
                for item in rootItems where item.itemType == .folder {
                    expandedItemIds.insert(item.id)
                }
            }
        } catch {
            NSLog("TreeViewModel: Failed to load items - \(error)")
            syncError = error.localizedDescription
        }
    }

    /// Sync from CloudKit and reload
    func syncAndReload() async {
        await MainActor.run {
            isLoading = true
            syncError = nil
        }

        await syncEngine.sync()

        await MainActor.run {
            loadFromDatabase()
            isLoading = false

            if case .error(let message) = syncEngine.status {
                syncError = message
            }
        }
    }

    /// Reset sync: clear local data and re-download from CloudKit
    func resetSync() async {
        await MainActor.run {
            isLoading = true
            syncError = nil
            items = []
            hasLoadedInitially = false
        }

        await syncEngine.resetSync()

        await MainActor.run {
            loadFromDatabase()
            isLoading = false

            if case .error(let message) = syncEngine.status {
                syncError = message
            }
        }
    }

    func loadSampleData() {
        // Create sample hierarchical data for testing
        let now = Int(Date().timeIntervalSince1970)
        let tomorrow = now + 86400
        let yesterday = now - 86400

        // Root folders
        let inbox = Item(id: "inbox", title: "Inbox", itemType: .folder, parentId: nil, sortOrder: 0, createdAt: now, modifiedAt: now)
        let projects = Item(id: "projects", title: "Projects", itemType: .folder, parentId: nil, sortOrder: 1, createdAt: now, modifiedAt: now)
        let reference = Item(id: "reference", title: "Reference", itemType: .folder, parentId: nil, sortOrder: 2, createdAt: now, modifiedAt: now)

        // Inbox items
        let task1 = Item(id: "task1", title: "Review budget proposal", itemType: .task, parentId: "inbox", sortOrder: 0, createdAt: now, modifiedAt: now, dueDate: tomorrow)
        let task2 = Item(id: "task2", title: "Call dentist", itemType: .task, parentId: "inbox", sortOrder: 1, createdAt: now, modifiedAt: now)
        let task3 = Item(id: "task3", title: "Buy groceries", itemType: .task, parentId: "inbox", sortOrder: 2, createdAt: now, modifiedAt: now, completedAt: now)

        // Projects folder items
        let project1 = Item(id: "project1", title: "iOS App Launch", itemType: .project, parentId: "projects", sortOrder: 0, createdAt: now, modifiedAt: now)
        let project2 = Item(id: "project2", title: "Website Redesign", itemType: .project, parentId: "projects", sortOrder: 1, createdAt: now, modifiedAt: now)

        // iOS App Launch tasks
        let projTask1 = Item(id: "projTask1", title: "Complete tree view", itemType: .task, parentId: "project1", sortOrder: 0, createdAt: now, modifiedAt: now, dueDate: now)
        let projTask2 = Item(id: "projTask2", title: "Add CloudKit sync", itemType: .task, parentId: "project1", sortOrder: 1, createdAt: now, modifiedAt: now)
        let projTask3 = Item(id: "projTask3", title: "Submit to App Store", itemType: .task, parentId: "project1", sortOrder: 2, createdAt: now, modifiedAt: now)

        // Website Redesign tasks
        let webTask1 = Item(id: "webTask1", title: "Design mockups", itemType: .task, parentId: "project2", sortOrder: 0, createdAt: now, modifiedAt: now, completedAt: now)
        let webTask2 = Item(id: "webTask2", title: "Implement homepage", itemType: .task, parentId: "project2", sortOrder: 1, createdAt: now, modifiedAt: now, dueDate: yesterday)

        // Reference items
        let note1 = Item(id: "note1", title: "Meeting notes - Dec 5", itemType: .note, parentId: "reference", sortOrder: 0, createdAt: now, modifiedAt: now)
        let note2 = Item(id: "note2", title: "API Documentation", itemType: .note, parentId: "reference", sortOrder: 1, createdAt: now, modifiedAt: now)

        items = [
            inbox, projects, reference,
            task1, task2, task3,
            project1, project2,
            projTask1, projTask2, projTask3,
            webTask1, webTask2,
            note1, note2
        ]

        // Auto-expand top-level folders
        expandedItemIds = ["inbox", "projects"]
    }
}

#Preview {
    NavigationStack {
        TreeView()
            .navigationTitle("DirectGTD")
            .environmentObject(TreeViewModel())
    }
}
