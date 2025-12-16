//
//  SyncEngine.swift
//  DirectGTD-iOS
//
//  Created by Behrooz Karjoo on 12/9/25.
//

import DirectGTDCore
import Foundation
import CloudKit
import GRDB
import Combine

/// Sync engine for iOS - pushes local changes and pulls remote changes from CloudKit
class SyncEngine: ObservableObject {
    private let cloudKitManager: CloudKitManagerProtocol
    private let database: DatabaseProvider
    private let metadataStore: SyncMetadataStore

    enum SyncStatus: Equatable {
        case disabled
        case idle
        case syncing
        case error(String)

        static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
            switch (lhs, rhs) {
            case (.disabled, .disabled), (.idle, .idle), (.syncing, .syncing):
                return true
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    @Published private(set) var status: SyncStatus = .idle
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var itemCount: Int = 0

    init(cloudKitManager: CloudKitManagerProtocol = CloudKitManager.shared,
         database: DatabaseProvider = Database.shared) {
        self.cloudKitManager = cloudKitManager
        self.database = database

        if let queue = database.getQueue() {
            self.metadataStore = SyncMetadataStore(dbQueue: queue)
            if let timestamp = try? metadataStore.getLastSyncTimestamp() {
                lastSyncDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
            }
        } else {
            fatalError("SyncEngine requires initialized database")
        }
    }

    // MARK: - Public API

    /// Perform a full sync (push local changes, then pull remote changes)
    func sync() async {
        guard status != .syncing else {
            NSLog("SyncEngine: Sync already in progress")
            return
        }

        await MainActor.run {
            status = .syncing
        }

        do {
            // Initialize CloudKit
            try await cloudKitManager.initialize()

            // Push local changes first
            try await pushLocalChanges()

            // Pull remote changes
            let changeCount = try await pullRemoteChanges()
            NSLog("SyncEngine: Pulled \(changeCount) changes")

            // Update last sync time
            let now = Int(Date().timeIntervalSince1970)
            try metadataStore.setLastSyncTimestamp(now)

            // Count items
            let count = try countItems()

            await MainActor.run {
                lastSyncDate = Date()
                itemCount = count
                status = .idle
            }

            NSLog("SyncEngine: Sync completed successfully")

        } catch {
            NSLog("SyncEngine: Sync failed - \(error)")
            await MainActor.run {
                status = .error(error.localizedDescription)
            }
        }
    }

    /// Get all items from local database
    func getAllItems() throws -> [Item] {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        return try dbQueue.read { db in
            try Item.filter(Column("deleted_at") == nil).fetchAll(db)
        }
    }

    /// Count items in database
    func countItems() throws -> Int {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        return try dbQueue.read { db in
            try Item.filter(Column("deleted_at") == nil).fetchCount(db)
        }
    }

    // MARK: - Push

    /// CloudKit batch size limit
    private static let cloudKitBatchLimit = 400

    /// Push all dirty records to CloudKit
    func pushLocalChanges() async throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        // Get all dirty records
        let dirtyItems = try getDirtyItems(dbQueue: dbQueue)
        let dirtyTags = try getDirtyTags(dbQueue: dbQueue)
        let dirtyItemTags = try getDirtyItemTags(dbQueue: dbQueue)
        let dirtyTimeEntries = try getDirtyTimeEntries(dbQueue: dbQueue)
        let dirtySavedSearches = try getDirtySavedSearches(dbQueue: dbQueue)

        let totalDirty = dirtyItems.count + dirtyTags.count + dirtyItemTags.count + dirtyTimeEntries.count + dirtySavedSearches.count
        guard totalDirty > 0 else {
            NSLog("SyncEngine: No dirty records to push")
            return
        }

        NSLog("SyncEngine: Pushing \(dirtyItems.count) items, \(dirtyTags.count) tags, \(dirtyItemTags.count) itemTags, \(dirtyTimeEntries.count) timeEntries, \(dirtySavedSearches.count) savedSearches")

        // Separate records to save vs delete
        var recordsToSave: [CKRecord] = []
        var recordIDsToDelete: [CKRecord.ID] = []

        // Process items
        for item in dirtyItems {
            if item.deletedAt != nil {
                if let recordName = item.ckRecordName {
                    recordIDsToDelete.append(cloudKitManager.recordID(for: recordName))
                }
            } else {
                recordsToSave.append(CKRecordConverters.record(from: item, manager: cloudKitManager))
            }
        }

        // Process tags
        for tag in dirtyTags {
            if tag.deletedAt != nil {
                if let recordName = tag.ckRecordName {
                    recordIDsToDelete.append(cloudKitManager.recordID(for: recordName))
                }
            } else {
                recordsToSave.append(CKRecordConverters.record(from: tag, manager: cloudKitManager))
            }
        }

        // Process itemTags
        for itemTag in dirtyItemTags {
            if itemTag.deletedAt != nil {
                if let recordName = itemTag.ckRecordName {
                    recordIDsToDelete.append(cloudKitManager.recordID(for: recordName))
                }
            } else {
                recordsToSave.append(CKRecordConverters.record(from: itemTag, manager: cloudKitManager))
            }
        }

        // Process timeEntries
        for timeEntry in dirtyTimeEntries {
            if timeEntry.deletedAt != nil {
                if let recordName = timeEntry.ckRecordName {
                    recordIDsToDelete.append(cloudKitManager.recordID(for: recordName))
                }
            } else {
                recordsToSave.append(CKRecordConverters.record(from: timeEntry, manager: cloudKitManager))
            }
        }

        // Process savedSearches
        for savedSearch in dirtySavedSearches {
            if savedSearch.deletedAt != nil {
                if let recordName = savedSearch.ckRecordName {
                    recordIDsToDelete.append(cloudKitManager.recordID(for: recordName))
                }
            } else {
                recordsToSave.append(CKRecordConverters.record(from: savedSearch, manager: cloudKitManager))
            }
        }

        // Perform batch operation
        if !recordsToSave.isEmpty || !recordIDsToDelete.isEmpty {
            try await performBatchOperation(
                recordsToSave: recordsToSave,
                recordIDsToDelete: recordIDsToDelete,
                dbQueue: dbQueue
            )
        }
    }

    /// Result type for batch modify operation
    private struct BatchModifyResult {
        var savedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []
        var conflictErrors: [(CKRecord.ID, CKError)] = []
    }

    /// Perform batch save/delete with conflict handling
    private func performBatchOperation(recordsToSave: [CKRecord],
                                       recordIDsToDelete: [CKRecord.ID],
                                       dbQueue: DatabaseQueue) async throws {
        // Chunk records into batches of 400 (CloudKit limit)
        let saveChunks = recordsToSave.chunked(into: Self.cloudKitBatchLimit)
        let deleteChunks = recordIDsToDelete.chunked(into: Self.cloudKitBatchLimit)

        let totalBatches = max(saveChunks.count, deleteChunks.count)
        NSLog("SyncEngine: Processing \(recordsToSave.count) saves and \(recordIDsToDelete.count) deletes in \(totalBatches) batch(es)")

        var totalSaved = 0
        var totalDeleted = 0
        var totalConflicts = 0

        // Process save batches
        for (index, saveChunk) in saveChunks.enumerated() {
            NSLog("SyncEngine: Processing save batch \(index + 1)/\(saveChunks.count) (\(saveChunk.count) records)")
            let result = try await performSingleBatchOperation(
                recordsToSave: saveChunk,
                recordIDsToDelete: []
            )
            totalSaved += result.savedRecords.count
            totalConflicts += result.conflictErrors.count

            // Update local records after each batch
            try updateLocalRecordsAfterPush(savedRecords: result.savedRecords, dbQueue: dbQueue)
            if !result.conflictErrors.isEmpty {
                try handleConflicts(result.conflictErrors, dbQueue: dbQueue)
            }
        }

        // Process delete batches
        for (index, deleteChunk) in deleteChunks.enumerated() {
            NSLog("SyncEngine: Processing delete batch \(index + 1)/\(deleteChunks.count) (\(deleteChunk.count) records)")
            let result = try await performSingleBatchOperation(
                recordsToSave: [],
                recordIDsToDelete: deleteChunk
            )
            totalDeleted += result.deletedRecordIDs.count

            try markDeletedRecordsAsSynced(recordIDs: result.deletedRecordIDs, dbQueue: dbQueue)
        }

        NSLog("SyncEngine: Push complete - saved: \(totalSaved), deleted: \(totalDeleted), conflicts: \(totalConflicts)")
    }

    /// Perform a single batch operation (up to 400 records)
    private func performSingleBatchOperation(recordsToSave: [CKRecord],
                                             recordIDsToDelete: [CKRecord.ID]) async throws -> BatchModifyResult {
        let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: recordIDsToDelete)
        operation.savePolicy = .ifServerRecordUnchanged
        operation.isAtomic = false  // Allow partial success

        return try await withCheckedThrowingContinuation { continuation in
            var batchResult = BatchModifyResult()

            operation.perRecordSaveBlock = { recordID, result in
                switch result {
                case .success(let record):
                    batchResult.savedRecords.append(record)
                case .failure(let error):
                    if let ckError = error as? CKError, ckError.code == .serverRecordChanged {
                        batchResult.conflictErrors.append((recordID, ckError))
                    } else {
                        NSLog("SyncEngine: Failed to save record \(recordID.recordName): \(error)")
                    }
                }
            }

            operation.perRecordDeleteBlock = { recordID, result in
                switch result {
                case .success:
                    batchResult.deletedRecordIDs.append(recordID)
                case .failure(let error):
                    // Ignore "not found" errors for deletes
                    if let ckError = error as? CKError, ckError.code == .unknownItem {
                        batchResult.deletedRecordIDs.append(recordID)
                    } else {
                        NSLog("SyncEngine: Failed to delete record \(recordID.recordName): \(error)")
                    }
                }
            }

            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: batchResult)
                case .failure(let error):
                    if let ckError = error as? CKError, ckError.code == .partialFailure {
                        continuation.resume(returning: batchResult)
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }

            self.cloudKitManager.privateDatabase.add(operation)
        }
    }

    // MARK: - Conflict Resolution

    /// Handle conflicts using last-write-wins based on modifiedAt timestamp.
    /// When local wins, updates ck_change_tag and ck_system_fields from server and marks for retry push.
    private func handleConflicts(_ conflicts: [(CKRecord.ID, CKError)], dbQueue: DatabaseQueue) throws {
        NSLog("SyncEngine: Handling \(conflicts.count) conflicts")
        for (recordID, error) in conflicts {
            let recordName = recordID.recordName

            guard let serverRecord = error.serverRecord else {
                // No server record available - clear metadata and mark for retry
                NSLog("SyncEngine: Conflict for \(recordName) has no serverRecord - clearing metadata for retry")
                try dbQueue.write { db in
                    try db.execute(sql: "UPDATE items SET ck_change_tag = NULL, ck_system_fields = NULL, needs_push = 1 WHERE ck_record_name = ?", arguments: [recordName])
                    try db.execute(sql: "UPDATE tags SET ck_change_tag = NULL, ck_system_fields = NULL, needs_push = 1 WHERE ck_record_name = ?", arguments: [recordName])
                    try db.execute(sql: "UPDATE item_tags SET ck_change_tag = NULL, ck_system_fields = NULL, needs_push = 1 WHERE ck_record_name = ?", arguments: [recordName])
                    try db.execute(sql: "UPDATE time_entries SET ck_change_tag = NULL, ck_system_fields = NULL, needs_push = 1 WHERE ck_record_name = ?", arguments: [recordName])
                    try db.execute(sql: "UPDATE saved_searches SET ck_change_tag = NULL, ck_system_fields = NULL, needs_push = 1 WHERE ck_record_name = ?", arguments: [recordName])
                }
                continue
            }

            let serverChangeTag = serverRecord.recordChangeTag
            let serverSystemFields = CKRecordConverters.encodeSystemFields(serverRecord)

            try dbQueue.write { db in
                let serverModifiedAt = serverRecord["modifiedAt"] as? Int ?? 0

                switch serverRecord.recordType {
                case CloudKitManager.RecordType.item:
                    if let localItem = try Item.filter(Column("ck_record_name") == recordName).fetchOne(db) {
                        if localItem.modifiedAt > serverModifiedAt {
                            // Local wins - update change tag/system fields AND mark for retry
                            try db.execute(
                                sql: "UPDATE items SET ck_change_tag = ?, ck_system_fields = ?, needs_push = 1 WHERE ck_record_name = ?",
                                arguments: [serverChangeTag, serverSystemFields, recordName]
                            )
                            NSLog("SyncEngine: Conflict - local item wins, marked for retry push")
                        } else {
                            // Server wins - apply server version
                            if let item = CKRecordConverters.item(from: serverRecord) {
                                try item.save(db, onConflict: .replace)
                            }
                            NSLog("SyncEngine: Conflict - server item wins")
                        }
                    }

                case CloudKitManager.RecordType.tag:
                    if let localTag = try Tag.filter(Column("ck_record_name") == recordName).fetchOne(db),
                       let localModified = localTag.modifiedAt {
                        if localModified > serverModifiedAt {
                            try db.execute(
                                sql: "UPDATE tags SET ck_change_tag = ?, ck_system_fields = ?, needs_push = 1 WHERE ck_record_name = ?",
                                arguments: [serverChangeTag, serverSystemFields, recordName]
                            )
                            NSLog("SyncEngine: Conflict - local tag wins, marked for retry push")
                        } else {
                            if let tag = CKRecordConverters.tag(from: serverRecord) {
                                try tag.save(db, onConflict: .replace)
                            }
                            NSLog("SyncEngine: Conflict - server tag wins")
                        }
                    }

                case CloudKitManager.RecordType.itemTag:
                    if let localItemTag = try ItemTag.filter(Column("ck_record_name") == recordName).fetchOne(db),
                       let localModified = localItemTag.modifiedAt {
                        if localModified > serverModifiedAt {
                            try db.execute(
                                sql: "UPDATE item_tags SET ck_change_tag = ?, ck_system_fields = ?, needs_push = 1 WHERE ck_record_name = ?",
                                arguments: [serverChangeTag, serverSystemFields, recordName]
                            )
                            NSLog("SyncEngine: Conflict - local itemTag wins, marked for retry push")
                        } else {
                            if let itemTag = CKRecordConverters.itemTag(from: serverRecord) {
                                try itemTag.save(db, onConflict: .replace)
                            }
                            NSLog("SyncEngine: Conflict - server itemTag wins")
                        }
                    }

                case CloudKitManager.RecordType.timeEntry:
                    if let localTimeEntry = try TimeEntry.filter(Column("ck_record_name") == recordName).fetchOne(db),
                       let localModified = localTimeEntry.modifiedAt {
                        if localModified > serverModifiedAt {
                            try db.execute(
                                sql: "UPDATE time_entries SET ck_change_tag = ?, ck_system_fields = ?, needs_push = 1 WHERE ck_record_name = ?",
                                arguments: [serverChangeTag, serverSystemFields, recordName]
                            )
                            NSLog("SyncEngine: Conflict - local timeEntry wins, marked for retry push")
                        } else {
                            if let timeEntry = CKRecordConverters.timeEntry(from: serverRecord) {
                                try timeEntry.save(db, onConflict: .replace)
                            }
                            NSLog("SyncEngine: Conflict - server timeEntry wins")
                        }
                    }

                case CloudKitManager.RecordType.savedSearch:
                    if let localSearch = try SavedSearch.filter(Column("ck_record_name") == recordName).fetchOne(db) {
                        if localSearch.modifiedAt > serverModifiedAt {
                            try db.execute(
                                sql: "UPDATE saved_searches SET ck_change_tag = ?, ck_system_fields = ?, needs_push = 1 WHERE ck_record_name = ?",
                                arguments: [serverChangeTag, serverSystemFields, recordName]
                            )
                            NSLog("SyncEngine: Conflict - local savedSearch wins, marked for retry push")
                        } else {
                            if let savedSearch = CKRecordConverters.savedSearch(from: serverRecord) {
                                try savedSearch.save(db, onConflict: .replace)
                            }
                            NSLog("SyncEngine: Conflict - server savedSearch wins")
                        }
                    }

                default:
                    NSLog("SyncEngine: Unhandled conflict for record type: \(serverRecord.recordType)")
                }
            }
        }
    }

    // MARK: - Push Helpers

    private func getDirtyItems(dbQueue: DatabaseQueue) throws -> [Item] {
        try dbQueue.read { db in
            try Item.filter(Column("needs_push") == 1).fetchAll(db)
        }
    }

    private func getDirtyTags(dbQueue: DatabaseQueue) throws -> [Tag] {
        try dbQueue.read { db in
            try Tag.filter(Column("needs_push") == 1).fetchAll(db)
        }
    }

    private func getDirtyItemTags(dbQueue: DatabaseQueue) throws -> [ItemTag] {
        try dbQueue.read { db in
            try ItemTag.filter(Column("needs_push") == 1).fetchAll(db)
        }
    }

    private func getDirtyTimeEntries(dbQueue: DatabaseQueue) throws -> [TimeEntry] {
        try dbQueue.read { db in
            try TimeEntry.filter(Column("needs_push") == 1).fetchAll(db)
        }
    }

    private func getDirtySavedSearches(dbQueue: DatabaseQueue) throws -> [SavedSearch] {
        try dbQueue.read { db in
            try SavedSearch.filter(Column("needs_push") == 1).fetchAll(db)
        }
    }

    private func updateLocalRecordsAfterPush(savedRecords: [CKRecord], dbQueue: DatabaseQueue) throws {
        try dbQueue.write { db in
            for record in savedRecords {
                let recordName = record.recordID.recordName
                let changeTag = record.recordChangeTag
                let systemFields = CKRecordConverters.encodeSystemFields(record)

                switch record.recordType {
                case CloudKitManager.RecordType.item:
                    try db.execute(
                        sql: "UPDATE items SET needs_push = 0, ck_change_tag = ?, ck_system_fields = ? WHERE ck_record_name = ?",
                        arguments: [changeTag, systemFields, recordName]
                    )

                case CloudKitManager.RecordType.tag:
                    try db.execute(
                        sql: "UPDATE tags SET needs_push = 0, ck_change_tag = ?, ck_system_fields = ? WHERE ck_record_name = ?",
                        arguments: [changeTag, systemFields, recordName]
                    )

                case CloudKitManager.RecordType.itemTag:
                    try db.execute(
                        sql: "UPDATE item_tags SET needs_push = 0, ck_change_tag = ?, ck_system_fields = ? WHERE ck_record_name = ?",
                        arguments: [changeTag, systemFields, recordName]
                    )

                case CloudKitManager.RecordType.timeEntry:
                    try db.execute(
                        sql: "UPDATE time_entries SET needs_push = 0, ck_change_tag = ?, ck_system_fields = ? WHERE ck_record_name = ?",
                        arguments: [changeTag, systemFields, recordName]
                    )

                case CloudKitManager.RecordType.savedSearch:
                    try db.execute(
                        sql: "UPDATE saved_searches SET needs_push = 0, ck_change_tag = ?, ck_system_fields = ? WHERE ck_record_name = ?",
                        arguments: [changeTag, systemFields, recordName]
                    )

                default:
                    break
                }
            }
        }
    }

    private func markDeletedRecordsAsSynced(recordIDs: [CKRecord.ID], dbQueue: DatabaseQueue) throws {
        try dbQueue.write { db in
            for recordID in recordIDs {
                let recordName = recordID.recordName

                // Try all tables since we don't know which one it belongs to
                try db.execute(
                    sql: "UPDATE items SET needs_push = 0, ck_change_tag = NULL, ck_system_fields = NULL WHERE ck_record_name = ?",
                    arguments: [recordName]
                )
                try db.execute(
                    sql: "UPDATE tags SET needs_push = 0, ck_change_tag = NULL, ck_system_fields = NULL WHERE ck_record_name = ?",
                    arguments: [recordName]
                )
                try db.execute(
                    sql: "UPDATE item_tags SET needs_push = 0, ck_change_tag = NULL, ck_system_fields = NULL WHERE ck_record_name = ?",
                    arguments: [recordName]
                )
                try db.execute(
                    sql: "UPDATE time_entries SET needs_push = 0, ck_change_tag = NULL, ck_system_fields = NULL WHERE ck_record_name = ?",
                    arguments: [recordName]
                )
                try db.execute(
                    sql: "UPDATE saved_searches SET needs_push = 0, ck_change_tag = NULL, ck_system_fields = NULL WHERE ck_record_name = ?",
                    arguments: [recordName]
                )
            }
        }
    }

    // MARK: - Pull

    private struct ZoneFetchResult {
        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [(CKRecord.ID, CKRecord.RecordType)] = []
        var newChangeToken: CKServerChangeToken?
        var moreComing: Bool = false
    }

    private func pullRemoteChanges() async throws -> Int {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        var currentToken: CKServerChangeToken? = nil
        if let tokenData = try metadataStore.getZoneChangeToken() {
            currentToken = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: tokenData)
        }

        var totalChanged = 0
        var totalDeleted = 0

        repeat {
            do {
                let result = try await fetchZoneChanges(changeToken: currentToken)

                try applyRemoteChanges(
                    changedRecords: result.changedRecords,
                    deletedRecordIDs: result.deletedRecordIDs,
                    dbQueue: dbQueue
                )

                totalChanged += result.changedRecords.count
                totalDeleted += result.deletedRecordIDs.count

                if let newToken = result.newChangeToken {
                    let tokenData = try NSKeyedArchiver.archivedData(withRootObject: newToken, requiringSecureCoding: true)
                    try metadataStore.setZoneChangeToken(tokenData)
                    currentToken = newToken
                }

                if !result.moreComing {
                    break
                }

                NSLog("SyncEngine: More changes coming, fetching next batch...")
            } catch let error as CKError where error.code == .changeTokenExpired {
                // Token expired - clear token and do a full fetch
                // Don't clear local data yet - wait until we successfully get replacement data
                NSLog("SyncEngine: Change token expired, clearing token and retrying full fetch...")
                try metadataStore.setZoneChangeToken(nil)
                currentToken = nil

                // Attempt full fetch - if this succeeds, clear local data first then apply
                let fullResult = try await fetchZoneChanges(changeToken: nil)

                // Successfully got data - now safe to clear local cache and apply
                NSLog("SyncEngine: Full fetch succeeded with \(fullResult.changedRecords.count) records, replacing local data...")
                try await clearLocalData(dbQueue: dbQueue)

                try applyRemoteChanges(
                    changedRecords: fullResult.changedRecords,
                    deletedRecordIDs: fullResult.deletedRecordIDs,
                    dbQueue: dbQueue
                )

                totalChanged += fullResult.changedRecords.count
                totalDeleted += fullResult.deletedRecordIDs.count

                if let newToken = fullResult.newChangeToken {
                    let tokenData = try NSKeyedArchiver.archivedData(withRootObject: newToken, requiringSecureCoding: true)
                    try metadataStore.setZoneChangeToken(tokenData)
                    currentToken = newToken
                }

                if fullResult.moreComing {
                    continue
                } else {
                    break
                }

            } catch let error as CKError where error.code == .zoneNotFound {
                // Zone doesn't exist (was deleted/reset) - recreate and do full fetch
                NSLog("SyncEngine: Zone not found, re-initializing CloudKit...")
                try metadataStore.setZoneChangeToken(nil)
                currentToken = nil

                // Re-initialize to recreate the zone
                try await cloudKitManager.initialize()

                // Full fetch from the (likely empty) zone
                let fullResult = try await fetchZoneChanges(changeToken: nil)

                // Clear local data to match server state (even if empty)
                NSLog("SyncEngine: Zone recreated, clearing local data and applying \(fullResult.changedRecords.count) records...")
                try await clearLocalData(dbQueue: dbQueue)

                try applyRemoteChanges(
                    changedRecords: fullResult.changedRecords,
                    deletedRecordIDs: fullResult.deletedRecordIDs,
                    dbQueue: dbQueue
                )

                totalChanged += fullResult.changedRecords.count
                totalDeleted += fullResult.deletedRecordIDs.count

                if let newToken = fullResult.newChangeToken {
                    let tokenData = try NSKeyedArchiver.archivedData(withRootObject: newToken, requiringSecureCoding: true)
                    try metadataStore.setZoneChangeToken(tokenData)
                    currentToken = newToken
                }

                if fullResult.moreComing {
                    continue
                } else {
                    break
                }
            }
        } while true

        NSLog("SyncEngine: Pull complete - changed: \(totalChanged), deleted: \(totalDeleted)")
        return totalChanged + totalDeleted
    }

    /// Clear all local data (called only after successfully fetching replacement data)
    private func clearLocalData(dbQueue: DatabaseQueue) async throws {
        NSLog("SyncEngine: Clearing local data for full resync")

        try await dbQueue.write { db in
            try db.execute(sql: "DELETE FROM item_tags")
            try db.execute(sql: "DELETE FROM time_entries")
            try db.execute(sql: "DELETE FROM saved_searches")
            try db.execute(sql: "DELETE FROM tags")
            try db.execute(sql: "DELETE FROM items")
        }
    }

    /// Reset sync: clear local data, clear change token, and perform a full resync from CloudKit
    func resetSync() async {
        guard let dbQueue = database.getQueue() else {
            NSLog("SyncEngine: Cannot reset - database not initialized")
            return
        }

        await MainActor.run {
            status = .syncing
        }

        NSLog("SyncEngine: Starting full sync reset")

        do {
            // 1. Clear local data
            try await clearLocalData(dbQueue: dbQueue)

            // 2. Clear all sync metadata (including change token)
            try metadataStore.clearAll()

            // 3. Perform a full pull from CloudKit (nil token = full fetch)
            _ = try await pullRemoteChanges()

            // 4. Update sync state
            try metadataStore.updateLastSyncTimestamp()
            itemCount = try countItems()

            await MainActor.run {
                lastSyncDate = Date()
                status = .idle
            }

            NSLog("SyncEngine: Reset sync completed successfully - \(itemCount) items")
        } catch {
            NSLog("SyncEngine: Reset sync failed - \(error)")
            await MainActor.run {
                status = .error(error.localizedDescription)
            }
        }
    }

    private func fetchZoneChanges(changeToken: CKServerChangeToken?) async throws -> ZoneFetchResult {
        let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        options.previousServerChangeToken = changeToken

        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [cloudKitManager.zoneID],
            configurationsByRecordZoneID: [cloudKitManager.zoneID: options]
        )

        return try await withCheckedThrowingContinuation { continuation in
            var fetchResult = ZoneFetchResult()
            var operationError: Error?

            operation.recordWasChangedBlock = { _, result in
                switch result {
                case .success(let record):
                    fetchResult.changedRecords.append(record)
                case .failure(let error):
                    NSLog("SyncEngine: Error fetching record: \(error)")
                }
            }

            operation.recordWithIDWasDeletedBlock = { recordID, recordType in
                fetchResult.deletedRecordIDs.append((recordID, recordType))
            }

            operation.recordZoneChangeTokensUpdatedBlock = { _, token, _ in
                fetchResult.newChangeToken = token
            }

            operation.recordZoneFetchResultBlock = { [zoneID = self.cloudKitManager.zoneID] fetchedZoneID, result in
                guard fetchedZoneID == zoneID else { return }

                switch result {
                case .success(let (token, _, moreComing)):
                    fetchResult.newChangeToken = token
                    fetchResult.moreComing = moreComing
                case .failure(let error):
                    NSLog("SyncEngine: Zone fetch error: \(error)")
                    operationError = error
                }
            }

            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: fetchResult)
                case .failure(let error):
                    continuation.resume(throwing: operationError ?? error)
                }
            }

            self.cloudKitManager.privateDatabase.add(operation)
        }
    }

    private func applyRemoteChanges(changedRecords: [CKRecord],
                                    deletedRecordIDs: [(CKRecord.ID, CKRecord.RecordType)],
                                    dbQueue: DatabaseQueue) throws {
        // Separate records by type for proper insertion order
        var itemRecords: [CKRecord] = []
        var tagRecords: [CKRecord] = []
        var itemTagRecords: [CKRecord] = []
        var timeEntryRecords: [CKRecord] = []
        var savedSearchRecords: [CKRecord] = []

        for record in changedRecords {
            switch record.recordType {
            case CloudKitManager.RecordType.item:
                itemRecords.append(record)
            case CloudKitManager.RecordType.tag:
                tagRecords.append(record)
            case CloudKitManager.RecordType.itemTag:
                itemTagRecords.append(record)
            case CloudKitManager.RecordType.timeEntry:
                timeEntryRecords.append(record)
            case CloudKitManager.RecordType.savedSearch:
                savedSearchRecords.append(record)
            default:
                NSLog("SyncEngine: Unknown record type: \(record.recordType)")
            }
        }

        // Sort items so parents are inserted before children (topological sort)
        let sortedItems = sortItemsByParentDependency(itemRecords)

        try dbQueue.write { db in
            // 1. Insert tags first (no dependencies)
            for record in tagRecords {
                if let tag = CKRecordConverters.tag(from: record) {
                    try tag.save(db, onConflict: .replace)
                }
            }

            // 2. Insert items in parent-first order
            for record in sortedItems {
                if var item = CKRecordConverters.item(from: record) {
                    if let parentId = item.parentId, !parentId.isEmpty,
                       try Item.fetchOne(db, key: parentId) == nil {
                        NSLog("SyncEngine: Missing parent \(parentId) for item \(item.id) - resetting parent to nil")
                        item.parentId = nil
                    }
                    try item.save(db, onConflict: .replace)
                }
            }

            // 3. Insert item_tags (depends on items and tags)
            for record in itemTagRecords {
                if let itemTag = CKRecordConverters.itemTag(from: record) {
                    try itemTag.save(db, onConflict: .replace)
                }
            }

            // 4. Insert time_entries (depends on items)
            for record in timeEntryRecords {
                if let timeEntry = CKRecordConverters.timeEntry(from: record) {
                    try timeEntry.save(db, onConflict: .replace)
                }
            }

            // 5. Insert saved_searches (no dependencies)
            for record in savedSearchRecords {
                if let savedSearch = CKRecordConverters.savedSearch(from: record) {
                    try savedSearch.save(db, onConflict: .replace)
                }
            }

            // Apply deletions (soft delete)
            let now = Int(Date().timeIntervalSince1970)
            for (recordID, recordType) in deletedRecordIDs {
                let recordName = recordID.recordName

                switch recordType {
                case CloudKitManager.RecordType.item:
                    try db.execute(
                        sql: "UPDATE items SET deleted_at = ? WHERE ck_record_name = ?",
                        arguments: [now, recordName]
                    )

                case CloudKitManager.RecordType.tag:
                    try db.execute(
                        sql: "UPDATE tags SET deleted_at = ? WHERE ck_record_name = ?",
                        arguments: [now, recordName]
                    )

                case CloudKitManager.RecordType.itemTag:
                    try db.execute(
                        sql: "UPDATE item_tags SET deleted_at = ? WHERE ck_record_name = ?",
                        arguments: [now, recordName]
                    )

                case CloudKitManager.RecordType.timeEntry:
                    try db.execute(
                        sql: "UPDATE time_entries SET deleted_at = ? WHERE ck_record_name = ?",
                        arguments: [now, recordName]
                    )

                case CloudKitManager.RecordType.savedSearch:
                    try db.execute(
                        sql: "UPDATE saved_searches SET deleted_at = ? WHERE ck_record_name = ?",
                        arguments: [now, recordName]
                    )

                default:
                    NSLog("SyncEngine: Unknown record type for deletion: \(recordType)")
                }
            }
        }
    }

    /// Sort item records so parents come before children (topological sort)
    private func sortItemsByParentDependency(_ records: [CKRecord]) -> [CKRecord] {
        // Build a map of localId -> record (localId is the item's actual ID used in parentId references)
        var recordByLocalId: [String: CKRecord] = [:]
        for record in records {
            if let localId = record["localId"] as? String {
                recordByLocalId[localId] = record
            }
        }

        // Extract parent relationships: localId -> parentId
        var parentIds: [String: String?] = [:]
        for record in records {
            if let localId = record["localId"] as? String {
                let parentId = record["parentId"] as? String
                parentIds[localId] = parentId
            }
        }

        // Topological sort using Kahn's algorithm
        var result: [CKRecord] = []
        var remaining = Set(recordByLocalId.keys)

        while !remaining.isEmpty {
            // Find records whose parent is either nil, not in this batch, or already processed
            var readyToInsert: [String] = []
            for localId in remaining {
                let parentId = parentIds[localId] ?? nil
                if parentId == nil || !remaining.contains(parentId!) {
                    readyToInsert.append(localId)
                }
            }

            // If no records are ready, we have a cycle - just insert remaining in any order
            if readyToInsert.isEmpty {
                NSLog("SyncEngine: Warning - circular parent reference detected, inserting remaining items")
                for localId in remaining {
                    if let record = recordByLocalId[localId] {
                        result.append(record)
                    }
                }
                break
            }

            // Add ready records to result
            for localId in readyToInsert {
                remaining.remove(localId)
                if let record = recordByLocalId[localId] {
                    result.append(record)
                }
            }
        }

        return result
    }
}

// MARK: - Database Error

enum DatabaseError: Error, LocalizedError {
    case notInitialized

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Database not initialized"
        }
    }
}
