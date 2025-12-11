import XCTest
import CloudKit
@testable import DirectGTD

/// Tests to verify mock infrastructure works correctly
final class MockInfrastructureTests: XCTestCase {
    var mockManager: MockCloudKitManager!
    var mockStore: MockSyncMetadataStore!

    override func setUp() {
        super.setUp()
        mockManager = MockCloudKitManager()
        mockStore = MockSyncMetadataStore()
    }

    override func tearDown() {
        mockManager = nil
        mockStore = nil
        super.tearDown()
    }

    // MARK: - MockCloudKitManager Tests

    func testMockManagerDefaultState() {
        XCTAssertEqual(mockManager.accountStatus, .couldNotDetermine)
        XCTAssertFalse(mockManager.isZoneReady)
        XCTAssertFalse(mockManager.isAccountAvailable)
    }

    func testMockManagerConfigureForSuccess() async throws {
        mockManager.configureForSuccess()

        try await mockManager.initialize()

        XCTAssertTrue(mockManager.isAccountAvailable)
        XCTAssertTrue(mockManager.isZoneReady)
        XCTAssertEqual(mockManager.initializeCallCount, 1)
        XCTAssertEqual(mockManager.checkAccountStatusCallCount, 1)
        XCTAssertEqual(mockManager.ensureZoneExistsCallCount, 1)
    }

    func testMockManagerConfigureForNoAccount() async {
        mockManager.configureForNoAccount()

        let error = await asyncAssertThrows(CloudKitError.self) {
            try await self.mockManager.initialize()
        }

        if case .accountNotAvailable(let message) = error {
            XCTAssertTrue(message.contains("No iCloud account"))
        } else {
            XCTFail("Expected accountNotAvailable error")
        }
    }

    func testMockManagerConfigureForZoneFailure() async {
        mockManager.configureForZoneFailure()
        mockManager.mockAccountStatus = .available

        let error = await asyncAssertThrows(CloudKitError.self) {
            try await self.mockManager.initialize()
        }

        if case .zoneNotReady = error {
            // Expected error type
        } else {
            XCTFail("Expected zoneNotReady error")
        }
    }

    func testMockManagerReset() async throws {
        // Set some state
        _ = try await mockManager.checkAccountStatus()
        mockManager.shouldFailZoneCreation = true

        // Reset
        mockManager.reset()

        // Verify everything is back to default
        XCTAssertEqual(mockManager.accountStatus, .couldNotDetermine)
        XCTAssertFalse(mockManager.isZoneReady)
        XCTAssertEqual(mockManager.checkAccountStatusCallCount, 0)
        XCTAssertFalse(mockManager.shouldFailZoneCreation)
    }

    func testMockManagerRecordIDCreation() {
        let recordID = mockManager.recordID(for: "test-123")

        XCTAssertEqual(recordID.recordName, "test-123")
        XCTAssertEqual(recordID.zoneID.zoneName, "TestZone")
    }

    func testMockManagerNewRecordCreation() {
        let record = mockManager.newRecord(type: "Item", recordName: "item-1")

        XCTAssertEqual(record.recordType, "Item")
        XCTAssertEqual(record.recordID.recordName, "item-1")
        XCTAssertEqual(record.recordID.zoneID.zoneName, "TestZone")
    }

    // MARK: - MockSyncMetadataStore Tests

    func testMockStoreDataOperations() throws {
        let testData = "test".data(using: .utf8)!

        try mockStore.setData(key: "key1", value: testData)
        let retrieved = try mockStore.getData(key: "key1")

        XCTAssertEqual(retrieved, testData)
        XCTAssertEqual(mockStore.setDataCallCount, 1)
        XCTAssertEqual(mockStore.getDataCallCount, 1)
    }

    func testMockStoreStringOperations() throws {
        try mockStore.setString(key: "key1", value: "hello")
        let retrieved = try mockStore.getString(key: "key1")

        XCTAssertEqual(retrieved, "hello")
        XCTAssertEqual(mockStore.setStringCallCount, 1)
        XCTAssertEqual(mockStore.getStringCallCount, 1)
    }

    func testMockStoreIntOperations() throws {
        try mockStore.setInt(key: "count", value: 42)
        let retrieved = try mockStore.getInt(key: "count")

        XCTAssertEqual(retrieved, 42)
        XCTAssertEqual(mockStore.setIntCallCount, 1)
        XCTAssertEqual(mockStore.getIntCallCount, 1)
    }

    func testMockStoreChangeTokens() throws {
        let tokenData = "token".data(using: .utf8)!

        try mockStore.setZoneChangeToken(tokenData)
        let retrieved = try mockStore.getZoneChangeToken()

        XCTAssertEqual(retrieved, tokenData)
    }

    func testMockStoreDeviceId() throws {
        let deviceId = try mockStore.getOrCreateDeviceId()

        XCTAssertFalse(deviceId.isEmpty)
        XCTAssertNotNil(UUID(uuidString: deviceId))

        // Should return same ID on second call
        let deviceId2 = try mockStore.getOrCreateDeviceId()
        XCTAssertEqual(deviceId, deviceId2)
    }

    func testMockStoreClearAll() throws {
        try mockStore.setString(key: "key1", value: "value1")
        try mockStore.setString(key: "key2", value: "value2")

        try mockStore.clearAll()

        let keys = try mockStore.getAllKeys()
        XCTAssertTrue(keys.isEmpty)
    }

    func testMockStoreReset() throws {
        try mockStore.setString(key: "key1", value: "value1")
        mockStore.shouldThrowError = true

        mockStore.reset()

        XCTAssertTrue(try mockStore.getAllKeys().isEmpty)
        XCTAssertFalse(mockStore.shouldThrowError)
        XCTAssertEqual(mockStore.getStringCallCount, 0)
    }

    func testMockStoreErrorThrow() {
        mockStore.shouldThrowError = true

        XCTAssertThrowsError(try mockStore.setString(key: "key", value: "value"))
        XCTAssertThrowsError(try mockStore.getString(key: "key"))
    }

    // MARK: - Async Test Helpers Tests

    func testAsyncWaitFor() async throws {
        var value = false

        Task {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            value = true
        }

        try await AsyncTestHelpers.waitFor(timeout: 1.0) {
            value == true
        }

        XCTAssertTrue(value)
    }

    func testAsyncWaitForValue() async throws {
        var counter = 0

        Task {
            for i in 1...5 {
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                counter = i
            }
        }

        try await AsyncTestHelpers.waitForValue(
            timeout: 1.0,
            getValue: { counter },
            expectedValue: 5
        )

        XCTAssertEqual(counter, 5)
    }

    func testAsyncTimeout() async {
        do {
            _ = try await AsyncTestHelpers.withTimeout(0.1) {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                return "done"
            }
            XCTFail("Should have timed out")
        } catch {
            // Expected timeout
            XCTAssertTrue(error is AsyncTestError)
        }
    }

    func testAsyncNoTimeout() async throws {
        let result = try await AsyncTestHelpers.withTimeout(1.0) {
            try await Task.sleep(nanoseconds: 10_000_000) // 0.01 second
            return "success"
        }

        XCTAssertEqual(result, "success")
    }
}
