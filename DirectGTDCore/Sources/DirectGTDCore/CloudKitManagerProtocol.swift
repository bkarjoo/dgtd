//
//  CloudKitManagerProtocol.swift
//  DirectGTDCore
//
//  Shared CloudKit abstractions for macOS and iOS
//

import CloudKit
import Combine

/// Protocol abstraction to allow mocking CloudKit interactions in tests
/// and sharing sync logic between platforms.
public protocol CloudKitManagerProtocol: AnyObject {
    var zoneID: CKRecordZone.ID { get }
    var container: CKContainer { get }
    var privateDatabase: CKDatabase { get }
    var accountStatus: CKAccountStatus { get }
    var isZoneReady: Bool { get }
    var accountStatusPublisher: Published<CKAccountStatus>.Publisher { get }
    var isZoneReadyPublisher: Published<Bool>.Publisher { get }
    var isAccountAvailable: Bool { get }

    func checkAccountStatus() async throws -> CKAccountStatus
    func ensureZoneExists() async throws
    func initialize() async throws
    func registerForSubscriptions() async throws
    func unregisterSubscriptions() async throws

    func recordID(for recordName: String) -> CKRecord.ID
    func newRecord(type: String, recordName: String) -> CKRecord
}

// MARK: - Record Types

/// CloudKit record type names matching our local tables
public enum CloudKitRecordType {
    public static let item = "Item"
    public static let tag = "Tag"
    public static let itemTag = "ItemTag"
    public static let timeEntry = "TimeEntry"
    public static let savedSearch = "SavedSearch"
}

// MARK: - CloudKit Configuration

/// Shared CloudKit configuration constants
public enum CloudKitConfig {
    /// Subscription ID for database changes
    public static let subscriptionID = "DirectGTD-zone-changes"
}

// MARK: - Errors

public enum CloudKitError: LocalizedError {
    case accountNotAvailable(String)
    case zoneNotReady
    case recordNotFound(String)
    case syncFailed(String)
    case conflictDetected(serverRecord: CKRecord, localModifiedAt: Int)

    public var errorDescription: String? {
        switch self {
        case .accountNotAvailable(let message):
            return message
        case .zoneNotReady:
            return "CloudKit zone is not ready. Please try again."
        case .recordNotFound(let recordName):
            return "Record not found: \(recordName)"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        case .conflictDetected:
            return "A sync conflict was detected."
        }
    }
}
