import DirectGTDCore
import SwiftUI

struct BackupManagerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var backupService = BackupService.shared
    @State private var backups: [BackupInfo] = []
    @State private var selectedBackups: Set<UUID> = []
    @State private var showingRestoreConfirmation = false
    @State private var backupToRestore: BackupInfo?
    @State private var showingDeleteConfirmation = false
    @State private var restoreErrorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Backups")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            if backups.isEmpty {
                VStack {
                    Spacer()
                    Text("No backups yet")
                        .foregroundColor(.secondary)
                    Text("Backups are created automatically (hourly and daily)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(selection: $selectedBackups) {
                    ForEach(backups) { backup in
                        HStack {
                            VStack(alignment: .leading) {
                                HStack(spacing: 6) {
                                    Text(backup.filename)
                                        .font(.body)
                                    Text(backup.typeLabel)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(backup.type == .daily ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                                        .cornerRadius(4)
                                }
                                Text(formatDate(backup.date))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(backup.formattedSize)
                                .foregroundColor(.secondary)
                        }
                        .tag(backup.id)
                    }
                }
            }

            Divider()

            // Footer with actions
            HStack {
                Button("Backup Now") {
                    backupService.performBackup()
                    refreshBackups()
                }

                Spacer()

                if !selectedBackups.isEmpty {
                    Button("Delete Selected") {
                        showingDeleteConfirmation = true
                    }
                    .foregroundColor(.red)

                    if selectedBackups.count == 1 {
                        Button("Restore") {
                            if let selected = selectedBackups.first,
                               let backup = backups.first(where: { $0.id == selected }) {
                                backupToRestore = backup
                                showingRestoreConfirmation = true
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .frame(width: 450, height: 400)
        .onAppear {
            refreshBackups()
        }
        .confirmationDialog(
            "Restore Backup?",
            isPresented: $showingRestoreConfirmation,
            presenting: backupToRestore
        ) { backup in
            Button("Restore from \(backup.filename)", role: .destructive) {
                do {
                    try backupService.restore(from: backup)
                    DispatchQueue.main.async {
                        NSApplication.shared.terminate(nil)
                    }
                } catch {
                    restoreErrorMessage = error.localizedDescription
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { backup in
            Text("This will replace your current database with the backup from \(backup.filename). The app will need to restart. This cannot be undone.")
        }
        .confirmationDialog(
            "Delete Backups?",
            isPresented: $showingDeleteConfirmation
        ) {
            Button("Delete \(selectedBackups.count) backup(s)", role: .destructive) {
                let toDelete = backups.filter { selectedBackups.contains($0.id) }
                backupService.deleteBackups(toDelete)
                selectedBackups.removeAll()
                refreshBackups()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete the selected backups? This cannot be undone.")
        }
        .alert("Restore Failed", isPresented: Binding(
            get: { restoreErrorMessage != nil },
            set: { newValue in
                if !newValue { restoreErrorMessage = nil }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreErrorMessage ?? "Unknown error")
        }
    }

    private func refreshBackups() {
        backups = backupService.listAllBackups()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    BackupManagerView()
}
