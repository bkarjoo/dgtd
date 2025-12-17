import DirectGTDCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: UserSettings
    @ObservedObject var store: ItemStore
    @ObservedObject var syncEngine: SyncEngine
    @StateObject private var backupService = BackupService.shared
    @Environment(\.dismiss) var dismiss
    @State private var quickCaptureFolderId: String?
    @State private var archiveFolderId: String?
    @State private var showingTagManager: Bool = false
    @State private var showingBackupManager: Bool = false
    @State private var showingResetSyncConfirmation: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            Form {
                Section("Quick Capture") {
                Picker("Quick Capture Folder", selection: $quickCaptureFolderId) {
                    Text("None").tag(String?.none)
                    ForEach(folderItems, id: \.id) { folder in
                        Text(folder.title ?? "Untitled").tag(String?.some(folder.id))
                    }
                }
                .onChange(of: quickCaptureFolderId) { oldValue, newValue in
                    saveQuickCaptureFolder(newValue)
                }
            }

            Section("Archive") {
                Picker("Archive Folder", selection: $archiveFolderId) {
                    Text("None").tag(String?.none)
                    ForEach(folderItems, id: \.id) { folder in
                        Text(folder.title ?? "Untitled").tag(String?.some(folder.id))
                    }
                }
                .onChange(of: archiveFolderId) { oldValue, newValue in
                    saveArchiveFolder(newValue)
                }
            }

            Section("Tags") {
                Button(action: { showingTagManager = true }) {
                    HStack {
                        Text("Manage Tags")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Section("Backups") {
                Button(action: { showingBackupManager = true }) {
                    HStack {
                        Text("Manage Backups")
                        Spacer()
                        Text("\(backupService.listBackups().count) backups")
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button("Backup Now") {
                    backupService.performBackup()
                }
            }

            Section("iCloud Sync") {
                Toggle("Enable iCloud Sync", isOn: $syncEngine.isSyncEnabled)

                HStack {
                    Text("Status")
                    Spacer()
                    syncStatusText
                }

                if let accountName = syncEngine.iCloudAccountName {
                    HStack {
                        Text("Account")
                        Spacer()
                        Text(accountName)
                            .foregroundColor(.secondary)
                    }
                }

                if let lastSync = syncEngine.lastSyncDate {
                    HStack {
                        Text("Last Sync")
                        Spacer()
                        Text(lastSync, style: .relative)
                            .foregroundColor(.secondary)
                        Text("ago")
                            .foregroundColor(.secondary)
                    }
                }

                Button(action: {
                    syncEngine.requestSync()
                }) {
                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(!syncEngine.isSyncEnabled || isSyncing)

                Button(role: .destructive, action: {
                    showingResetSyncConfirmation = true
                }) {
                    Label("Reset Sync Data", systemImage: "arrow.counterclockwise")
                }
                .disabled(isSyncing)
            }

            Section("Debug") {
                HStack {
                    Text("Selected Item ID")
                    Spacer()
                    if let selectedId = store.selectedItemId {
                        Text(selectedId)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    } else {
                        Text("None")
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    Text("Inbox Folder ID")
                    Spacer()
                    if let inboxId = quickCaptureFolderId {
                        Text(inboxId)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    } else {
                        Text("Not set")
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Tree") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Font Size: \(Int(settings.fontSize))")
                    Slider(value: $settings.fontSize, in: 8...48, step: 1)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Horizontal Margin: \(Int(settings.horizontalMargin))")
                    Slider(value: $settings.horizontalMargin, in: 0...32, step: 1)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Vertical Margin: \(Int(settings.verticalMargin))")
                    Slider(value: $settings.verticalMargin, in: 0...16, step: 1)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Line Spacing: \(Int(settings.lineSpacing))")
                    Slider(value: $settings.lineSpacing, in: 0...16, step: 1)
                }
            }

            Section("Markdown") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Font Size: \(Int(settings.markdownFontSize))")
                    Slider(value: $settings.markdownFontSize, in: 8...48, step: 1)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Line Spacing: \(Int(settings.markdownLineSpacing))")
                    Slider(value: $settings.markdownLineSpacing, in: 0...16, step: 1)
                }
            }
            }
            .formStyle(.grouped)
        }
        .frame(width: 400, height: 550)
        .onAppear {
            loadQuickCaptureFolder()
            loadArchiveFolder()
        }
        .sheet(isPresented: $showingTagManager) {
            TagManagerView(store: store)
        }
        .sheet(isPresented: $showingBackupManager) {
            BackupManagerView()
        }
        .alert("Too Many Backups", isPresented: $backupService.showBackupCleanupPrompt) {
            Button("Manage Backups") {
                showingBackupManager = true
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text("You have \(backupService.backupCount) backups. Would you like to delete some old ones?")
        }
        .alert("Reset Sync Data", isPresented: $showingResetSyncConfirmation) {
            Button("Reset", role: .destructive) {
                Task {
                    try? await syncEngine.resetSyncState()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will clear all sync metadata and re-sync all data from scratch. Your data will not be deleted. Continue?")
        }
    }

    private var isSyncing: Bool {
        switch syncEngine.status {
        case .syncing, .initialSync:
            return true
        default:
            return false
        }
    }

    @ViewBuilder
    private var syncStatusText: some View {
        switch syncEngine.status {
        case .disabled:
            if !syncEngine.isSyncEnabled {
                Text("Disabled")
                    .foregroundColor(.secondary)
            } else {
                Text("Not Available")
                    .foregroundColor(.orange)
            }
        case .idle:
            Text("Ready")
                .foregroundColor(.green)
        case .syncing:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.5)
                Text("Syncing...")
                    .foregroundColor(.secondary)
            }
        case .initialSync(let progress, _):
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.5)
                Text("Initial sync \(Int(progress * 100))%")
                    .foregroundColor(.secondary)
            }
        case .error(let message):
            Text(message)
                .foregroundColor(.red)
                .lineLimit(1)
        }
    }

    private var folderItems: [Item] {
        store.items.filter { $0.itemType == .folder }
    }

    private func loadQuickCaptureFolder() {
        let repository = ItemRepository()
        quickCaptureFolderId = try? repository.getSetting(key: "quick_capture_folder_id")
    }

    private func saveQuickCaptureFolder(_ folderId: String?) {
        let repository = ItemRepository()
        try? repository.setSetting(key: "quick_capture_folder_id", value: folderId)
    }

    private func loadArchiveFolder() {
        let repository = ItemRepository()
        archiveFolderId = try? repository.getSetting(key: "archive_folder_id")
    }

    private func saveArchiveFolder(_ folderId: String?) {
        let repository = ItemRepository()
        try? repository.setSetting(key: "archive_folder_id", value: folderId)
    }
}

#Preview {
    let settings = UserSettings()
    SettingsView(settings: settings, store: ItemStore(settings: settings), syncEngine: SyncEngine(
        cloudKitManager: CloudKitManager.shared,
        database: Database.shared
    ))
}
