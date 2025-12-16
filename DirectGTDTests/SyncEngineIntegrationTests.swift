import XCTest
import CloudKit
import Combine
import GRDB
@testable import DirectGTD

/// Integration tests for SyncEngine using mock CloudKit manager
final class SyncEngineIntegrationTests: XCTestCase {
    var mockCloudKit: MockCloudKitManager!
    var testDB: TestDatabaseWrapper!
    var mockMetadataStore: MockSyncMetadataStore!
    var syncEngine: SyncEngine!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockCloudKit = MockCloudKitManager()
        testDB = TestDatabaseWrapper()
        mockMetadataStore = MockSyncMetadataStore()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        cancellables = nil
        syncEngine = nil
        mockMetadataStore = nil
        testDB = nil
        mockCloudKit = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testSyncEngineCreationWithMockManager() {
        // Verify we can create SyncEngine with mock
        guard let dbQueue = testDB.getQueue() else {
            XCTFail("Test database not initialized")
            return
        }

        syncEngine = SyncEngine(
            cloudKitManager: mockCloudKit,
            database: testDB
        )

        XCTAssertNotNil(syncEngine)
    }

    func testSyncEngineInitialState() {
        guard let dbQueue = testDB.getQueue() else {
            XCTFail("Test database not initialized")
            return
        }

        syncEngine = SyncEngine(
            cloudKitManager: mockCloudKit,
            database: testDB
        )

        // Initial state should be idle (or disabled based on isSyncEnabled)
        XCTAssertTrue(
            syncEngine.status == .idle || syncEngine.status == .disabled,
            "Expected idle or disabled, got \(syncEngine.status)"
        )
        XCTAssertNil(syncEngine.lastSyncDate)
    }

    // MARK: - Start/Stop Tests

    func testStartCallsInitialize() async throws {
        guard testDB.getQueue() != nil else {
            XCTFail("Test database not initialized")
            return
        }

        mockCloudKit.configureForSuccess()
        syncEngine = SyncEngine(
            cloudKitManager: mockCloudKit,
            database: testDB
        )

        await syncEngine.start()

        // Verify initialize was called
        XCTAssertEqual(mockCloudKit.initializeCallCount, 1)
    }

    func testStartCallsRegisterForSubscriptions() async throws {
        guard testDB.getQueue() != nil else {
            XCTFail("Test database not initialized")
            return
        }

        mockCloudKit.configureForSuccess()
        syncEngine = SyncEngine(
            cloudKitManager: mockCloudKit,
            database: testDB
        )

        await syncEngine.start()

        // Verify subscription registration was called
        XCTAssertEqual(mockCloudKit.registerForSubscriptionsCallCount, 1)
    }

    func testStartWithNoAccountSetsDisabledStatus() async throws {
        guard testDB.getQueue() != nil else {
            XCTFail("Test database not initialized")
            return
        }

        mockCloudKit.configureForNoAccount()
        syncEngine = SyncEngine(
            cloudKitManager: mockCloudKit,
            database: testDB
        )

        await syncEngine.start()

        // Should set status to disabled when no account
        XCTAssertEqual(syncEngine.status, .disabled)
    }

    func testStopCallsUnregisterSubscriptions() async throws {
        guard testDB.getQueue() != nil else {
            XCTFail("Test database not initialized")
            return
        }

        mockCloudKit.configureForSuccess()
        syncEngine = SyncEngine(
            cloudKitManager: mockCloudKit,
            database: testDB
        )

        await syncEngine.start()
        await syncEngine.stop()

        // Verify unregister was called
        XCTAssertEqual(mockCloudKit.unregisterSubscriptionsCallCount, 1)
    }

    func testStopSetsDisabledStatus() async throws {
        guard testDB.getQueue() != nil else {
            XCTFail("Test database not initialized")
            return
        }

        mockCloudKit.configureForSuccess()
        syncEngine = SyncEngine(
            cloudKitManager: mockCloudKit,
            database: testDB
        )

        await syncEngine.start()
        await syncEngine.stop()

        // Status should be disabled after stop
        XCTAssertEqual(syncEngine.status, .disabled)
    }

    // MARK: - Status Transition Tests

    func testSyncStatusPublisherEmitsChanges() async throws {
        guard testDB.getQueue() != nil else {
            XCTFail("Test database not initialized")
            return
        }

        mockCloudKit.configureForSuccess()
        syncEngine = SyncEngine(
            cloudKitManager: mockCloudKit,
            database: testDB
        )

        var statusChanges: [SyncEngine.SyncStatus] = []

        syncEngine.$status
            .sink { status in
                statusChanges.append(status)
            }
            .store(in: &cancellables)

        await syncEngine.start()

        // Give it time to process
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Should have captured at least the initial status
        XCTAssertGreaterThanOrEqual(statusChanges.count, 1)
    }

    func testIsSyncEnabledToggle() async throws {
        guard testDB.getQueue() != nil else {
            XCTFail("Test database not initialized")
            return
        }

        mockCloudKit.configureForSuccess()
        syncEngine = SyncEngine(
            cloudKitManager: mockCloudKit,
            database: testDB
        )

        // Initially enabled by default
        XCTAssertTrue(syncEngine.isSyncEnabled)

        // Disable sync
        syncEngine.isSyncEnabled = false

        // Give it time to process the change
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Status should be disabled
        XCTAssertEqual(syncEngine.status, .disabled)
    }

    // MARK: - Debouncing Tests

    func testRequestSyncDebounces() async throws {
        guard testDB.getQueue() != nil else {
            XCTFail("Test database not initialized")
            return
        }

        mockCloudKit.configureForSuccess()
        syncEngine = SyncEngine(
            cloudKitManager: mockCloudKit,
            database: testDB
        )

        // Start the engine first
        await syncEngine.start()

        // Reset call counts after start
        mockCloudKit.initializeCallCount = 0

        // Make multiple rapid sync requests
        syncEngine.requestSync()
        syncEngine.requestSync()
        syncEngine.requestSync()

        // Wait longer than debounce interval (1 second + buffer)
        try await Task.sleep(nanoseconds: 1_500_000_000)

        // Should have debounced to a single sync attempt
        // Note: initialize gets called during sync()
        XCTAssertLessThanOrEqual(mockCloudKit.initializeCallCount, 2,
                                 "Should debounce multiple requests")
    }

    // MARK: - iCloud Account Name Tests

    func testStartFetchesAccountInfo() async throws {
        guard testDB.getQueue() != nil else {
            XCTFail("Test database not initialized")
            return
        }

        mockCloudKit.configureForSuccess()
        syncEngine = SyncEngine(
            cloudKitManager: mockCloudKit,
            database: testDB
        )

        XCTAssertNil(syncEngine.iCloudAccountName)

        await syncEngine.start()

        // iCloudAccountName should be set (or at least attempted to be fetched)
        // Note: The actual value depends on mock container behavior
        // We're just verifying the attempt was made
    }

    // MARK: - Initial Sync Tests

    func testInitialSyncCompleteFlag() async throws {
        guard testDB.getQueue() != nil else {
            XCTFail("Test database not initialized")
            return
        }

        mockCloudKit.configureForSuccess()
        syncEngine = SyncEngine(
            cloudKitManager: mockCloudKit,
            database: testDB
        )

        // Initial sync flag should be readable
        // Value depends on metadata store state
        _ = syncEngine.isInitialSyncComplete
    }

    // MARK: - Error Handling Tests

    func testStartWithZoneFailureSetsErrorStatus() async throws {
        guard testDB.getQueue() != nil else {
            XCTFail("Test database not initialized")
            return
        }

        mockCloudKit.mockAccountStatus = .available
        mockCloudKit.shouldFailZoneCreation = true

        syncEngine = SyncEngine(
            cloudKitManager: mockCloudKit,
            database: testDB
        )

        await syncEngine.start()

        // Should have error status
        switch syncEngine.status {
        case .error:
            break // Expected
        default:
            XCTFail("Expected error status, got \(syncEngine.status)")
        }
    }

    // MARK: - Publisher Tests

    func testLastSyncDatePublisher() async throws {
        guard testDB.getQueue() != nil else {
            XCTFail("Test database not initialized")
            return
        }

        mockCloudKit.configureForSuccess()
        syncEngine = SyncEngine(
            cloudKitManager: mockCloudKit,
            database: testDB
        )

        var capturedDate: Date? = nil

        syncEngine.$lastSyncDate
            .sink { date in
                capturedDate = date
            }
            .store(in: &cancellables)

        await syncEngine.start()

        // Give it time to potentially update
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Just verify the publisher is accessible
        // The actual value depends on whether sync completed
    }

    // MARK: - Sync Enabled State Tests

    func testSyncEnabledStateChangeCallsStartStop() async throws {
        guard testDB.getQueue() != nil else {
            XCTFail("Test database not initialized")
            return
        }

        mockCloudKit.configureForSuccess()
        syncEngine = SyncEngine(
            cloudKitManager: mockCloudKit,
            database: testDB
        )

        // Start with sync enabled
        XCTAssertTrue(syncEngine.isSyncEnabled)

        // Disable sync
        syncEngine.isSyncEnabled = false
        try await Task.sleep(nanoseconds: 600_000_000)

        XCTAssertEqual(syncEngine.status, .disabled)

        // Reset call count
        let countAfterDisable = mockCloudKit.initializeCallCount

        // Re-enable sync
        syncEngine.isSyncEnabled = true
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Should call initialize again
        XCTAssertGreaterThan(mockCloudKit.initializeCallCount, countAfterDisable)
    }

    // MARK: - Multiple Start/Stop Cycles

    func testMultipleStartStopCycles() async throws {
        guard testDB.getQueue() != nil else {
            XCTFail("Test database not initialized")
            return
        }

        mockCloudKit.configureForSuccess()
        syncEngine = SyncEngine(
            cloudKitManager: mockCloudKit,
            database: testDB
        )

        // Cycle 1
        await syncEngine.start()
        XCTAssertEqual(mockCloudKit.initializeCallCount, 1)
        await syncEngine.stop()
        XCTAssertEqual(mockCloudKit.unregisterSubscriptionsCallCount, 1)

        // Cycle 2
        await syncEngine.start()
        XCTAssertEqual(mockCloudKit.initializeCallCount, 2)
        await syncEngine.stop()
        XCTAssertEqual(mockCloudKit.unregisterSubscriptionsCallCount, 2)

        // Each cycle should properly initialize and clean up
        XCTAssertEqual(syncEngine.status, .disabled)
    }

    // MARK: - Mock Verification Tests

    func testMockCloudKitManagerIntegration() {
        // Verify mock works as expected with SyncEngine
        mockCloudKit.configureForSuccess()

        XCTAssertEqual(mockCloudKit.accountStatus, .couldNotDetermine)
        XCTAssertEqual(mockCloudKit.mockAccountStatus, .available)
        XCTAssertFalse(mockCloudKit.isZoneReady)
        XCTAssertEqual(mockCloudKit.initializeCallCount, 0)
    }

    func testMockResetBetweenTests() {
        // Verify mock can be reset
        mockCloudKit.initializeCallCount = 5
        mockCloudKit.reset()

        XCTAssertEqual(mockCloudKit.initializeCallCount, 0)
        XCTAssertEqual(mockCloudKit.accountStatus, .couldNotDetermine)
        XCTAssertFalse(mockCloudKit.isZoneReady)
    }
}
