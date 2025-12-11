//
//  CloudKitManager.swift
//  DirectGTD-iOS
//
//  Created by Behrooz Karjoo on 12/9/25.
//

import DirectGTDCore
import Foundation
import CloudKit
import Combine

/// Manages CloudKit container, zone setup, and account status for iOS.
class CloudKitManager {
    static let shared = CloudKitManager()

    // Configuration - same as macOS
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

    func checkAccountStatus() async throws -> CKAccountStatus {
        let status = try await container.accountStatus()
        await MainActor.run {
            self.accountStatus = status
        }
        return status
    }

    var isAccountAvailable: Bool {
        accountStatus == .available
    }

    // MARK: - Zone Setup

    func ensureZoneExists() async throws {
        let zone = CKRecordZone(zoneID: zoneID)

        do {
            _ = try await privateDatabase.recordZone(for: zoneID)
            NSLog("CloudKitManager: Zone '\(CloudKitManager.zoneName)' already exists")
            await MainActor.run {
                self.isZoneReady = true
            }
        } catch let error as CKError where error.code == .zoneNotFound {
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

    func initialize() async throws {
        let status = try await checkAccountStatus()

        guard status == .available else {
            let errorMessage: String
            switch status {
            case .noAccount:
                errorMessage = "No iCloud account. Please sign in to iCloud in Settings."
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

        try await ensureZoneExists()
        NSLog("CloudKitManager: Initialization complete")
    }

    // MARK: - Record Type Names

    enum RecordType {
        static let item = "Item"
        static let tag = "Tag"
        static let itemTag = "ItemTag"
        static let timeEntry = "TimeEntry"
        static let savedSearch = "SavedSearch"
    }

    // MARK: - Helpers

    func recordID(for recordName: String) -> CKRecord.ID {
        CKRecord.ID(recordName: recordName, zoneID: zoneID)
    }

    func newRecord(type: String, recordName: String) -> CKRecord {
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        return CKRecord(recordType: type, recordID: recordID)
    }
}

// MARK: - Errors

enum CloudKitError: Error, LocalizedError {
    case accountNotAvailable(String)
    case zoneNotReady
    case recordNotFound
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .accountNotAvailable(let message):
            return message
        case .zoneNotReady:
            return "CloudKit zone is not ready"
        case .recordNotFound:
            return "Record not found"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        }
    }
}
