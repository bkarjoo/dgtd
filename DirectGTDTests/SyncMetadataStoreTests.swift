import DirectGTDCore
import XCTest
import GRDB
@testable import DirectGTD

final class SyncMetadataStoreTests: XCTestCase {
    private var testDB: TestDatabaseWrapper!
    private var metadataStore: SyncMetadataStore!

    override func setUp() {
        super.setUp()
        testDB = TestDatabaseWrapper()
        metadataStore = SyncMetadataStore(dbQueue: testDB.getQueue()!)
    }

    override func tearDown() {
        metadataStore = nil
        testDB = nil
        super.tearDown()
    }

    // MARK: - Generic Data Get/Set Tests

    func testSetAndGetDataValue() throws {
        let testData = "test-data".data(using: .utf8)!

        try metadataStore.setData(key: "test-key", value: testData)

        let retrieved = try metadataStore.getData(key: "test-key")
        XCTAssertEqual(retrieved, testData)
    }

    func testGetDataReturnsNilForNonexistentKey() throws {
        let retrieved = try metadataStore.getData(key: "nonexistent-key")
        XCTAssertNil(retrieved)
    }

    func testSetDataWithNilDeletesKey() throws {
        let testData = "test-data".data(using: .utf8)!
        try metadataStore.setData(key: "test-key", value: testData)

        try metadataStore.setData(key: "test-key", value: nil)

        let retrieved = try metadataStore.getData(key: "test-key")
        XCTAssertNil(retrieved)
    }

    func testSetDataReplacesExistingValue() throws {
        let data1 = "first".data(using: .utf8)!
        let data2 = "second".data(using: .utf8)!

        try metadataStore.setData(key: "test-key", value: data1)
        try metadataStore.setData(key: "test-key", value: data2)

        let retrieved = try metadataStore.getData(key: "test-key")
        XCTAssertEqual(retrieved, data2)
    }

    // MARK: - String Get/Set Tests

    func testSetAndGetStringValue() throws {
        try metadataStore.setString(key: "string-key", value: "test-string")

        let retrieved = try metadataStore.getString(key: "string-key")
        XCTAssertEqual(retrieved, "test-string")
    }

    func testGetStringReturnsNilForNonexistentKey() throws {
        let retrieved = try metadataStore.getString(key: "nonexistent")
        XCTAssertNil(retrieved)
    }

    func testSetStringWithNilDeletesKey() throws {
        try metadataStore.setString(key: "string-key", value: "test")

        try metadataStore.setString(key: "string-key", value: nil)

        let retrieved = try metadataStore.getString(key: "string-key")
        XCTAssertNil(retrieved)
    }

    func testSetStringWithEmptyString() throws {
        try metadataStore.setString(key: "empty-key", value: "")

        let retrieved = try metadataStore.getString(key: "empty-key")
        XCTAssertEqual(retrieved, "")
    }

    // MARK: - Int Get/Set Tests

    func testSetAndGetIntValue() throws {
        try metadataStore.setInt(key: "int-key", value: 42)

        let retrieved = try metadataStore.getInt(key: "int-key")
        XCTAssertEqual(retrieved, 42)
    }

    func testGetIntReturnsNilForNonexistentKey() throws {
        let retrieved = try metadataStore.getInt(key: "nonexistent")
        XCTAssertNil(retrieved)
    }

    func testSetIntWithNilDeletesKey() throws {
        try metadataStore.setInt(key: "int-key", value: 123)

        try metadataStore.setInt(key: "int-key", value: nil)

        let retrieved = try metadataStore.getInt(key: "int-key")
        XCTAssertNil(retrieved)
    }

    func testSetIntWithZero() throws {
        try metadataStore.setInt(key: "zero-key", value: 0)

        let retrieved = try metadataStore.getInt(key: "zero-key")
        XCTAssertEqual(retrieved, 0)
    }

    func testSetIntWithNegativeValue() throws {
        try metadataStore.setInt(key: "negative-key", value: -100)

        let retrieved = try metadataStore.getInt(key: "negative-key")
        XCTAssertEqual(retrieved, -100)
    }

    // MARK: - Zone Change Token Tests

    func testGetZoneChangeTokenReturnsNilInitially() throws {
        let token = try metadataStore.getZoneChangeToken()
        XCTAssertNil(token)
    }

    func testSetAndGetZoneChangeToken() throws {
        let tokenData = "zone-token-data".data(using: .utf8)!

        try metadataStore.setZoneChangeToken(tokenData)

        let retrieved = try metadataStore.getZoneChangeToken()
        XCTAssertEqual(retrieved, tokenData)
    }

    func testSetZoneChangeTokenWithNil() throws {
        let tokenData = "zone-token".data(using: .utf8)!
        try metadataStore.setZoneChangeToken(tokenData)

        try metadataStore.setZoneChangeToken(nil)

        let retrieved = try metadataStore.getZoneChangeToken()
        XCTAssertNil(retrieved)
    }

    func testZoneChangeTokenPersistsAcrossInstances() throws {
        let tokenData = "persistent-token".data(using: .utf8)!
        try metadataStore.setZoneChangeToken(tokenData)

        // Create new store instance with same database
        let newStore = SyncMetadataStore(dbQueue: testDB.getQueue()!)
        let retrieved = try newStore.getZoneChangeToken()

        XCTAssertEqual(retrieved, tokenData)
    }

    // MARK: - Database Change Token Tests

    func testGetDatabaseChangeTokenReturnsNilInitially() throws {
        let token = try metadataStore.getDatabaseChangeToken()
        XCTAssertNil(token)
    }

    func testSetAndGetDatabaseChangeToken() throws {
        let tokenData = "db-token-data".data(using: .utf8)!

        try metadataStore.setDatabaseChangeToken(tokenData)

        let retrieved = try metadataStore.getDatabaseChangeToken()
        XCTAssertEqual(retrieved, tokenData)
    }

    func testSetDatabaseChangeTokenWithNil() throws {
        let tokenData = "db-token".data(using: .utf8)!
        try metadataStore.setDatabaseChangeToken(tokenData)

        try metadataStore.setDatabaseChangeToken(nil)

        let retrieved = try metadataStore.getDatabaseChangeToken()
        XCTAssertNil(retrieved)
    }

    // MARK: - Last Sync Timestamp Tests

    func testGetLastSyncTimestampReturnsNilInitially() throws {
        let timestamp = try metadataStore.getLastSyncTimestamp()
        XCTAssertNil(timestamp)
    }

    func testSetAndGetLastSyncTimestamp() throws {
        let timestamp = 1234567890

        try metadataStore.setLastSyncTimestamp(timestamp)

        let retrieved = try metadataStore.getLastSyncTimestamp()
        XCTAssertEqual(retrieved, timestamp)
    }

    func testUpdateLastSyncTimestampSetsCurrentTime() throws {
        let beforeUpdate = Int(Date().timeIntervalSince1970)

        try metadataStore.updateLastSyncTimestamp()

        let afterUpdate = Int(Date().timeIntervalSince1970)
        let retrieved = try metadataStore.getLastSyncTimestamp()

        XCTAssertNotNil(retrieved)
        XCTAssertGreaterThanOrEqual(retrieved!, beforeUpdate)
        XCTAssertLessThanOrEqual(retrieved!, afterUpdate)
    }

    func testLastSyncTimestampPersistsAcrossInstances() throws {
        let timestamp = 9876543210
        try metadataStore.setLastSyncTimestamp(timestamp)

        let newStore = SyncMetadataStore(dbQueue: testDB.getQueue()!)
        let retrieved = try newStore.getLastSyncTimestamp()

        XCTAssertEqual(retrieved, timestamp)
    }

    // MARK: - Device ID Tests

    func testGetOrCreateDeviceIdCreatesNewId() throws {
        let deviceId = try metadataStore.getOrCreateDeviceId()

        XCTAssertFalse(deviceId.isEmpty)
        // UUID format check
        XCTAssertNotNil(UUID(uuidString: deviceId))
    }

    func testGetOrCreateDeviceIdReturnsExistingId() throws {
        let firstId = try metadataStore.getOrCreateDeviceId()
        let secondId = try metadataStore.getOrCreateDeviceId()

        XCTAssertEqual(firstId, secondId)
    }

    func testGetOrCreateDeviceIdPersistsAcrossInstances() throws {
        let deviceId = try metadataStore.getOrCreateDeviceId()

        let newStore = SyncMetadataStore(dbQueue: testDB.getQueue()!)
        let retrievedId = try newStore.getOrCreateDeviceId()

        XCTAssertEqual(deviceId, retrievedId)
    }

    // MARK: - Initial Sync Complete Tests

    func testIsInitialSyncCompleteDefaultsToFalse() throws {
        let complete = try metadataStore.isInitialSyncComplete()
        XCTAssertFalse(complete)
    }

    func testSetInitialSyncCompleteToTrue() throws {
        try metadataStore.setInitialSyncComplete(true)

        let complete = try metadataStore.isInitialSyncComplete()
        XCTAssertTrue(complete)
    }

    func testSetInitialSyncCompleteToFalse() throws {
        try metadataStore.setInitialSyncComplete(true)
        try metadataStore.setInitialSyncComplete(false)

        let complete = try metadataStore.isInitialSyncComplete()
        XCTAssertFalse(complete)
    }

    func testInitialSyncCompletePersistsAcrossInstances() throws {
        try metadataStore.setInitialSyncComplete(true)

        let newStore = SyncMetadataStore(dbQueue: testDB.getQueue()!)
        let complete = try newStore.isInitialSyncComplete()

        XCTAssertTrue(complete)
    }

    // MARK: - Sync Enabled Tests

    func testIsSyncEnabledDefaultsToTrue() throws {
        let enabled = try metadataStore.isSyncEnabled()
        XCTAssertTrue(enabled)
    }

    func testSetSyncEnabledToFalse() throws {
        try metadataStore.setSyncEnabled(false)

        let enabled = try metadataStore.isSyncEnabled()
        XCTAssertFalse(enabled)
    }

    func testSetSyncEnabledToTrue() throws {
        try metadataStore.setSyncEnabled(false)
        try metadataStore.setSyncEnabled(true)

        let enabled = try metadataStore.isSyncEnabled()
        XCTAssertTrue(enabled)
    }

    func testSyncEnabledPersistsAcrossInstances() throws {
        try metadataStore.setSyncEnabled(false)

        let newStore = SyncMetadataStore(dbQueue: testDB.getQueue()!)
        let enabled = try newStore.isSyncEnabled()

        XCTAssertFalse(enabled)
    }

    // MARK: - Bulk Operations Tests

    func testClearAllRemovesAllMetadata() throws {
        // Set various metadata
        try metadataStore.setString(key: "key1", value: "value1")
        try metadataStore.setInt(key: "key2", value: 123)
        try metadataStore.setZoneChangeToken("token".data(using: .utf8))
        try metadataStore.setLastSyncTimestamp(9999)
        try metadataStore.setInitialSyncComplete(true)

        try metadataStore.clearAll()

        // Verify all cleared
        XCTAssertNil(try metadataStore.getString(key: "key1"))
        XCTAssertNil(try metadataStore.getInt(key: "key2"))
        XCTAssertNil(try metadataStore.getZoneChangeToken())
        XCTAssertNil(try metadataStore.getLastSyncTimestamp())
        XCTAssertFalse(try metadataStore.isInitialSyncComplete())

        let keys = try metadataStore.getAllKeys()
        XCTAssertTrue(keys.isEmpty)
    }

    func testGetAllKeysReturnsEmptyArrayWhenNoMetadata() throws {
        let keys = try metadataStore.getAllKeys()
        XCTAssertTrue(keys.isEmpty)
    }

    func testGetAllKeysReturnsAllStoredKeys() throws {
        try metadataStore.setString(key: "key1", value: "value1")
        try metadataStore.setString(key: "key2", value: "value2")
        try metadataStore.setString(key: "key3", value: "value3")

        let keys = try metadataStore.getAllKeys()

        XCTAssertEqual(keys.count, 3)
        XCTAssertTrue(keys.contains("key1"))
        XCTAssertTrue(keys.contains("key2"))
        XCTAssertTrue(keys.contains("key3"))
    }

    // MARK: - Integration Tests

    func testMultipleMetadataTypesPersistTogether() throws {
        // Set various types
        let zoneToken = "zone-token".data(using: .utf8)!
        let dbToken = "db-token".data(using: .utf8)!
        let timestamp = 1234567890
        let deviceId = try metadataStore.getOrCreateDeviceId()

        try metadataStore.setZoneChangeToken(zoneToken)
        try metadataStore.setDatabaseChangeToken(dbToken)
        try metadataStore.setLastSyncTimestamp(timestamp)
        try metadataStore.setInitialSyncComplete(true)
        try metadataStore.setSyncEnabled(false)

        // Create new instance
        let newStore = SyncMetadataStore(dbQueue: testDB.getQueue()!)

        // Verify all persisted
        XCTAssertEqual(try newStore.getZoneChangeToken(), zoneToken)
        XCTAssertEqual(try newStore.getDatabaseChangeToken(), dbToken)
        XCTAssertEqual(try newStore.getLastSyncTimestamp(), timestamp)
        XCTAssertEqual(try newStore.getOrCreateDeviceId(), deviceId)
        XCTAssertTrue(try newStore.isInitialSyncComplete())
        XCTAssertFalse(try newStore.isSyncEnabled())
    }

    func testWellKnownKeyConstants() {
        // Verify the key constants are correctly defined
        XCTAssertEqual(SyncMetadataStore.Key.zoneChangeToken, "zone_change_token")
        XCTAssertEqual(SyncMetadataStore.Key.databaseChangeToken, "database_change_token")
        XCTAssertEqual(SyncMetadataStore.Key.lastSyncTimestamp, "last_sync_timestamp")
        XCTAssertEqual(SyncMetadataStore.Key.deviceId, "device_id")
        XCTAssertEqual(SyncMetadataStore.Key.initialSyncComplete, "initial_sync_complete")
        XCTAssertEqual(SyncMetadataStore.Key.syncEnabled, "sync_enabled")
    }
}
