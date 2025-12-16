import Foundation
import CloudKit
import Combine
@testable import DirectGTD

/// Mock implementation of CloudKitManagerProtocol for testing
class MockCloudKitManager: CloudKitManagerProtocol {
    // MARK: - Configuration

    let zoneID: CKRecordZone.ID
    let container: CKContainer
    let privateDatabase: CKDatabase

    // MARK: - Published State

    @Published private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published private(set) var isZoneReady: Bool = false

    var accountStatusPublisher: Published<CKAccountStatus>.Publisher { $accountStatus }
    var isZoneReadyPublisher: Published<Bool>.Publisher { $isZoneReady }

    var isAccountAvailable: Bool {
        accountStatus == .available
    }

    // MARK: - Mock State & Configuration

    /// Set this to control what checkAccountStatus() returns
    var mockAccountStatus: CKAccountStatus = .available

    /// Set this to true to make ensureZoneExists() throw
    var shouldFailZoneCreation: Bool = false

    /// Set this to true to make ensureZoneExists() find existing zone
    var zoneAlreadyExists: Bool = false

    /// Set this to true to make registerForSubscriptions() throw
    var shouldFailSubscriptionRegistration: Bool = false

    /// Set this to true to simulate subscription already exists
    var subscriptionAlreadyExists: Bool = false

    /// Set custom error to throw
    var errorToThrow: Error?

    /// Track method calls for verification
    var checkAccountStatusCallCount: Int = 0
    var ensureZoneExistsCallCount: Int = 0
    var initializeCallCount: Int = 0
    var registerForSubscriptionsCallCount: Int = 0
    var unregisterSubscriptionsCallCount: Int = 0

    // MARK: - Initialization

    init(zoneName: String = "TestZone") {
        self.zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        self.container = CKContainer(identifier: "iCloud.com.directgtd.test")
        self.privateDatabase = container.privateCloudDatabase
    }

    // MARK: - Async Operations

    func checkAccountStatus() async throws -> CKAccountStatus {
        checkAccountStatusCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        accountStatus = mockAccountStatus
        return mockAccountStatus
    }

    func ensureZoneExists() async throws {
        ensureZoneExistsCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        if shouldFailZoneCreation {
            throw CloudKitError.zoneNotReady
        }

        if zoneAlreadyExists {
            // Zone already exists, just mark as ready
            isZoneReady = true
            return
        }

        // Simulate zone creation
        try await Task.sleep(nanoseconds: 100_000) // 0.1ms
        isZoneReady = true
    }

    func initialize() async throws {
        initializeCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        // Check account status
        let status = try await checkAccountStatus()

        guard status == .available else {
            let errorMessage: String
            switch status {
            case .noAccount:
                errorMessage = "No iCloud account. Please sign in to iCloud in System Settings."
            case .restricted:
                errorMessage = "iCloud access is restricted on this device."
            case .temporarilyUnavailable:
                errorMessage = "iCloud is temporarily unavailable. Please try again later."
            case .couldNotDetermine:
                errorMessage = "Could not determine iCloud account status."
            @unknown default:
                errorMessage = "Unknown iCloud account status."
            }
            throw CloudKitError.accountNotAvailable(errorMessage)
        }

        // Ensure zone exists
        try await ensureZoneExists()
    }

    func registerForSubscriptions() async throws {
        registerForSubscriptionsCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        if shouldFailSubscriptionRegistration {
            throw CloudKitError.syncFailed("Subscription registration failed")
        }

        if subscriptionAlreadyExists {
            // Subscription already exists, return early
            return
        }

        // Simulate subscription creation
        try await Task.sleep(nanoseconds: 100_000) // 0.1ms
    }

    func unregisterSubscriptions() async throws {
        unregisterSubscriptionsCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        // Simulate subscription deletion
        try await Task.sleep(nanoseconds: 100_000) // 0.1ms
    }

    // MARK: - Helper Methods

    func recordID(for recordName: String) -> CKRecord.ID {
        CKRecord.ID(recordName: recordName, zoneID: zoneID)
    }

    func newRecord(type: String, recordName: String) -> CKRecord {
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        return CKRecord(recordType: type, recordID: recordID)
    }

    // MARK: - Test Helpers

    /// Reset all mock state for a fresh test
    func reset() {
        accountStatus = .couldNotDetermine
        isZoneReady = false
        mockAccountStatus = .available
        shouldFailZoneCreation = false
        zoneAlreadyExists = false
        shouldFailSubscriptionRegistration = false
        subscriptionAlreadyExists = false
        errorToThrow = nil
        checkAccountStatusCallCount = 0
        ensureZoneExistsCallCount = 0
        initializeCallCount = 0
        registerForSubscriptionsCallCount = 0
        unregisterSubscriptionsCallCount = 0
    }

    /// Configure for successful operations
    func configureForSuccess() {
        mockAccountStatus = .available
        shouldFailZoneCreation = false
        shouldFailSubscriptionRegistration = false
        errorToThrow = nil
    }

    /// Configure for account unavailable
    func configureForNoAccount() {
        mockAccountStatus = .noAccount
    }

    /// Configure for zone creation failure
    func configureForZoneFailure() {
        shouldFailZoneCreation = true
    }
}
