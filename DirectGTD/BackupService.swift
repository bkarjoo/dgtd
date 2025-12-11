import DirectGTDCore
import Foundation
import GRDB
import Combine

class BackupService: ObservableObject {
    static let shared = BackupService()

    private let fileManager: FileManager
    private let backupThresholdCount = 30
    private var hourlyTimerCancellable: AnyCancellable?
    private var dailyTimerCancellable: AnyCancellable?
    private let databaseProvider: DatabaseProvider
    private let userDefaults: UserDefaults
    private let backupsDirectory: URL  // Daily backups
    private let hourlyBackupsDirectory: URL  // Hourly backups (auto-deleted after 2 days)

    // Published for UI to show prompt
    @Published var showBackupCleanupPrompt = false
    @Published var backupCount = 0

    private let lastDailyBackupDateKey = "lastDailyBackupDate"
    private let lastHourlyBackupDateKey = "lastHourlyBackupDate"

    init(
        databaseProvider: DatabaseProvider = Database.shared,
        backupsDirectory: URL? = nil,
        hourlyBackupsDirectory: URL? = nil,
        userDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) {
        self.databaseProvider = databaseProvider
        self.userDefaults = userDefaults
        self.fileManager = fileManager

        // Use provided directory or default to production path
        if let providedDir = backupsDirectory {
            self.backupsDirectory = providedDir
        } else {
            guard let appSupport = try? fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ) else {
                fatalError("Could not access application support directory")
            }
            self.backupsDirectory = appSupport.appendingPathComponent("DirectGTD/backups/daily")
        }

        // Hourly backups directory
        if let providedHourlyDir = hourlyBackupsDirectory {
            self.hourlyBackupsDirectory = providedHourlyDir
        } else {
            guard let appSupport = try? fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ) else {
                fatalError("Could not access application support directory")
            }
            self.hourlyBackupsDirectory = appSupport.appendingPathComponent("DirectGTD/backups/hourly")
        }

        // Create backups directories if they don't exist
        try? fileManager.createDirectory(at: self.backupsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: self.hourlyBackupsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// Called on app launch - checks if backups needed and starts timers
    func startAutomaticBackups() {
        checkAndPerformDailyBackupIfNeeded()
        checkAndPerformHourlyBackupIfNeeded()
        cleanupOldHourlyBackups()
        startDailyTimer()
        startHourlyTimer()
    }

    /// Performs daily backup if 24+ hours since last daily backup
    func checkAndPerformDailyBackupIfNeeded() {
        // Always check backup count so alert can fire even when skipping
        checkBackupCount()

        let lastBackup = userDefaults.object(forKey: lastDailyBackupDateKey) as? Date

        if let lastBackup = lastBackup {
            let hoursSinceBackup = Date().timeIntervalSince(lastBackup) / 3600
            if hoursSinceBackup < 24 {
                NSLog("BackupService: Last daily backup was \(Int(hoursSinceBackup)) hours ago, skipping")
                return
            }
        }

        performDailyBackup()
    }

    /// Performs hourly backup if 1+ hours since last hourly backup
    func checkAndPerformHourlyBackupIfNeeded() {
        let lastBackup = userDefaults.object(forKey: lastHourlyBackupDateKey) as? Date

        if let lastBackup = lastBackup {
            let minutesSinceBackup = Date().timeIntervalSince(lastBackup) / 60
            if minutesSinceBackup < 60 {
                NSLog("BackupService: Last hourly backup was \(Int(minutesSinceBackup)) minutes ago, skipping")
                return
            }
        }

        performHourlyBackup()
    }

    /// Manually trigger a daily backup (for user-initiated backup)
    func performBackup() {
        performDailyBackup()
    }

    /// Perform a daily backup
    private func performDailyBackup() {
        guard let dbQueue = databaseProvider.getQueue() else {
            NSLog("BackupService: Cannot backup - database not available")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let backupPath = backupsDirectory.appendingPathComponent("\(dateString).sqlite")

        do {
            // Use GRDB's backup API for safe WAL handling
            try dbQueue.backup(to: DatabaseQueue(path: backupPath.path))

            userDefaults.set(Date(), forKey: lastDailyBackupDateKey)
            NSLog("BackupService: Daily backup created at \(backupPath.path)")

            // Check if we've exceeded threshold
            checkBackupCount()
        } catch {
            NSLog("BackupService: Daily backup failed - \(error)")
        }
    }

    /// Perform an hourly backup
    private func performHourlyBackup() {
        guard let dbQueue = databaseProvider.getQueue() else {
            NSLog("BackupService: Cannot backup - database not available")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let backupPath = hourlyBackupsDirectory.appendingPathComponent("\(dateString).sqlite")

        do {
            // Use GRDB's backup API for safe WAL handling
            try dbQueue.backup(to: DatabaseQueue(path: backupPath.path))

            userDefaults.set(Date(), forKey: lastHourlyBackupDateKey)
            NSLog("BackupService: Hourly backup created at \(backupPath.path)")
        } catch {
            NSLog("BackupService: Hourly backup failed - \(error)")
        }
    }

    /// Delete hourly backups older than 2 days
    private func cleanupOldHourlyBackups() {
        let twoDaysAgo = Date().addingTimeInterval(-2 * 24 * 60 * 60)

        do {
            let files = try fileManager.contentsOfDirectory(at: hourlyBackupsDirectory, includingPropertiesForKeys: [.creationDateKey])

            for file in files where file.pathExtension == "sqlite" {
                if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
                   let creationDate = attributes[.creationDate] as? Date,
                   creationDate < twoDaysAgo {
                    try fileManager.removeItem(at: file)
                    NSLog("BackupService: Deleted old hourly backup \(file.lastPathComponent)")
                }
            }
        } catch {
            NSLog("BackupService: Failed to cleanup old hourly backups - \(error)")
        }
    }

    /// Returns list of daily backups sorted by date (newest first)
    func listBackups() -> [BackupInfo] {
        return listBackupsInDirectory(backupsDirectory, type: .daily)
    }

    /// Returns list of hourly backups sorted by date (newest first)
    func listHourlyBackups() -> [BackupInfo] {
        return listBackupsInDirectory(hourlyBackupsDirectory, type: .hourly)
    }

    /// Returns list of all backups (daily + hourly) sorted by date (newest first)
    func listAllBackups() -> [BackupInfo] {
        let daily = listBackupsInDirectory(backupsDirectory, type: .daily)
        let hourly = listBackupsInDirectory(hourlyBackupsDirectory, type: .hourly)
        return (daily + hourly).sorted { $0.date > $1.date }
    }

    private func listBackupsInDirectory(_ directory: URL, type: BackupType) -> [BackupInfo] {
        do {
            let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])

            return files
                .filter { $0.pathExtension == "sqlite" }
                .compactMap { url -> BackupInfo? in
                    guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
                          let size = attributes[.size] as? Int64,
                          let date = attributes[.creationDate] as? Date else {
                        return nil
                    }
                    return BackupInfo(url: url, date: date, size: size, type: type)
                }
                .sorted { $0.date > $1.date }
        } catch {
            NSLog("BackupService: Failed to list backups in \(directory.path) - \(error)")
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
        // Fire every 24 hours - uses checkAndPerformDailyBackupIfNeeded so manual backups reset the clock
        dailyTimerCancellable = Timer.publish(every: 24 * 60 * 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkAndPerformDailyBackupIfNeeded()
            }
        NSLog("BackupService: 24-hour backup timer started")
    }

    private func startHourlyTimer() {
        // Fire every hour for hourly backups, also cleanup old ones
        hourlyTimerCancellable = Timer.publish(every: 60 * 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkAndPerformHourlyBackupIfNeeded()
                self?.cleanupOldHourlyBackups()
            }
        NSLog("BackupService: 1-hour backup timer started")
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

enum BackupType {
    case daily
    case hourly
}

struct BackupInfo: Identifiable {
    let id = UUID()
    let url: URL
    let date: Date
    let size: Int64
    let type: BackupType

    init(url: URL, date: Date, size: Int64, type: BackupType = .daily) {
        self.url = url
        self.date = date
        self.size = size
        self.type = type
    }

    var filename: String {
        url.deletingPathExtension().lastPathComponent
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var typeLabel: String {
        switch type {
        case .daily: return "Daily"
        case .hourly: return "Hourly"
        }
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
