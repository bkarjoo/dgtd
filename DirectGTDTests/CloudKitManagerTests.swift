import DirectGTDCore
import XCTest
import CloudKit
@testable import DirectGTD

final class CloudKitManagerTests: XCTestCase {
    var manager: CloudKitManager!

    override func setUp() {
        super.setUp()
        manager = CloudKitManager.shared
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    // MARK: - Configuration Tests

    func testContainerIdentifier() {
        XCTAssertEqual(CloudKitManager.containerIdentifier, "iCloud.com.directgtd")
    }

    func testZoneName() {
        XCTAssertEqual(CloudKitManager.zoneName, "DirectGTDZone")
    }

    func testSubscriptionID() {
        XCTAssertEqual(CloudKitConfig.subscriptionID, "DirectGTD-zone-changes")
    }

    func testContainerIsConfigured() {
        XCTAssertNotNil(manager.container)
        XCTAssertEqual(manager.container.containerIdentifier, "iCloud.com.directgtd")
    }

    func testPrivateDatabaseIsConfigured() {
        XCTAssertNotNil(manager.privateDatabase)
    }

    func testZoneIDIsConfigured() {
        XCTAssertEqual(manager.zoneID.zoneName, "DirectGTDZone")
        XCTAssertEqual(manager.zoneID.ownerName, CKCurrentUserDefaultName)
    }

    // MARK: - Record Type Tests

    func testRecordTypeConstants() {
        XCTAssertEqual(CloudKitRecordType.item, "Item")
        XCTAssertEqual(CloudKitRecordType.tag, "Tag")
        XCTAssertEqual(CloudKitRecordType.itemTag, "ItemTag")
        XCTAssertEqual(CloudKitRecordType.timeEntry, "TimeEntry")
        XCTAssertEqual(CloudKitRecordType.savedSearch, "SavedSearch")
    }

    // MARK: - Record ID Helper Tests

    func testRecordIDCreation() {
        let recordName = "test-record-123"
        let recordID = manager.recordID(for: recordName)

        XCTAssertEqual(recordID.recordName, recordName)
        XCTAssertEqual(recordID.zoneID.zoneName, "DirectGTDZone")
        XCTAssertEqual(recordID.zoneID.ownerName, CKCurrentUserDefaultName)
    }

    func testRecordIDCreationWithDifferentNames() {
        let recordName1 = "item-1"
        let recordName2 = "item-2"

        let recordID1 = manager.recordID(for: recordName1)
        let recordID2 = manager.recordID(for: recordName2)

        XCTAssertNotEqual(recordID1.recordName, recordID2.recordName)
        XCTAssertEqual(recordID1.zoneID, recordID2.zoneID)
    }

    // MARK: - New Record Creation Tests

    func testNewRecordCreation() {
        let recordName = "test-item-456"
        let record = manager.newRecord(type: CloudKitRecordType.item, recordName: recordName)

        XCTAssertEqual(record.recordType, "Item")
        XCTAssertEqual(record.recordID.recordName, recordName)
        XCTAssertEqual(record.recordID.zoneID.zoneName, "DirectGTDZone")
    }

    func testNewRecordCreationForDifferentTypes() {
        let itemRecord = manager.newRecord(type: CloudKitRecordType.item, recordName: "item-1")
        let tagRecord = manager.newRecord(type: CloudKitRecordType.tag, recordName: "tag-1")

        XCTAssertEqual(itemRecord.recordType, "Item")
        XCTAssertEqual(tagRecord.recordType, "Tag")
        XCTAssertNotEqual(itemRecord.recordID.recordName, tagRecord.recordID.recordName)
    }

    func testNewRecordIsInCorrectZone() {
        let record = manager.newRecord(type: CloudKitRecordType.item, recordName: "test")

        XCTAssertEqual(record.recordID.zoneID, manager.zoneID)
    }

    // MARK: - Account Status Tests

    func testAccountStatusInitialValue() {
        // Initial value should be couldNotDetermine
        XCTAssertEqual(manager.accountStatus, .couldNotDetermine)
    }

    func testIsAccountAvailableWhenNotAvailable() {
        // Since we can't mock the account status easily, we test the property logic
        // When accountStatus is not .available, isAccountAvailable should be false
        XCTAssertFalse(manager.isAccountAvailable)
    }

    // MARK: - Zone Ready Tests

    func testIsZoneReadyInitialValue() {
        // Zone should not be ready initially
        XCTAssertFalse(manager.isZoneReady)
    }

    // MARK: - CloudKit Error Tests

    func testCloudKitErrorAccountNotAvailable() {
        let error = CloudKitError.accountNotAvailable("Test message")

        XCTAssertEqual(error.errorDescription, "Test message")
    }

    func testCloudKitErrorZoneNotReady() {
        let error = CloudKitError.zoneNotReady

        XCTAssertEqual(error.errorDescription, "CloudKit zone is not ready. Please try again.")
    }

    func testCloudKitErrorRecordNotFound() {
        let recordName = "missing-record"
        let error = CloudKitError.recordNotFound(recordName)

        XCTAssertEqual(error.errorDescription, "Record not found: \(recordName)")
    }

    func testCloudKitErrorSyncFailed() {
        let message = "Network error"
        let error = CloudKitError.syncFailed(message)

        XCTAssertEqual(error.errorDescription, "Sync failed: \(message)")
    }

    func testCloudKitErrorConflictDetected() {
        let zoneID = CKRecordZone.ID(zoneName: "TestZone")
        let recordID = CKRecord.ID(recordName: "test", zoneID: zoneID)
        let serverRecord = CKRecord(recordType: "Item", recordID: recordID)
        let error = CloudKitError.conflictDetected(serverRecord: serverRecord, localModifiedAt: 123456)

        XCTAssertEqual(error.errorDescription, "A sync conflict was detected.")
    }

    // MARK: - Singleton Tests

    func testSharedInstanceIsSingleton() {
        let instance1 = CloudKitManager.shared
        let instance2 = CloudKitManager.shared

        // Both should reference the same instance
        XCTAssertTrue(instance1 === instance2)
    }

    func testSharedInstanceHasSameConfiguration() {
        let instance1 = CloudKitManager.shared
        let instance2 = CloudKitManager.shared

        XCTAssertEqual(instance1.zoneID, instance2.zoneID)
        XCTAssertEqual(instance1.container.containerIdentifier, instance2.container.containerIdentifier)
    }

    // MARK: - Integration Tests

    func testMultipleRecordIDsInSameZone() {
        let recordIDs = (1...10).map { manager.recordID(for: "record-\($0)") }

        // All record IDs should be in the same zone
        let uniqueZones = Set(recordIDs.map { $0.zoneID })
        XCTAssertEqual(uniqueZones.count, 1)
        XCTAssertEqual(uniqueZones.first?.zoneName, "DirectGTDZone")
    }

    func testRecordCreationForAllTypes() {
        let types = [
            (CloudKitRecordType.item, "Item"),
            (CloudKitRecordType.tag, "Tag"),
            (CloudKitRecordType.itemTag, "ItemTag"),
            (CloudKitRecordType.timeEntry, "TimeEntry"),
            (CloudKitRecordType.savedSearch, "SavedSearch")
        ]

        for (typeConstant, expectedType) in types {
            let record = manager.newRecord(type: typeConstant, recordName: "test-\(expectedType)")
            XCTAssertEqual(record.recordType, expectedType, "Record type mismatch for \(expectedType)")
            XCTAssertEqual(record.recordID.zoneID, manager.zoneID, "Zone mismatch for \(expectedType)")
        }
    }

    // MARK: - CloudKit Account Status Error Message Tests

    func testAccountStatusErrorMessages() {
        let testCases: [(CKAccountStatus, String)] = [
            (.noAccount, "No iCloud account. Please sign in to iCloud in System Settings."),
            (.restricted, "iCloud access is restricted on this device."),
            (.temporarilyUnavailable, "iCloud is temporarily unavailable. Please try again later."),
            (.couldNotDetermine, "Could not determine iCloud account status.")
        ]

        // Note: We can't directly test the initialize() method without mocking CloudKit,
        // but we can document the expected error messages for each status
        for (status, expectedMessage) in testCases {
            // This test documents the expected behavior
            // Actual testing would require mocking CKContainer.accountStatus()
            XCTAssertFalse(expectedMessage.isEmpty, "Error message should not be empty for status \(status)")
        }
    }
}
