import XCTest
import CloudKit
import Combine
@testable import DirectGTD

/// Tests for async CloudKit operations using mock infrastructure
final class CloudKitAsyncOperationsTests: XCTestCase {
    var mockManager: MockCloudKitManager!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockManager = MockCloudKitManager()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        cancellables = nil
        mockManager = nil
        super.tearDown()
    }

    // MARK: - checkAccountStatus() Tests

    func testCheckAccountStatusAvailable() async throws {
        mockManager.mockAccountStatus = .available

        let status = try await mockManager.checkAccountStatus()

        XCTAssertEqual(status, .available)
        XCTAssertTrue(mockManager.isAccountAvailable)
        XCTAssertEqual(mockManager.checkAccountStatusCallCount, 1)
    }

    func testCheckAccountStatusNoAccount() async throws {
        mockManager.mockAccountStatus = .noAccount

        let status = try await mockManager.checkAccountStatus()

        XCTAssertEqual(status, .noAccount)
        XCTAssertFalse(mockManager.isAccountAvailable)
        XCTAssertEqual(mockManager.checkAccountStatusCallCount, 1)
    }

    func testCheckAccountStatusRestricted() async throws {
        mockManager.mockAccountStatus = .restricted

        let status = try await mockManager.checkAccountStatus()

        XCTAssertEqual(status, .restricted)
        XCTAssertFalse(mockManager.isAccountAvailable)
    }

    func testCheckAccountStatusCouldNotDetermine() async throws {
        mockManager.mockAccountStatus = .couldNotDetermine

        let status = try await mockManager.checkAccountStatus()

        XCTAssertEqual(status, .couldNotDetermine)
        XCTAssertFalse(mockManager.isAccountAvailable)
    }

    func testCheckAccountStatusTemporarilyUnavailable() async throws {
        mockManager.mockAccountStatus = .temporarilyUnavailable

        let status = try await mockManager.checkAccountStatus()

        XCTAssertEqual(status, .temporarilyUnavailable)
        XCTAssertFalse(mockManager.isAccountAvailable)
    }

    func testCheckAccountStatusUpdatesPublishedProperty() async throws {
        mockManager.mockAccountStatus = .available

        // Verify initial state
        XCTAssertEqual(mockManager.accountStatus, .couldNotDetermine)

        // Check account status
        _ = try await mockManager.checkAccountStatus()

        // Verify property updated
        XCTAssertEqual(mockManager.accountStatus, .available)
    }

    // MARK: - ensureZoneExists() Tests

    func testEnsureZoneExistsCreatesNewZone() async throws {
        mockManager.mockAccountStatus = .available
        mockManager.zoneAlreadyExists = false

        try await mockManager.ensureZoneExists()

        XCTAssertTrue(mockManager.isZoneReady)
        XCTAssertEqual(mockManager.ensureZoneExistsCallCount, 1)
    }

    func testEnsureZoneExistsWhenZoneAlreadyExists() async throws {
        mockManager.mockAccountStatus = .available
        mockManager.zoneAlreadyExists = true

        try await mockManager.ensureZoneExists()

        XCTAssertTrue(mockManager.isZoneReady)
        XCTAssertEqual(mockManager.ensureZoneExistsCallCount, 1)
    }

    func testEnsureZoneExistsFailsWhenConfigured() async {
        mockManager.shouldFailZoneCreation = true

        let error = await asyncAssertThrows(CloudKitError.self) {
            try await self.mockManager.ensureZoneExists()
        }

        XCTAssertNotNil(error)
        if case .zoneNotReady = error {
            // Expected error
        } else {
            XCTFail("Expected zoneNotReady error")
        }
        XCTAssertFalse(mockManager.isZoneReady)
    }

    func testEnsureZoneExistsUpdatesPublishedProperty() async throws {
        mockManager.mockAccountStatus = .available

        // Verify initial state
        XCTAssertFalse(mockManager.isZoneReady)

        try await mockManager.ensureZoneExists()

        // Verify property updated
        XCTAssertTrue(mockManager.isZoneReady)
    }

    // MARK: - initialize() Tests

    func testInitializeSuccessPath() async throws {
        mockManager.configureForSuccess()

        try await mockManager.initialize()

        XCTAssertTrue(mockManager.isAccountAvailable)
        XCTAssertTrue(mockManager.isZoneReady)
        XCTAssertEqual(mockManager.initializeCallCount, 1)
        XCTAssertEqual(mockManager.checkAccountStatusCallCount, 1)
        XCTAssertEqual(mockManager.ensureZoneExistsCallCount, 1)
    }

    func testInitializeFailsWithNoAccount() async {
        mockManager.configureForNoAccount()

        let error = await asyncAssertThrows(CloudKitError.self) {
            try await self.mockManager.initialize()
        }

        if case .accountNotAvailable = error {
            // Expected error
        } else {
            XCTFail("Expected accountNotAvailable error")
        }
        XCTAssertFalse(mockManager.isAccountAvailable)
        XCTAssertFalse(mockManager.isZoneReady)
    }

    func testInitializeFailsWithZoneCreationError() async {
        mockManager.mockAccountStatus = .available
        mockManager.shouldFailZoneCreation = true

        let error = await asyncAssertThrows(CloudKitError.self) {
            try await self.mockManager.initialize()
        }

        if case .zoneNotReady = error {
            // Expected error
        } else {
            XCTFail("Expected zoneNotReady error")
        }
        XCTAssertTrue(mockManager.isAccountAvailable)
        XCTAssertFalse(mockManager.isZoneReady)
    }

    func testInitializeIsIdempotent() async throws {
        mockManager.configureForSuccess()

        // Call initialize multiple times
        try await mockManager.initialize()
        try await mockManager.initialize()
        try await mockManager.initialize()

        // Should succeed and track all calls
        XCTAssertEqual(mockManager.initializeCallCount, 3)
        XCTAssertTrue(mockManager.isAccountAvailable)
        XCTAssertTrue(mockManager.isZoneReady)
    }

    // MARK: - registerForSubscriptions() Tests

    func testRegisterForSubscriptionsSuccess() async throws {
        mockManager.mockAccountStatus = .available

        try await mockManager.registerForSubscriptions()

        XCTAssertEqual(mockManager.registerForSubscriptionsCallCount, 1)
    }

    func testRegisterForSubscriptionsWhenAlreadyRegistered() async throws {
        mockManager.mockAccountStatus = .available
        mockManager.subscriptionAlreadyExists = true

        try await mockManager.registerForSubscriptions()

        XCTAssertEqual(mockManager.registerForSubscriptionsCallCount, 1)
    }

    func testRegisterForSubscriptionsFailure() async {
        mockManager.shouldFailSubscriptionRegistration = true

        let error = await asyncAssertThrows(CloudKitError.self) {
            try await self.mockManager.registerForSubscriptions()
        }

        XCTAssertNotNil(error)
    }

    func testUnregisterSubscriptions() async throws {
        mockManager.mockAccountStatus = .available

        try await mockManager.unregisterSubscriptions()

        XCTAssertEqual(mockManager.unregisterSubscriptionsCallCount, 1)
    }

    // MARK: - @Published Property Tests with Combine

    func testAccountStatusPublisherEmitsChanges() async throws {
        let expectation = expectation(description: "Account status published")
        var receivedStatuses: [CKAccountStatus] = []

        mockManager.$accountStatus
            .dropFirst() // Skip initial value
            .sink { status in
                receivedStatuses.append(status)
                if status == .available {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Change the status
        mockManager.mockAccountStatus = .available
        _ = try await mockManager.checkAccountStatus()

        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertEqual(receivedStatuses.last, .available)
    }

    func testIsZoneReadyPublisherEmitsChanges() async throws {
        let expectation = expectation(description: "Zone ready published")
        var receivedValues: [Bool] = []

        mockManager.$isZoneReady
            .dropFirst() // Skip initial value
            .sink { isReady in
                receivedValues.append(isReady)
                if isReady {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Change the zone ready status
        mockManager.mockAccountStatus = .available
        try await mockManager.ensureZoneExists()

        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertTrue(receivedValues.last ?? false)
    }

    func testIsAccountAvailableComputedProperty() async throws {
        // Verify computed property reflects account status
        XCTAssertFalse(mockManager.isAccountAvailable)

        mockManager.mockAccountStatus = .available
        _ = try await mockManager.checkAccountStatus()

        XCTAssertTrue(mockManager.isAccountAvailable)
    }

    func testMultiplePublishersEmitDuringInitialize() async throws {
        let accountExpectation = expectation(description: "Account status changed")
        let zoneExpectation = expectation(description: "Zone ready changed")

        var accountChanged = false
        var zoneChanged = false

        mockManager.$accountStatus
            .dropFirst()
            .sink { status in
                if status == .available {
                    accountChanged = true
                    accountExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        mockManager.$isZoneReady
            .dropFirst()
            .sink { isReady in
                if isReady {
                    zoneChanged = true
                    zoneExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        mockManager.configureForSuccess()
        try await mockManager.initialize()

        await fulfillment(of: [accountExpectation, zoneExpectation], timeout: 1.0)

        XCTAssertTrue(accountChanged)
        XCTAssertTrue(zoneChanged)
    }

    // MARK: - Error Handling Tests

    func testCustomErrorThrownDuringInitialize() async {
        let customError = NSError(domain: "TestError", code: 123, userInfo: [NSLocalizedDescriptionKey: "Custom test error"])
        mockManager.errorToThrow = customError

        do {
            try await mockManager.initialize()
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual((error as NSError).code, 123)
            XCTAssertEqual((error as NSError).domain, "TestError")
        }
    }

    // MARK: - State Reset Tests

    func testResetClearsAllState() async throws {
        // Set up some state
        mockManager.configureForSuccess()
        try await mockManager.initialize()
        XCTAssertTrue(mockManager.isAccountAvailable)
        XCTAssertTrue(mockManager.isZoneReady)

        // Reset
        mockManager.reset()

        // Verify everything is cleared
        XCTAssertEqual(mockManager.accountStatus, .couldNotDetermine)
        XCTAssertFalse(mockManager.isZoneReady)
        XCTAssertFalse(mockManager.isAccountAvailable)
        XCTAssertEqual(mockManager.initializeCallCount, 0)
        XCTAssertEqual(mockManager.checkAccountStatusCallCount, 0)
        XCTAssertEqual(mockManager.ensureZoneExistsCallCount, 0)
    }
}
