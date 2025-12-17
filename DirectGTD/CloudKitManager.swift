import DirectGTDCore
import Foundation
import CloudKit
import Combine

/// Manages CloudKit container, zone setup, and account status.
class CloudKitManager: CloudKitManagerProtocol {
    static let shared = CloudKitManager()

    // Configuration
    static let containerIdentifier = "iCloud.com.directgtd"
    static let zoneName = "DirectGTDZone"

    let container: CKContainer
    let privateDatabase: CKDatabase
    let zoneID: CKRecordZone.ID

    // Account status
    @Published private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published private(set) var isZoneReady: Bool = false

    private init() {
        container = CKContainer(identifier: CloudKitManager.containerIdentifier)
        privateDatabase = container.privateCloudDatabase
        zoneID = CKRecordZone.ID(zoneName: CloudKitManager.zoneName, ownerName: CKCurrentUserDefaultName)
    }

    // MARK: - Account Status

    /// Check if iCloud account is available
    func checkAccountStatus() async throws -> CKAccountStatus {
        let status = try await container.accountStatus()
        await MainActor.run {
            self.accountStatus = status
        }
        return status
    }

    /// Returns true if account is available for CloudKit operations
    var isAccountAvailable: Bool {
        accountStatus == .available
    }

    // MARK: - Zone Setup

    /// Ensures the custom zone exists, creating it if necessary
    func ensureZoneExists() async throws {
        let zone = CKRecordZone(zoneID: zoneID)

        do {
            // Try to fetch the zone first
            _ = try await privateDatabase.recordZone(for: zoneID)
            NSLog("CloudKitManager: Zone '\(CloudKitManager.zoneName)' already exists")
            await MainActor.run {
                self.isZoneReady = true
            }
        } catch let error as CKError where error.code == .zoneNotFound {
            // Zone doesn't exist, create it
            NSLog("CloudKitManager: Creating zone '\(CloudKitManager.zoneName)'")
            _ = try await privateDatabase.save(zone)
            NSLog("CloudKitManager: Zone created successfully")
            await MainActor.run {
                self.isZoneReady = true
            }
        } catch {
            NSLog("CloudKitManager: Error checking/creating zone: \(error)")
            throw error
        }
    }

    /// Initialize CloudKit - check account and ensure zone exists
    func initialize() async throws {
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

        NSLog("CloudKitManager: Initialization complete")
    }

    // MARK: - Helpers

    /// Create a CKRecord.ID for a given record type and local ID
    func recordID(for recordName: String) -> CKRecord.ID {
        CKRecord.ID(recordName: recordName, zoneID: zoneID)
    }

    /// Create a new CKRecord in our zone
    func newRecord(type: String, recordName: String) -> CKRecord {
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        return CKRecord(recordType: type, recordID: recordID)
    }

    // MARK: - Subscriptions

    /// Register for push notifications when database changes
    func registerForSubscriptions() async throws {
        let subscriptionID = CloudKitConfig.subscriptionID

        // Check if subscription already exists
        do {
            _ = try await privateDatabase.subscription(for: subscriptionID)
            NSLog("CloudKitManager: Subscription '\(subscriptionID)' already exists")
            return
        } catch let error as CKError where error.code == .unknownItem {
            // Subscription doesn't exist, create it
            NSLog("CloudKitManager: Creating subscription '\(subscriptionID)'")
        } catch {
            NSLog("CloudKitManager: Error checking subscription: \(error)")
            throw error
        }

        // Create a database subscription for all changes in our zone
        let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true  // Silent push for background fetch
        subscription.notificationInfo = notificationInfo

        _ = try await privateDatabase.save(subscription)
        NSLog("CloudKitManager: Subscription created successfully")
    }

    /// Unregister subscription
    func unregisterSubscriptions() async throws {
        let subscriptionID = CloudKitConfig.subscriptionID

        do {
            try await privateDatabase.deleteSubscription(withID: subscriptionID)
            NSLog("CloudKitManager: Subscription deleted")
        } catch let error as CKError where error.code == .unknownItem {
            // Already deleted, ignore
            NSLog("CloudKitManager: Subscription already deleted")
        }
    }
}

// MARK: - CloudKitManagerProtocol conformance

extension CloudKitManager {
    var accountStatusPublisher: Published<CKAccountStatus>.Publisher { $accountStatus }
    var isZoneReadyPublisher: Published<Bool>.Publisher { $isZoneReady }
}
