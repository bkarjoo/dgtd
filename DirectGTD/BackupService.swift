import Foundation
import GRDB
import Combine

class BackupService: ObservableObject {
    static let shared = BackupService()

    private let fileManager = FileManager.default
    private let backupThresholdCount = 30
    private var timerCancellable: AnyCancellable?

    // Published for UI to show prompt
    @Published var showBackupCleanupPrompt = false
    @Published var backupCount = 0

    private var backupsDirectory: URL? {
        guard let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }

        let backupsDir = appSupport.appendingPathComponent("DirectGTD/backups")
        try? fileManager.createDirectory(at: backupsDir, withIntermediateDirectories: true)
        return backupsDir
    }

    private var databasePath: URL? {
        guard let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }

        return appSupport.appendingPathComponent("DirectGTD/directgtd.sqlite")
    }

    private var lastBackupDateKey = "lastBackupDate"

    init() {}

    // MARK: - Public API

    /// Called on app launch - checks if backup needed and starts 24-hour timer
    func startAutomaticBackups() {
        checkAndBackupIfNeeded()
        startDailyTimer()
    }

    /// Performs backup if 24+ hours since last backup
    func checkAndBackupIfNeeded() {
        // Always check backup count so alert can fire even when skipping
        checkBackupCount()

        let lastBackup = UserDefaults.standard.object(forKey: lastBackupDateKey) as? Date

        if let lastBackup = lastBackup {
            let hoursSinceBackup = Date().timeIntervalSince(lastBackup) / 3600
            if hoursSinceBackup < 24 {
                NSLog("BackupService: Last backup was \(Int(hoursSinceBackup)) hours ago, skipping")
                return
            }
        }

        performBackup()
    }

    /// Manually trigger a backup (for user-initiated backup)
    func performBackup() {
        guard let dbQueue = Database.shared.getQueue(),
              let backupsDir = backupsDirectory else {
            NSLog("BackupService: Cannot backup - database or backups directory not available")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let backupPath = backupsDir.appendingPathComponent("\(dateString).sqlite")

        do {
            // Use GRDB's backup API for safe WAL handling
            try dbQueue.backup(to: DatabaseQueue(path: backupPath.path))

            UserDefaults.standard.set(Date(), forKey: lastBackupDateKey)
            NSLog("BackupService: Backup created at \(backupPath.path)")

            // Check if we've exceeded threshold
            checkBackupCount()
        } catch {
            NSLog("BackupService: Backup failed - \(error)")
        }
    }

    /// Returns list of all backups sorted by date (newest first)
    func listBackups() -> [BackupInfo] {
        guard let backupsDir = backupsDirectory else { return [] }

        do {
            let files = try fileManager.contentsOfDirectory(at: backupsDir, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])

            return files
                .filter { $0.pathExtension == "sqlite" }
                .compactMap { url -> BackupInfo? in
                    guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
                          let size = attributes[.size] as? Int64,
                          let date = attributes[.creationDate] as? Date else {
                        return nil
                    }
                    return BackupInfo(url: url, date: date, size: size)
                }
                .sorted { $0.date > $1.date }
        } catch {
            NSLog("BackupService: Failed to list backups - \(error)")
            return []
        }
    }

    /// Schedule a restore from a backup file (happens on next app launch)
    func restore(from backup: BackupInfo) throws {
        // Verify backup file exists
        guard fileManager.fileExists(atPath: backup.url.path) else {
            NSLog("BackupService: Backup file not found at \(backup.url.path)")
            throw BackupError.backupNotFound
        }

        // Schedule the restore for next launch (before database opens)
        Database.scheduleRestore(from: backup.url.path)
        NSLog("BackupService: Scheduled restore from \(backup.url.lastPathComponent)")
    }

    /// Delete specific backups
    func deleteBackups(_ backups: [BackupInfo]) {
        for backup in backups {
            do {
                try fileManager.removeItem(at: backup.url)
                NSLog("BackupService: Deleted backup \(backup.url.lastPathComponent)")
            } catch {
                NSLog("BackupService: Failed to delete backup - \(error)")
            }
        }
        checkBackupCount()
    }

    // MARK: - Private Methods

    private func startDailyTimer() {
        // Fire every 24 hours - uses checkAndBackupIfNeeded so manual backups reset the clock
        timerCancellable = Timer.publish(every: 24 * 60 * 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkAndBackupIfNeeded()
            }
        NSLog("BackupService: 24-hour backup timer started")
    }

    private func checkBackupCount() {
        let backups = listBackups()
        backupCount = backups.count

        DispatchQueue.main.async {
            if self.backupCount > self.backupThresholdCount {
                self.showBackupCleanupPrompt = true
            } else {
                // Reset prompt when count drops below threshold
                self.showBackupCleanupPrompt = false
            }
        }
    }
}

// MARK: - Supporting Types

struct BackupInfo: Identifiable {
    let id = UUID()
    let url: URL
    let date: Date
    let size: Int64

    var filename: String {
        url.deletingPathExtension().lastPathComponent
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

enum BackupError: Error, LocalizedError {
    case backupNotFound

    var errorDescription: String? {
        switch self {
        case .backupNotFound:
            return "Backup file not found"
        }
    }
}
