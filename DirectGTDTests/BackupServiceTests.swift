import DirectGTDCore
import XCTest
@testable import DirectGTD
import GRDB

final class BackupServiceTests: XCTestCase {
    var backupService: BackupService!
    var testBackupDir: URL!
    var testDB: TestDatabaseWrapper!
    var testDefaults: UserDefaults!
    let testSuiteName = "BackupServiceTestSuite"

    override func setUp() {
        super.setUp()

        // Create isolated test dependencies
        testDB = TestDatabaseWrapper()
        testDefaults = UserDefaults(suiteName: testSuiteName)!
        testDefaults.removePersistentDomain(forName: testSuiteName)

        // Create temporary backup directory
        testBackupDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("backups")

        // Create BackupService with injected dependencies
        backupService = BackupService(
            databaseProvider: testDB,
            backupsDirectory: testBackupDir,
            userDefaults: testDefaults
        )
    }

    override func tearDown() {
        // Clean up test backup directory
        if let backupDir = testBackupDir?.deletingLastPathComponent() {
            try? FileManager.default.removeItem(at: backupDir)
        }

        // Clear pendingRestorePath to prevent affecting next app launch
        UserDefaults.standard.removeObject(forKey: "pendingRestorePath")

        // Clean up test defaults
        testDefaults.removePersistentDomain(forName: testSuiteName)

        testBackupDir = nil
        testDB = nil
        testDefaults = nil
        backupService = nil

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

        // Should format as KB or bytes
        XCTAssertTrue(backupInfo.formattedSize.contains("KB") || backupInfo.formattedSize.contains("bytes"))
    }

    func testBackupInfoLargeSizeFormatsAsMB() throws {
        let backupInfo = BackupInfo(url: URL(fileURLWithPath: "/test.sqlite"), date: Date(), size: 5_242_880) // 5 MB

        XCTAssertTrue(backupInfo.formattedSize.contains("MB"))
    }

    // MARK: - List Backups Tests

    func testListBackupsReturnsEmptyWhenNoBackups() throws {
        let backups = backupService.listBackups()
        XCTAssertTrue(backups.isEmpty)
    }

    func testListBackupsSortsNewestFirst() throws {
        // Create test database with some data
        guard let dbQueue = testDB.getQueue() else {
            XCTFail("Test database not available")
            return
        }

        try dbQueue.write { db in
            try db.execute(sql: "INSERT INTO items (id, created_at, modified_at) VALUES ('item1', 1, 1)")
        }

        // Create multiple backups
        backupService.performBackup()
        Thread.sleep(forTimeInterval: 0.1) // Ensure different timestamps

        try dbQueue.write { db in
            try db.execute(sql: "INSERT INTO items (id, created_at, modified_at) VALUES ('item2', 2, 2)")
        }

        backupService.performBackup()

        // List backups
        let backups = backupService.listBackups()

        XCTAssertEqual(backups.count, 2)
        // Newest backup should be first
        XCTAssertTrue(backups[0].date >= backups[1].date, "Backups should be sorted newest first")
    }

    func testListBackupsOnlyIncludesSQLiteFiles() throws {
        let fileManager = FileManager.default

        // Create a non-sqlite file in backup directory
        let txtFile = testBackupDir.appendingPathComponent("readme.txt")
        try "test".write(to: txtFile, atomically: true, encoding: .utf8)

        // Create a sqlite backup
        backupService.performBackup()

        let backups = backupService.listBackups()

        // Should only include .sqlite files
        XCTAssertEqual(backups.count, 1)
        XCTAssertTrue(backups[0].url.pathExtension == "sqlite")
    }

    // MARK: - Delete Backups Tests

    func testDeleteBackupsRemovesFiles() throws {
        // Create a backup
        backupService.performBackup()

        var backups = backupService.listBackups()
        XCTAssertEqual(backups.count, 1)

        let backupToDelete = backups[0]

        // Delete it
        backupService.deleteBackups([backupToDelete])

        // Verify it's gone
        backups = backupService.listBackups()
        XCTAssertEqual(backups.count, 0)
    }

    func testDeleteMultipleBackupsKeepsOthers() throws {
        // Create three backups
        backupService.performBackup()
        Thread.sleep(forTimeInterval: 0.1)
        backupService.performBackup()
        Thread.sleep(forTimeInterval: 0.1)
        backupService.performBackup()

        var backups = backupService.listBackups()
        XCTAssertEqual(backups.count, 3)

        // Delete first two
        let toDelete = Array(backups[0...1])
        backupService.deleteBackups(toDelete)

        // Should have one remaining
        backups = backupService.listBackups()
        XCTAssertEqual(backups.count, 1)
    }

    // MARK: - Restore Scheduling Tests

    func testRestoreSchedulesSavesToUserDefaults() throws {
        // Create a backup
        backupService.performBackup()

        let backups = backupService.listBackups()
        XCTAssertEqual(backups.count, 1)

        // Schedule restore
        try backupService.restore(from: backups[0])

        // Verify the restore path was saved to UserDefaults.standard
        // (Database.scheduleRestore uses UserDefaults.standard)
        let pendingPath = UserDefaults.standard.string(forKey: "pendingRestorePath")
        XCTAssertNotNil(pendingPath)
        XCTAssertEqual(pendingPath, backups[0].url.path)
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

    func testCheckAndBackupIfNeededCreatesBackupWhenNoLastBackup() throws {
        // No last backup date set
        let initialBackups = backupService.listBackups()
        XCTAssertEqual(initialBackups.count, 0)

        // Should create backup
        backupService.checkAndPerformDailyBackupIfNeeded()

        let backups = backupService.listBackups()
        XCTAssertEqual(backups.count, 1)

        // Should have set lastDailyBackupDate
        let lastBackup = testDefaults.object(forKey: "lastDailyBackupDate") as? Date
        XCTAssertNotNil(lastBackup)
    }

    func testCheckAndBackupIfNeededSkipsRecentBackup() throws {
        // Set last backup to 1 hour ago
        let oneHourAgo = Date(timeIntervalSinceNow: -3600)
        testDefaults.set(oneHourAgo, forKey: "lastDailyBackupDate")

        let initialBackups = backupService.listBackups()
        XCTAssertEqual(initialBackups.count, 0)

        // Should skip backup
        backupService.checkAndPerformDailyBackupIfNeeded()

        let backups = backupService.listBackups()
        XCTAssertEqual(backups.count, 0)

        // Last backup date should be unchanged
        let lastBackup = testDefaults.object(forKey: "lastDailyBackupDate") as? Date
        XCTAssertNotNil(lastBackup)
        XCTAssertEqual(lastBackup!.timeIntervalSince1970, oneHourAgo.timeIntervalSince1970, accuracy: 1.0)
    }

    func testCheckAndBackupIfNeededPerformsBackupAfter24Hours() throws {
        // Set last backup to 25 hours ago
        let twentyFiveHoursAgo = Date(timeIntervalSinceNow: -25 * 3600)
        testDefaults.set(twentyFiveHoursAgo, forKey: "lastDailyBackupDate")

        let initialBackups = backupService.listBackups()
        XCTAssertEqual(initialBackups.count, 0)

        // Should perform backup
        backupService.checkAndPerformDailyBackupIfNeeded()

        let backups = backupService.listBackups()
        XCTAssertEqual(backups.count, 1)

        // Last backup date should be updated
        let lastBackup = testDefaults.object(forKey: "lastDailyBackupDate") as? Date
        XCTAssertNotNil(lastBackup)
        XCTAssertTrue(lastBackup! > twentyFiveHoursAgo)
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
        guard let dbQueue = testDB.getQueue() else {
            XCTFail("Test database not available")
            return
        }

        // Add some test data
        try dbQueue.write { db in
            try db.execute(sql: "INSERT INTO items (id, created_at, modified_at) VALUES ('test1', 1, 1)")
            try db.execute(sql: "INSERT INTO items (id, created_at, modified_at) VALUES ('test2', 2, 2)")
        }

        // Perform backup
        backupService.performBackup()

        // Verify backup exists
        let backups = backupService.listBackups()
        XCTAssertEqual(backups.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: backups[0].url.path))

        // Verify backup contains data
        let backupQueue = try DatabaseQueue(path: backups[0].url.path)
        let count = try backupQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")
        }
        XCTAssertEqual(count, 2)
    }

    func testBackupDateFormatterCreatesValidFilenames() throws {
        backupService.performBackup()

        let backups = backupService.listBackups()
        XCTAssertEqual(backups.count, 1)

        let filename = backups[0].filename

        // Should match format: yyyy-MM-dd_HHmmss
        XCTAssertTrue(filename.contains("-"))
        XCTAssertTrue(filename.contains("_"))

        let components = filename.split(separator: "_")
        XCTAssertEqual(components.count, 2, "Filename should have date and time separated by underscore")

        let dateComponent = String(components[0])
        XCTAssertEqual(dateComponent.count, 10, "Date component should be yyyy-MM-dd (10 chars)")

        let timeComponent = String(components[1])
        XCTAssertEqual(timeComponent.count, 6, "Time component should be HHmmss (6 chars)")
    }
}
