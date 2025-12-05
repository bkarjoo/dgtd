import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: UserSettings
    @ObservedObject var store: ItemStore
    @StateObject private var backupService = BackupService.shared
    @Environment(\.dismiss) var dismiss
    @State private var quickCaptureFolderId: String?
    @State private var archiveFolderId: String?
    @State private var showingTagManager: Bool = false
    @State private var showingBackupManager: Bool = false

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

            Section("Debug (Temporary)") {
                HStack {
                    Text("Selected Item ID:")
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
        .frame(width: 400, height: 400)
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
    SettingsView(settings: settings, store: ItemStore(settings: settings))
}
