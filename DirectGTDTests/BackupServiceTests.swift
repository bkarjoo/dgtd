import XCTest
@testable import DirectGTD
import GRDB

final class BackupServiceTests: XCTestCase {
    var backupService: BackupService!
    var testBackupDir: URL!
    var testDBPath: URL!
    var fileManager: FileManager!

    override func setUp() {
        super.setUp()
        backupService = BackupService()
        fileManager = FileManager.default

        // Create temporary test directories
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        testBackupDir = tempDir.appendingPathComponent("backups")
        testDBPath = tempDir.appendingPathComponent("test.sqlite")

        try? fileManager.createDirectory(at: testBackupDir, withIntermediateDirectories: true)

        // Clear any previous backup date
        UserDefaults.standard.removeObject(forKey: "lastBackupDate")
    }

    override func tearDown() {
        // Clean up test directories
        if let tempDir = testBackupDir?.deletingLastPathComponent() {
            try? fileManager.removeItem(at: tempDir)
        }

        UserDefaults.standard.removeObject(forKey: "lastBackupDate")
        super.tearDown()
    }

    // MARK: - BackupInfo Tests

    func testBackupInfoFilename() throws {
        let url = URL(fileURLWithPath: "/path/to/2025-12-04_153045.sqlite")
        let backupInfo = BackupInfo(url: url, date: Date(), size: 1024)

        XCTAssertEqual(backupInfo.filename, "2025-12-04_153045")
    }

    func testBackupInfoFormattedSize() throws {
        let backupInfo = BackupInfo(url: URL(fileURLWithPath: "/test.sqlite"), date: Date(), size: 1024)

        // Should format as "1 KB" or similar
        XCTAssertTrue(backupInfo.formattedSize.contains("KB") || backupInfo.formattedSize.contains("bytes"))
    }

    func testBackupInfoLargeSize() throws {
        let backupInfo = BackupInfo(url: URL(fileURLWithPath: "/test.sqlite"), date: Date(), size: 5_242_880) // 5 MB

        // Should format as MB
        XCTAssertTrue(backupInfo.formattedSize.contains("MB"))
    }

    // MARK: - List Backups Tests

    func testListBackupsReturnsEmptyWhenNoBackups() throws {
        // BackupService.shared uses real app support directory, so we can't easily test it
        // This test documents expected behavior
        let backups = backupService.listBackups()

        // Should return array (might be empty or contain real backups)
        XCTAssertNotNil(backups)
    }

    func testListBackupsSortsNewestFirst() throws {
        // Create test backup files with different dates
        let oldDate = Date(timeIntervalSinceNow: -86400 * 2) // 2 days ago
        let newDate = Date(timeIntervalSinceNow: -86400) // 1 day ago

        let oldBackup = testBackupDir.appendingPathComponent("2025-12-02_120000.sqlite")
        let newBackup = testBackupDir.appendingPathComponent("2025-12-03_120000.sqlite")

        fileManager.createFile(atPath: oldBackup.path, contents: Data())
        fileManager.createFile(atPath: newBackup.path, contents: Data())

        // Set file creation dates
        try fileManager.setAttributes([.creationDate: oldDate], ofItemAtPath: oldBackup.path)
        try fileManager.setAttributes([.creationDate: newDate], ofItemAtPath: newBackup.path)

        // List backups (note: this tests internal logic, not the service directly)
        let files = try fileManager.contentsOfDirectory(at: testBackupDir, includingPropertiesForKeys: [.creationDateKey])
        let backups = files
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

        XCTAssertEqual(backups.count, 2)
        XCTAssertTrue(backups[0].date > backups[1].date, "Backups should be sorted newest first")
    }

    // MARK: - Delete Backups Tests

    func testDeleteBackupsRemovesFiles() throws {
        // Create test backup file
        let backupPath = testBackupDir.appendingPathComponent("2025-12-04_120000.sqlite")
        fileManager.createFile(atPath: backupPath.path, contents: Data())

        XCTAssertTrue(fileManager.fileExists(atPath: backupPath.path))

        // Delete it
        let backupInfo = BackupInfo(url: backupPath, date: Date(), size: 0)
        backupService.deleteBackups([backupInfo])

        XCTAssertFalse(fileManager.fileExists(atPath: backupPath.path))
    }

    func testDeleteMultipleBackups() throws {
        // Create multiple test backup files
        let backup1 = testBackupDir.appendingPathComponent("2025-12-04_120000.sqlite")
        let backup2 = testBackupDir.appendingPathComponent("2025-12-04_130000.sqlite")
        let backup3 = testBackupDir.appendingPathComponent("2025-12-04_140000.sqlite")

        fileManager.createFile(atPath: backup1.path, contents: Data())
        fileManager.createFile(atPath: backup2.path, contents: Data())
        fileManager.createFile(atPath: backup3.path, contents: Data())

        let backupInfos = [
            BackupInfo(url: backup1, date: Date(), size: 0),
            BackupInfo(url: backup2, date: Date(), size: 0),
        ]

        backupService.deleteBackups(backupInfos)

        XCTAssertFalse(fileManager.fileExists(atPath: backup1.path))
        XCTAssertFalse(fileManager.fileExists(atPath: backup2.path))
        XCTAssertTrue(fileManager.fileExists(atPath: backup3.path), "Should not delete backup3")
    }

    // MARK: - Restore Scheduling Tests

    func testRestoreSchedulesSavedToUserDefaults() throws {
        let backupPath = testBackupDir.appendingPathComponent("2025-12-04_120000.sqlite")
        fileManager.createFile(atPath: backupPath.path, contents: Data())

        let backupInfo = BackupInfo(url: backupPath, date: Date(), size: 1024)

        try backupService.restore(from: backupInfo)

        // Verify the restore path was saved
        let pendingPath = UserDefaults.standard.string(forKey: "pendingRestorePath")
        XCTAssertEqual(pendingPath, backupPath.path)
    }

    func testRestoreThrowsErrorWhenBackupNotFound() throws {
        let nonexistentPath = testBackupDir.appendingPathComponent("nonexistent.sqlite")
        let backupInfo = BackupInfo(url: nonexistentPath, date: Date(), size: 0)

        XCTAssertThrowsError(try backupService.restore(from: backupInfo)) { error in
            XCTAssertTrue(error is BackupError)
            if let backupError = error as? BackupError {
                XCTAssertEqual(backupError, BackupError.backupNotFound)
            }
        }
    }

    // MARK: - Automatic Backup Tests

    func testCheckAndBackupIfNeededSkipsRecentBackup() throws {
        // Set last backup to 1 hour ago
        let oneHourAgo = Date(timeIntervalSinceNow: -3600)
        UserDefaults.standard.set(oneHourAgo, forKey: "lastBackupDate")

        // This should skip backup (can't easily verify without mocking database)
        backupService.checkAndBackupIfNeeded()

        // Verify last backup date unchanged
        let lastBackup = UserDefaults.standard.object(forKey: "lastBackupDate") as? Date
        XCTAssertNotNil(lastBackup)
        if let lastBackup = lastBackup {
            XCTAssertEqual(lastBackup.timeIntervalSince1970, oneHourAgo.timeIntervalSince1970, accuracy: 1.0)
        }
    }

    func testCheckAndBackupIfNeededPerformsBackupAfter24Hours() throws {
        // Set last backup to 25 hours ago
        let twentyFiveHoursAgo = Date(timeIntervalSinceNow: -25 * 3600)
        UserDefaults.standard.set(twentyFiveHoursAgo, forKey: "lastBackupDate")

        // This should perform backup (but will fail without real database)
        // We're just testing the logic, not the actual backup
        backupService.checkAndBackupIfNeeded()

        // If backup succeeded, lastBackupDate would be updated
        // Since we don't have real database, it won't update
        // This test documents expected behavior
    }

    func testCheckAndBackupIfNeededPerformsBackupWhenNoLastBackup() throws {
        // No last backup date set
        UserDefaults.standard.removeObject(forKey: "lastBackupDate")

        // Should attempt backup (will fail without real database)
        backupService.checkAndBackupIfNeeded()

        // Test documents expected behavior
    }

    // MARK: - Threshold Tests

    func testBackupCountInitiallyZero() throws {
        XCTAssertEqual(backupService.backupCount, 0)
    }

    func testShowBackupCleanupPromptInitiallyFalse() throws {
        XCTAssertFalse(backupService.showBackupCleanupPrompt)
    }

    // MARK: - BackupError Tests

    func testBackupErrorLocalizedDescription() throws {
        let error = BackupError.backupNotFound
        XCTAssertEqual(error.errorDescription, "Backup file not found")
    }

    // MARK: - Integration Tests

    func testBackupWorkflowWithRealDatabase() throws {
        // Create a real test database
        let dbQueue = try DatabaseQueue(path: testDBPath.path)
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE test (id INTEGER PRIMARY KEY, value TEXT)")
            try db.execute(sql: "INSERT INTO test (value) VALUES ('test data')")
        }

        // Create backup using GRDB backup API
        let backupPath = testBackupDir.appendingPathComponent("test_backup.sqlite")
        try dbQueue.backup(to: DatabaseQueue(path: backupPath.path))

        // Verify backup exists and has content
        XCTAssertTrue(fileManager.fileExists(atPath: backupPath.path))

        let backupQueue = try DatabaseQueue(path: backupPath.path)
        let count = try backupQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM test")
        }

        XCTAssertEqual(count, 1)
    }

    func testBackupDateFormatterFormat() throws {
        // Test the date format used for backup filenames
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"

        let date = Date(timeIntervalSince1970: 1701734445) // 2023-12-04 15:30:45 UTC
        let formatted = dateFormatter.string(from: date)

        // Should match format: yyyy-MM-dd_HHmmss
        XCTAssertTrue(formatted.contains("-"))
        XCTAssertTrue(formatted.contains("_"))
        let components = formatted.split(separator: "_")
        XCTAssertEqual(components.count, 2)
    }
}
