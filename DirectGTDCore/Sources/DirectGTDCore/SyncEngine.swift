//
//  SyncEngine.swift
//  DirectGTDCore
//
//  Orchestrates push/pull sync operations with CloudKit.
//

import Foundation
import CloudKit
import GRDB
import Combine

/// Orchestrates push/pull sync operations with CloudKit.
/// Handles dirty tracking, batch uploads, change token management, conflict resolution,
/// and automatic retry with exponential backoff.
public class SyncEngine: ObservableObject {
    private let cloudKitManager: CloudKitManagerProtocol
    private let database: DatabaseProvider
    private let metadataStore: SyncMetadataStore

    /// Sync status for UI
    public enum SyncStatus: Equatable {
        case disabled          // Sync not available (no iCloud account)
        case idle              // Ready to sync
        case syncing           // Sync in progress
        case initialSync(progress: Double, message: String)  // First-time sync with progress
        case error(String)     // Last sync failed

        public static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
            switch (lhs, rhs) {
            case (.disabled, .disabled), (.idle, .idle), (.syncing, .syncing):
                return true
            case (.initialSync(let p1, let m1), .initialSync(let p2, let m2)):
                return p1 == p2 && m1 == m2
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    @Published public private(set) var status: SyncStatus = .idle
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var iCloudAccountName: String?
    @Published public private(set) var isInitialSyncComplete: Bool = true
    @Published public var isSyncEnabled: Bool = true {
        didSet {
            if oldValue != isSyncEnabled {
                Task {
                    await handleSyncEnabledChange()
                }
            }
        }
    }

    // Retry configuration
    private let maxRetryAttempts = 3
    private let baseRetryDelay: TimeInterval = 2.0  // seconds
    private var currentRetryAttempt = 0
    private var retryTask: Task<Void, Never>?

    // Debounce sync requests
    private var pendingSyncTask: Task<Void, Never>?
    private let syncDebounceInterval: TimeInterval = 1.0

    // Account monitoring
    private var accountChangeObserver: NSObjectProtocol?

    // Tombstone cleanup
    private let tombstoneRetentionDays = 30

    // Periodic sync timer (fallback when push notifications don't work)
    private var periodicSyncTimer: Timer?
    private let periodicSyncInterval: TimeInterval = 5 * 60  // 5 minutes

    public init(cloudKitManager: CloudKitManagerProtocol,
                database: DatabaseProvider) {
        self.cloudKitManager = cloudKitManager
        self.database = database

        if let queue = database.getQueue() {
            self.metadataStore = SyncMetadataStore(dbQueue: queue)
            // Load last sync date
            if let timestamp = try? metadataStore.getLastSyncTimestamp() {
                lastSyncDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
            }
            // Load initial sync status
            isInitialSyncComplete = (try? metadataStore.isInitialSyncComplete()) ?? false
            // Load sync enabled preference
            isSyncEnabled = (try? metadataStore.isSyncEnabled()) ?? true
        } else {
            fatalError("SyncEngine requires initialized database")
        }

        setupAccountChangeObserver()
    }

    deinit {
        if let observer = accountChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        periodicSyncTimer?.invalidate()
    }

    // MARK: - Public API

    /// Start sync engine - initialize CloudKit and register for notifications
    public func start() async {
        guard isSyncEnabled else {
            await MainActor.run { status = .disabled }
            NSLog("SyncEngine: Sync disabled by user")
            return
        }

        do {
            try await cloudKitManager.initialize()
            try await cloudKitManager.registerForSubscriptions()

            // Fetch account info
            await fetchAccountInfo()

            await MainActor.run { status = .idle }

            // Check if this is the first sync
            let needsInitialSync = !(try metadataStore.isInitialSyncComplete())
            if needsInitialSync {
                await MainActor.run { isInitialSyncComplete = false }
                try await performInitialSync()
            } else {
                // Perform regular sync (which includes tombstone cleanup)
                try await sync()
            }

            // Start periodic sync timer as fallback for unreliable push notifications
            startPeriodicSyncTimer()
        } catch let error as CloudKitError {
            await MainActor.run {
                if case .accountNotAvailable = error {
                    status = .disabled
                } else {
                    status = .error(error.localizedDescription)
                }
            }
            NSLog("SyncEngine: Failed to start - \(error)")
        } catch {
            await MainActor.run { status = .error(error.localizedDescription) }
            NSLog("SyncEngine: Failed to start - \(error)")
        }
    }

    /// Stop sync engine
    public func stop() async {
        retryTask?.cancel()
        pendingSyncTask?.cancel()
        stopPeriodicSyncTimer()

        do {
            try await cloudKitManager.unregisterSubscriptions()
        } catch {
            NSLog("SyncEngine: Error unregistering subscriptions - \(error)")
        }

        await MainActor.run { status = .disabled }
    }

    /// Request a sync (debounced to avoid rapid-fire syncs)
    public func requestSync() {
        pendingSyncTask?.cancel()
        pendingSyncTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(syncDebounceInterval * 1_000_000_000))
            guard !Task.isCancelled else { return }

            do {
                try await sync()
            } catch {
                NSLog("SyncEngine: Requested sync failed - \(error)")
            }
        }
    }

    /// Handle remote notification (called from AppDelegate)
    /// Handle a remote notification from CloudKit.
    /// Returns true if changes were fetched, false otherwise.
    @discardableResult
    public func handleRemoteNotification(userInfo: [AnyHashable: Any]) async -> Bool {
        NSLog("SyncEngine: Received remote notification")

        // Parse the notification to check if it's a CloudKit notification
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)

        guard notification?.subscriptionID == CloudKitConfig.subscriptionID else {
            NSLog("SyncEngine: Notification not for our subscription")
            return false
        }

        // Trigger a pull to get the latest changes
        do {
            let changeCount = try await pullRemoteChanges()
            NSLog("SyncEngine: Pulled \(changeCount) changes from notification")

            // Run tombstone cleanup after successful pull
            try await cleanupTombstones()

            return changeCount > 0
        } catch {
            NSLog("SyncEngine: Failed to pull after notification - \(error)")
            return false
        }
    }

    // MARK: - Full Sync

    /// Perform a full sync: push local changes, then pull remote changes
    public func sync() async throws {
        guard status != .disabled else {
            NSLog("SyncEngine: Sync skipped - disabled")
            return
        }

        await MainActor.run { status = .syncing }
        currentRetryAttempt = 0

        do {
            // Ensure CloudKit is ready
            try await cloudKitManager.initialize()

            // Push local changes first
            try await pushLocalChanges()

            // Then pull remote changes
            let changeCount = try await pullRemoteChanges()

            // If pull returned 0 changes, verify we're actually in sync
            // This detects stale change tokens that miss updates
            if changeCount == 0 {
                try await detectAndRecoverFromDrift()
            }

            try metadataStore.updateLastSyncTimestamp()

            await MainActor.run {
                status = .idle
                lastSyncDate = Date()
            }
            NSLog("SyncEngine: Sync completed successfully")

            // Run tombstone cleanup after successful sync
            try await cleanupTombstones()
        } catch {
            await handleSyncError(error)
            throw error
        }
    }

    // MARK: - Error Handling & Retry

    private func handleSyncError(_ error: Error) async {
        // Check if this is a retryable error
        if isRetryableError(error) && currentRetryAttempt < maxRetryAttempts {
            currentRetryAttempt += 1
            let delay = calculateRetryDelay()

            NSLog("SyncEngine: Retryable error, attempt \(currentRetryAttempt)/\(maxRetryAttempts), retrying in \(delay)s")

            await MainActor.run {
                status = .error("Retrying... (\(currentRetryAttempt)/\(maxRetryAttempts))")
            }

            retryTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { return }

                do {
                    try await sync()
                } catch {
                    NSLog("SyncEngine: Retry attempt \(currentRetryAttempt) failed")
                }
            }
        } else {
            await MainActor.run {
                status = .error(error.localizedDescription)
            }
            NSLog("SyncEngine: Sync failed (non-retryable or max attempts reached) - \(error)")

            // Auto-dismiss error after 10 seconds
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                await MainActor.run {
                    if case .error = status {
                        status = .idle
                    }
                }
            }
        }
    }

    private func isRetryableError(_ error: Error) -> Bool {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable, .networkFailure, .serviceUnavailable,
                 .requestRateLimited, .zoneBusy, .operationCancelled:
                return true
            default:
                return false
            }
        }
        // Network errors are retryable
        if (error as NSError).domain == NSURLErrorDomain {
            return true
        }
        return false
    }

    private func calculateRetryDelay() -> TimeInterval {
        // Exponential backoff: 2s, 4s, 8s, ...
        let delay = baseRetryDelay * pow(2.0, Double(currentRetryAttempt - 1))
        // Add jitter (±25%)
        let jitter = delay * Double.random(in: -0.25...0.25)
        return delay + jitter
    }

    // MARK: - Initial Sync

    /// Perform initial sync with progress reporting
    private func performInitialSync() async throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        NSLog("SyncEngine: Starting initial sync")

        // Count total records to sync for progress calculation
        let totalItems = try await dbQueue.read { db in try Item.fetchCount(db) }
        let totalTags = try await dbQueue.read { db in try Tag.fetchCount(db) }
        let totalItemTags = try await dbQueue.read { db in try ItemTag.fetchCount(db) }
        let totalTimeEntries = try await dbQueue.read { db in try TimeEntry.fetchCount(db) }
        let totalSavedSearches = try await dbQueue.read { db in try SavedSearch.fetchCount(db) }
        let totalRecords = totalItems + totalTags + totalItemTags + totalTimeEntries + totalSavedSearches

        NSLog("SyncEngine: Initial sync - \(totalRecords) total records to sync")

        // Phase 1: Push local changes (40% of progress)
        await MainActor.run {
            status = .initialSync(progress: 0.0, message: "Preparing to sync \(totalRecords) records...")
        }

        await MainActor.run {
            status = .initialSync(progress: 0.1, message: "Uploading items...")
        }
        try await pushLocalChanges()

        await MainActor.run {
            status = .initialSync(progress: 0.4, message: "Uploading complete")
        }

        // Phase 2: Pull remote changes (40% of progress)
        await MainActor.run {
            status = .initialSync(progress: 0.5, message: "Downloading remote changes...")
        }
        try await pullRemoteChanges()

        await MainActor.run {
            status = .initialSync(progress: 0.8, message: "Download complete")
        }

        // Phase 3: Finalize (20% of progress)
        await MainActor.run {
            status = .initialSync(progress: 0.9, message: "Finalizing...")
        }

        try metadataStore.updateLastSyncTimestamp()
        try metadataStore.setInitialSyncComplete(true)

        // Run tombstone cleanup after successful initial sync
        try await cleanupTombstones()

        await MainActor.run {
            status = .initialSync(progress: 1.0, message: "Sync complete!")
            isInitialSyncComplete = true
            lastSyncDate = Date()
        }

        // Brief pause to show completion
        try? await Task.sleep(nanoseconds: 500_000_000)

        await MainActor.run {
            status = .idle
        }

        NSLog("SyncEngine: Initial sync completed successfully")
    }

    // MARK: - Account Management

    /// Setup observer for iCloud account changes
    private func setupAccountChangeObserver() {
        accountChangeObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            NSLog("SyncEngine: iCloud account changed notification received")
            Task {
                await self?.handleAccountChange()
            }
        }
    }

    /// Handle iCloud account change (sign in, sign out, switch)
    private func handleAccountChange() async {
        NSLog("SyncEngine: Handling account change")

        // Re-check account status
        do {
            let accountStatus = try await cloudKitManager.checkAccountStatus()

            await MainActor.run {
                if accountStatus == .available {
                    // Account is available - restart sync
                    NSLog("SyncEngine: Account available, restarting sync")
                } else {
                    // Account not available - disable sync
                    NSLog("SyncEngine: Account not available, disabling sync")
                    status = .disabled
                    iCloudAccountName = nil
                }
            }

            if accountStatus == .available {
                await fetchAccountInfo()
                await start()
            }
        } catch {
            NSLog("SyncEngine: Error checking account status after change: \(error)")
            await MainActor.run {
                status = .error("Account error: \(error.localizedDescription)")
            }
        }
    }

    /// Fetch iCloud account display name
    private func fetchAccountInfo() async {
        do {
            let userRecordID = try await cloudKitManager.container.userRecordID()
            // Try to discover user identity
            let identity = try? await cloudKitManager.container.userIdentity(forUserRecordID: userRecordID)
            let name = identity?.nameComponents?.formatted() ?? userRecordID.recordName

            await MainActor.run {
                iCloudAccountName = name
            }
            NSLog("SyncEngine: Fetched account info: \(name)")
        } catch {
            NSLog("SyncEngine: Could not fetch account info: \(error)")
        }
    }

    /// Handle sync enabled/disabled toggle
    private func handleSyncEnabledChange() async {
        do {
            try metadataStore.setSyncEnabled(isSyncEnabled)

            if isSyncEnabled {
                NSLog("SyncEngine: Sync enabled by user, starting")
                await start()
            } else {
                NSLog("SyncEngine: Sync disabled by user, stopping")
                await stop()
            }
        } catch {
            NSLog("SyncEngine: Error saving sync enabled state: \(error)")
        }
    }

    // MARK: - Periodic Sync Timer

    /// Start periodic sync timer as fallback for unreliable push notifications
    private func startPeriodicSyncTimer() {
        // Must run on main thread for Timer
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Invalidate any existing timer
            self.periodicSyncTimer?.invalidate()

            // Create new timer
            self.periodicSyncTimer = Timer.scheduledTimer(
                withTimeInterval: self.periodicSyncInterval,
                repeats: true
            ) { [weak self] _ in
                NSLog("SyncEngine: Periodic sync timer fired")
                self?.requestSync()
            }

            NSLog("SyncEngine: Periodic sync timer started (interval: \(self.periodicSyncInterval)s)")
        }
    }

    /// Stop periodic sync timer
    private func stopPeriodicSyncTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.periodicSyncTimer?.invalidate()
            self?.periodicSyncTimer = nil
            NSLog("SyncEngine: Periodic sync timer stopped")
        }
    }

    // MARK: - Tombstone Cleanup

    /// Purge tombstones older than retention period that have been synced
    public func cleanupTombstones() async throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        let cutoffTimestamp = Int(Date().timeIntervalSince1970) - (tombstoneRetentionDays * 24 * 60 * 60)
        NSLog("SyncEngine: Cleaning up tombstones older than \(tombstoneRetentionDays) days (cutoff: \(cutoffTimestamp))")

        try await dbQueue.write { db in
            // Only purge tombstones that:
            // 1. Have been soft-deleted (deleted_at IS NOT NULL)
            // 2. Are older than retention period
            // 3. Have been synced to CloudKit (needs_push = 0)

            // Purge item_tags first (junction table)
            try db.execute(
                sql: """
                    DELETE FROM item_tags
                    WHERE deleted_at IS NOT NULL
                    AND deleted_at < ?
                    AND (needs_push = 0 OR needs_push IS NULL)
                    """,
                arguments: [cutoffTimestamp]
            )
            NSLog("SyncEngine: Purged \(db.changesCount) item_tags tombstones")

            // Purge time_entries
            try db.execute(
                sql: """
                    DELETE FROM time_entries
                    WHERE deleted_at IS NOT NULL
                    AND deleted_at < ?
                    AND (needs_push = 0 OR needs_push IS NULL)
                    """,
                arguments: [cutoffTimestamp]
            )
            NSLog("SyncEngine: Purged \(db.changesCount) time_entries tombstones")

            // Purge tags (only if no item_tags reference them - even tombstoned ones)
            try db.execute(
                sql: """
                    DELETE FROM tags
                    WHERE deleted_at IS NOT NULL
                    AND deleted_at < ?
                    AND (needs_push = 0 OR needs_push IS NULL)
                    AND id NOT IN (SELECT tag_id FROM item_tags)
                    """,
                arguments: [cutoffTimestamp]
            )
            NSLog("SyncEngine: Purged \(db.changesCount) tags tombstones")

            // Purge saved_searches
            try db.execute(
                sql: """
                    DELETE FROM saved_searches
                    WHERE deleted_at IS NOT NULL
                    AND deleted_at < ?
                    AND (needs_push = 0 OR needs_push IS NULL)
                    """,
                arguments: [cutoffTimestamp]
            )
            NSLog("SyncEngine: Purged \(db.changesCount) saved_searches tombstones")

            // Purge items (only leaf nodes first - items with no children)
            // We need to do this in multiple passes until no more can be deleted
            var totalItemsDeleted = 0
            var passDeleted: Int
            repeat {
                try db.execute(
                    sql: """
                        DELETE FROM items
                        WHERE deleted_at IS NOT NULL
                        AND deleted_at < ?
                        AND (needs_push = 0 OR needs_push IS NULL)
                        AND id NOT IN (SELECT parent_id FROM items WHERE parent_id IS NOT NULL)
                        AND id NOT IN (SELECT item_id FROM item_tags)
                        AND id NOT IN (SELECT item_id FROM time_entries)
                        """,
                    arguments: [cutoffTimestamp]
                )
                passDeleted = db.changesCount
                totalItemsDeleted += passDeleted
            } while passDeleted > 0

            NSLog("SyncEngine: Purged \(totalItemsDeleted) items tombstones")
        }
    }

    /// Reset sync state (for account switch or troubleshooting)
    public func resetSyncState() async throws {
        NSLog("SyncEngine: Resetting sync state")

        // Stop any ongoing sync
        await stop()

        // Clear all sync metadata
        try metadataStore.clearAll()

        // Mark all records as needing push
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        try await dbQueue.write { db in
            try db.execute(sql: "UPDATE items SET needs_push = 1, ck_change_tag = NULL, ck_system_fields = NULL")
            try db.execute(sql: "UPDATE tags SET needs_push = 1, ck_change_tag = NULL, ck_system_fields = NULL")
            try db.execute(sql: "UPDATE item_tags SET needs_push = 1, ck_change_tag = NULL, ck_system_fields = NULL")
            try db.execute(sql: "UPDATE time_entries SET needs_push = 1, ck_change_tag = NULL, ck_system_fields = NULL")
            try db.execute(sql: "UPDATE saved_searches SET needs_push = 1, ck_change_tag = NULL, ck_system_fields = NULL")
        }

        await MainActor.run {
            isInitialSyncComplete = false
            lastSyncDate = nil
            status = .idle
        }

        NSLog("SyncEngine: Sync state reset complete")
    }

    // MARK: - Push

    /// Push all dirty records to CloudKit
    public func pushLocalChanges() async throws {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        // Get all dirty records
        let dirtyItems = try getDirtyItems(dbQueue: dbQueue)
        let dirtyTags = try getDirtyTags(dbQueue: dbQueue)
        let dirtyItemTags = try getDirtyItemTags(dbQueue: dbQueue)
        let dirtyTimeEntries = try getDirtyTimeEntries(dbQueue: dbQueue)
        let dirtySavedSearches = try getDirtySavedSearches(dbQueue: dbQueue)

        NSLog("SyncEngine: Pushing \(dirtyItems.count) items, \(dirtyTags.count) tags, \(dirtyItemTags.count) itemTags, \(dirtyTimeEntries.count) timeEntries, \(dirtySavedSearches.count) savedSearches")

        // Separate records to save vs delete
        var recordsToSave: [CKRecord] = []
        var recordIDsToDelete: [CKRecord.ID] = []

        // Process items
        for item in dirtyItems {
            if item.deletedAt != nil {
                // This is a tombstone - delete from CloudKit
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

    /// CloudKit batch size limit
    private static let cloudKitBatchLimit = 400

    /// Perform batch save/delete with conflict handling, waiting for completion
    /// Automatically chunks records into batches of 400 to respect CloudKit limits
    private func performBatchOperation(recordsToSave: [CKRecord],
                                       recordIDsToDelete: [CKRecord.ID],
                                       dbQueue: DatabaseQueue) async throws {
        // Chunk records into batches of 400 (CloudKit limit)
        let saveChunks = recordsToSave.chunked(into: Self.cloudKitBatchLimit)
        let deleteChunks = recordIDsToDelete.chunked(into: Self.cloudKitBatchLimit)

        // Calculate total batches for logging
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
                recordIDsToDelete: [],
                dbQueue: dbQueue
            )
            totalSaved += result.savedRecords.count
            totalConflicts += result.conflictErrors.count

            // Process results immediately after each batch
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
                recordIDsToDelete: deleteChunk,
                dbQueue: dbQueue
            )
            totalDeleted += result.deletedRecordIDs.count

            // Process results immediately after each batch
            try markDeletedRecordsAsSynced(recordIDs: result.deletedRecordIDs, dbQueue: dbQueue)
        }

        NSLog("SyncEngine: Push complete - saved: \(totalSaved), deleted: \(totalDeleted), conflicts: \(totalConflicts)")
    }

    /// Perform a single batch operation (up to 400 records)
    private func performSingleBatchOperation(recordsToSave: [CKRecord],
                                             recordIDsToDelete: [CKRecord.ID],
                                             dbQueue: DatabaseQueue) async throws -> BatchModifyResult {
        let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: recordIDsToDelete)
        operation.savePolicy = .ifServerRecordUnchanged
        operation.isAtomic = false  // Allow partial success

        // Use continuation to wait for operation completion
        let result: BatchModifyResult = try await withCheckedThrowingContinuation { continuation in
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
                        batchResult.deletedRecordIDs.append(recordID)  // Consider it deleted
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
                    // Check if it's a partial failure - we still want to process successful records
                    if let ckError = error as? CKError, ckError.code == .partialFailure {
                        // Partial failure is expected when some records fail - continue with what succeeded
                        continuation.resume(returning: batchResult)
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }

            self.cloudKitManager.privateDatabase.add(operation)
        }

        return result
    }

    // MARK: - Pull

    /// Result type for zone fetch operation
    private struct ZoneFetchResult {
        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [(CKRecord.ID, CKRecord.RecordType)] = []
        var newChangeToken: CKServerChangeToken?
        var moreComing: Bool = false
    }

    /// Pull remote changes using stored change token, looping until moreComing is false
    /// Pull remote changes from CloudKit.
    /// Returns the total number of changes (changed + deleted records).
    @discardableResult
    public func pullRemoteChanges() async throws -> Int {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        var currentToken: CKServerChangeToken? = nil
        if let tokenData = try metadataStore.getZoneChangeToken() {
            currentToken = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: tokenData)
        }

        var totalChanged = 0
        var totalDeleted = 0

        // Loop until server indicates we're caught up (moreComing == false)
        repeat {
            let result = try await fetchZoneChanges(changeToken: currentToken)

            // Apply changes to local database
            NSLog("SyncEngine: Applying \(result.changedRecords.count) changes and \(result.deletedRecordIDs.count) deletions...")
            try applyRemoteChanges(changedRecords: result.changedRecords, deletedRecordIDs: result.deletedRecordIDs, dbQueue: dbQueue)
            NSLog("SyncEngine: Apply complete")

            totalChanged += result.changedRecords.count
            totalDeleted += result.deletedRecordIDs.count

            // Save change token after each batch
            if let newToken = result.newChangeToken {
                let tokenData = try NSKeyedArchiver.archivedData(withRootObject: newToken, requiringSecureCoding: true)
                try metadataStore.setZoneChangeToken(tokenData)
                currentToken = newToken
            }

            // Continue if there are more changes
            if !result.moreComing {
                break
            }

            NSLog("SyncEngine: More changes coming, fetching next batch...")
        } while true

        NSLog("SyncEngine: Pull complete - changed: \(totalChanged), deleted: \(totalDeleted)")
        return totalChanged + totalDeleted
    }

    /// Fetch a single batch of zone changes
    private func fetchZoneChanges(changeToken: CKServerChangeToken?) async throws -> ZoneFetchResult {
        NSLog("SyncEngine: Starting zone fetch (hasToken=\(changeToken != nil))")

        let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        options.previousServerChangeToken = changeToken

        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [cloudKitManager.zoneID],
            configurationsByRecordZoneID: [cloudKitManager.zoneID: options]
        )
        operation.qualityOfService = .userInitiated

        return try await withCheckedThrowingContinuation { continuation in
            var fetchResult = ZoneFetchResult()
            var operationError: Error?
            var recordCount = 0

            operation.recordWasChangedBlock = { _, result in
                switch result {
                case .success(let record):
                    fetchResult.changedRecords.append(record)
                    recordCount += 1
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
                    NSLog("SyncEngine: Zone fetch result - changed=\(fetchResult.changedRecords.count), deleted=\(fetchResult.deletedRecordIDs.count), moreComing=\(moreComing)")
                case .failure(let error):
                    NSLog("SyncEngine: Zone fetch error: \(error)")
                    operationError = error
                }
            }

            operation.fetchRecordZoneChangesResultBlock = { result in
                NSLog("SyncEngine: Fetch operation completed")
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

    // MARK: - Drift Detection & Auto-Recovery

    /// Count local Item records (non-deleted)
    private func countLocalItems() throws -> Int {
        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        return try dbQueue.read { db in
            try Item.filter(Column("deleted_at") == nil).fetchCount(db)
        }
    }

    /// Detect and recover from sync drift (stale change token)
    /// Called when pull returns 0 changes to verify we're actually in sync
    /// Uses a full zone fetch (nil token) to get true CloudKit state
    private func detectAndRecoverFromDrift() async throws {
        NSLog("SyncEngine: Checking for sync drift...")

        guard let dbQueue = database.getQueue() else {
            throw DatabaseError.notInitialized
        }

        // Do a full fetch from CloudKit (nil token = all records)
        let fullFetchResult = try await fetchZoneChanges(changeToken: nil)

        // Count Item records from CloudKit
        let cloudKitItemCount = fullFetchResult.changedRecords.filter {
            $0.recordType == CloudKitRecordType.item
        }.count

        let localCount = try countLocalItems()
        let drift = abs(cloudKitItemCount - localCount)

        NSLog("SyncEngine: CloudKit has \(cloudKitItemCount) items, local has \(localCount) items (drift: \(drift))")

        if drift > 0 {
            NSLog("SyncEngine: ⚠️ Drift detected! Applying \(fullFetchResult.changedRecords.count) records from full fetch...")

            // Apply the records we just fetched
            try applyRemoteChanges(
                changedRecords: fullFetchResult.changedRecords,
                deletedRecordIDs: fullFetchResult.deletedRecordIDs,
                dbQueue: dbQueue
            )

            // Save the new change token
            if let newToken = fullFetchResult.newChangeToken {
                let tokenData = try NSKeyedArchiver.archivedData(withRootObject: newToken, requiringSecureCoding: true)
                try metadataStore.setZoneChangeToken(tokenData)
            }

            NSLog("SyncEngine: Drift recovery complete")
        } else {
            NSLog("SyncEngine: No drift detected, sync is healthy")
        }
    }

    /// Apply remote changes to local database
    private func applyRemoteChanges(changedRecords: [CKRecord],
                                    deletedRecordIDs: [(CKRecord.ID, CKRecord.RecordType)],
                                    dbQueue: DatabaseQueue) throws {
        // Separate records by type for proper ordering
        // Order must be: tags -> items -> item_tags -> time_entries -> saved_searches
        // This ensures foreign key dependencies are satisfied
        var tagRecords: [CKRecord] = []
        var itemRecords: [CKRecord] = []
        var itemTagRecords: [CKRecord] = []
        var timeEntryRecords: [CKRecord] = []
        var savedSearchRecords: [CKRecord] = []

        for record in changedRecords {
            switch record.recordType {
            case CloudKitRecordType.tag:
                tagRecords.append(record)
            case CloudKitRecordType.item:
                itemRecords.append(record)
            case CloudKitRecordType.itemTag:
                itemTagRecords.append(record)
            case CloudKitRecordType.timeEntry:
                timeEntryRecords.append(record)
            case CloudKitRecordType.savedSearch:
                savedSearchRecords.append(record)
            default:
                break
            }
        }

        // Sort item records by hierarchy: parents before children
        let sortedItemRecords = topologicalSortItems(itemRecords)

        try dbQueue.write { db in
            // Track applied item IDs in-memory to reduce DB lookups
            var appliedItemIds = Set<String>()
            var appliedTagIds = Set<String>()

            // Helper to check if item exists (in-memory or DB)
            func itemExists(_ id: String) throws -> Bool {
                if appliedItemIds.contains(id) { return true }
                if try Item.fetchOne(db, key: id) != nil {
                    appliedItemIds.insert(id)
                    return true
                }
                return false
            }

            // Helper to check if tag exists (in-memory or DB)
            func tagExists(_ id: String) throws -> Bool {
                if appliedTagIds.contains(id) { return true }
                if try Tag.fetchOne(db, key: id) != nil {
                    appliedTagIds.insert(id)
                    return true
                }
                return false
            }

            // 1. Tags first (no dependencies)
            for record in tagRecords {
                try applyChangedRecord(record, to: db)
                if let tag = CKRecordConverters.tag(from: record) {
                    appliedTagIds.insert(tag.id)
                }
            }

            // 2. Items with multi-pass retry for deep chains
            var pendingItems = sortedItemRecords
            let maxRetryPasses = 3
            var pass = 0

            while !pendingItems.isEmpty && pass < maxRetryPasses {
                pass += 1
                var stillPending: [CKRecord] = []

                for record in pendingItems {
                    if let item = CKRecordConverters.item(from: record),
                       let parentId = item.parentId, !parentId.isEmpty {
                        if try !itemExists(parentId) {
                            if pass < maxRetryPasses {
                                NSLog("SyncEngine: Deferring item \(item.id) - parent \(parentId) not ready (pass \(pass))")
                                stillPending.append(record)
                                continue
                            } else {
                                NSLog("SyncEngine: Skipping item \(item.id) - parent \(parentId) still missing after \(maxRetryPasses) passes")
                                continue
                            }
                        }
                    }
                    try applyChangedRecord(record, to: db)
                    if let item = CKRecordConverters.item(from: record) {
                        appliedItemIds.insert(item.id)
                    }
                }

                pendingItems = stillPending
            }

            // Log any unresolved items
            for record in pendingItems {
                if let item = CKRecordConverters.item(from: record) {
                    NSLog("SyncEngine: Unresolved item \(item.id) after all retry passes - parent chain incomplete")
                }
            }

            // 3. ItemTags with retry
            var pendingItemTags = itemTagRecords
            var retriedItemTags: [CKRecord] = []

            for record in pendingItemTags {
                if try !applyItemTagIfReady(record, to: db, itemExists: itemExists, tagExists: tagExists) {
                    retriedItemTags.append(record)
                }
            }

            // Retry once after items are applied
            for record in retriedItemTags {
                if try !applyItemTagIfReady(record, to: db, itemExists: itemExists, tagExists: tagExists) {
                    if let itemTag = CKRecordConverters.itemTag(from: record) {
                        NSLog("SyncEngine: Unresolved item_tag (item=\(itemTag.itemId), tag=\(itemTag.tagId)) after retry")
                    }
                }
            }

            // 4. TimeEntries with retry
            let pendingTimeEntries = timeEntryRecords
            var retriedTimeEntries: [CKRecord] = []

            for record in pendingTimeEntries {
                if try !applyTimeEntryIfReady(record, to: db, itemExists: itemExists) {
                    retriedTimeEntries.append(record)
                }
            }

            // Retry once
            for record in retriedTimeEntries {
                if try !applyTimeEntryIfReady(record, to: db, itemExists: itemExists) {
                    if let timeEntry = CKRecordConverters.timeEntry(from: record) {
                        NSLog("SyncEngine: Unresolved time_entry (id=\(timeEntry.id), item=\(timeEntry.itemId)) after retry")
                    }
                }
            }

            // 5. SavedSearches (no dependencies)
            for record in savedSearchRecords {
                try applyChangedRecord(record, to: db)
            }

            // Apply deletions
            for (recordID, recordType) in deletedRecordIDs {
                let now = Int(Date().timeIntervalSince1970)
                let recordName = recordID.recordName

                switch recordType {
                case CloudKitRecordType.item:
                    // Soft-delete locally
                    try db.execute(
                        sql: "UPDATE items SET deleted_at = ?, needs_push = 0 WHERE ck_record_name = ?",
                        arguments: [now, recordName]
                    )

                case CloudKitRecordType.tag:
                    try db.execute(
                        sql: "UPDATE tags SET deleted_at = ?, needs_push = 0 WHERE ck_record_name = ?",
                        arguments: [now, recordName]
                    )

                case CloudKitRecordType.itemTag:
                    try db.execute(
                        sql: "UPDATE item_tags SET deleted_at = ?, needs_push = 0 WHERE ck_record_name = ?",
                        arguments: [now, recordName]
                    )

                case CloudKitRecordType.timeEntry:
                    try db.execute(
                        sql: "UPDATE time_entries SET deleted_at = ?, needs_push = 0 WHERE ck_record_name = ?",
                        arguments: [now, recordName]
                    )

                case CloudKitRecordType.savedSearch:
                    try db.execute(
                        sql: "UPDATE saved_searches SET deleted_at = ?, needs_push = 0 WHERE ck_record_name = ?",
                        arguments: [now, recordName]
                    )

                default:
                    break
                }
            }
        }
    }

    /// Topologically sort item records so parents come before children.
    /// Uses CKRecordConverters to extract IDs consistently with the rest of the sync logic.
    /// Preserves original order where hierarchy doesn't dictate otherwise.
    private func topologicalSortItems(_ records: [CKRecord]) -> [CKRecord] {
        // Build mappings: convert once, reuse everywhere
        var originalIndex: [String: Int] = [:]       // itemId -> original index
        var recordByItemId: [String: CKRecord] = [:]
        var itemIdByRecordName: [String: String] = [:] // recordName -> itemId
        var itemById: [String: Item] = [:]
        var failedRecords: [CKRecord] = []

        for (index, record) in records.enumerated() {
            if let item = CKRecordConverters.item(from: record) {
                originalIndex[item.id] = index
                recordByItemId[item.id] = record
                itemIdByRecordName[record.recordID.recordName] = item.id
                itemById[item.id] = item
            } else {
                NSLog("SyncEngine: topologicalSort - failed to convert record: \(record.recordID.recordName)")
                failedRecords.append(record)
            }
        }

        // Build parent-child relationships in original order
        var childrenOf: [String: [String]] = [:]  // parentId -> [childIds]
        var rootIds: [String] = []
        var rootIdSet = Set<String>()

        for record in records {
            guard let itemId = itemIdByRecordName[record.recordID.recordName],
                  let item = itemById[itemId] else {
                continue
            }

            if let parentId = item.parentId, !parentId.isEmpty {
                childrenOf[parentId, default: []].append(item.id)
                // If parent not in this batch, treat as root
                if itemById[parentId] == nil && !rootIdSet.contains(item.id) {
                    rootIds.append(item.id)
                    rootIdSet.insert(item.id)
                }
            } else {
                if !rootIdSet.contains(item.id) {
                    rootIds.append(item.id)
                    rootIdSet.insert(item.id)
                }
            }
        }

        // BFS from roots to build sorted order
        var sorted: [CKRecord] = []
        var queue = rootIds
        var visited = Set<String>()

        while !queue.isEmpty {
            let id = queue.removeFirst()
            guard !visited.contains(id) else { continue }
            visited.insert(id)

            if let record = recordByItemId[id] {
                sorted.append(record)
            }

            // Enqueue children sorted by original order, skip already visited (duplicate ID safety)
            if let children = childrenOf[id] {
                let sortedChildren = children.sorted { a, b in
                    (originalIndex[a] ?? Int.max) < (originalIndex[b] ?? Int.max)
                }
                for childId in sortedChildren {
                    if !visited.contains(childId) {
                        queue.append(childId)
                    }
                }
            }
        }

        // Fallback: append any items that weren't reached, preserving original order
        // This can happen with cycles or if parent references form a loop
        for record in records {
            if let itemId = itemIdByRecordName[record.recordID.recordName],
               !visited.contains(itemId) {
                sorted.append(record)
                let item = itemById[itemId]
                let parentId = item?.parentId ?? "nil"
                NSLog("SyncEngine: topologicalSort - appending unreached item \(itemId) (parentId=\(parentId)) - possible cycle or missing parent chain")
            }
        }

        // Append records that failed conversion (preserve original order)
        sorted.append(contentsOf: failedRecords)

        return sorted
    }

    /// Apply a single changed record to the database
    private func applyChangedRecord(_ record: CKRecord, to db: GRDB.Database) throws {
        switch record.recordType {
        case CloudKitRecordType.item:
            if var item = CKRecordConverters.item(from: record) {
                // Ensure parent exists; if not, drop the reference to avoid FK failures.
                if let parentId = item.parentId, !parentId.isEmpty,
                   try Item.fetchOne(db, key: parentId) == nil {
                    NSLog("SyncEngine: Missing parent \(parentId) for item \(item.id) - resetting parent to nil")
                    item.parentId = nil
                }

                // Check for conflict with local changes
                if let existingItem = try Item.fetchOne(db, key: item.id),
                   existingItem.needsPush == 1 {
                    // Local has unsaved changes - use last-write-wins
                    if let serverModified = record["modifiedAt"] as? Int,
                       serverModified > existingItem.modifiedAt {
                        // Server wins
                        try item.save(db, onConflict: .replace)
                    }
                    // Otherwise local wins - don't overwrite
                } else {
                    // No local conflict, apply server version
                    try item.save(db, onConflict: .replace)
                }
            } else {
                NSLog("SyncEngine: Failed to convert item record: \(record.recordID.recordName), keys: \(record.allKeys())")
            }

        case CloudKitRecordType.tag:
            if let tag = CKRecordConverters.tag(from: record) {
                if let existingTag = try Tag.fetchOne(db, key: tag.id),
                   existingTag.needsPush == 1 {
                    if let serverModified = record["modifiedAt"] as? Int,
                       let localModified = existingTag.modifiedAt,
                       serverModified > localModified {
                        try tag.save(db, onConflict: .replace)
                    }
                } else {
                    try tag.save(db, onConflict: .replace)
                }
            }

        case CloudKitRecordType.itemTag:
            if let itemTag = CKRecordConverters.itemTag(from: record) {
                // ItemTag uses composite key
                let existing = try ItemTag
                    .filter(Column("item_id") == itemTag.itemId && Column("tag_id") == itemTag.tagId)
                    .fetchOne(db)
                if let existingItemTag = existing, existingItemTag.needsPush == 1 {
                    if let serverModified = record["modifiedAt"] as? Int,
                       let localModified = existingItemTag.modifiedAt,
                       serverModified > localModified {
                        try itemTag.save(db, onConflict: .replace)
                    }
                } else {
                    try itemTag.save(db, onConflict: .replace)
                }
            }

        case CloudKitRecordType.timeEntry:
            if let timeEntry = CKRecordConverters.timeEntry(from: record) {
                if let existingEntry = try TimeEntry.fetchOne(db, key: timeEntry.id),
                   existingEntry.needsPush == 1 {
                    if let serverModified = record["modifiedAt"] as? Int,
                       let localModified = existingEntry.modifiedAt,
                       serverModified > localModified {
                        try timeEntry.save(db, onConflict: .replace)
                    }
                } else {
                    try timeEntry.save(db, onConflict: .replace)
                }
            }

        case CloudKitRecordType.savedSearch:
            if let savedSearch = CKRecordConverters.savedSearch(from: record) {
                if let existingSearch = try SavedSearch.fetchOne(db, key: savedSearch.id),
                   existingSearch.needsPush == 1 {
                    if let serverModified = record["modifiedAt"] as? Int,
                       serverModified > existingSearch.modifiedAt {
                        try savedSearch.save(db, onConflict: .replace)
                    }
                } else {
                    try savedSearch.save(db, onConflict: .replace)
                }
            }

        default:
            NSLog("SyncEngine: Unknown record type: \(record.recordType)")
        }
    }

    /// Apply an itemTag record if its dependencies exist. Returns true if applied, false if deferred.
    private func applyItemTagIfReady(_ record: CKRecord, to db: GRDB.Database,
                                      itemExists: (String) throws -> Bool,
                                      tagExists: (String) throws -> Bool) throws -> Bool {
        guard let itemTag = CKRecordConverters.itemTag(from: record) else {
            NSLog("SyncEngine: Failed to convert item_tag record: \(record.recordID.recordName)")
            return true  // Don't retry conversion failures
        }

        let hasItem = try itemExists(itemTag.itemId)
        let hasTag = try tagExists(itemTag.tagId)

        guard hasItem && hasTag else {
            NSLog("SyncEngine: Deferring item_tag (item=\(itemTag.itemId), tag=\(itemTag.tagId)) - itemExists=\(hasItem), tagExists=\(hasTag)")
            return false
        }

        try applyChangedRecord(record, to: db)
        return true
    }

    /// Apply a timeEntry record if its item dependency exists. Returns true if applied, false if deferred.
    private func applyTimeEntryIfReady(_ record: CKRecord, to db: GRDB.Database,
                                        itemExists: (String) throws -> Bool) throws -> Bool {
        guard let timeEntry = CKRecordConverters.timeEntry(from: record) else {
            NSLog("SyncEngine: Failed to convert time_entry record: \(record.recordID.recordName)")
            return true  // Don't retry conversion failures
        }

        guard try itemExists(timeEntry.itemId) else {
            NSLog("SyncEngine: Deferring time_entry (id=\(timeEntry.id)) - item \(timeEntry.itemId) missing")
            return false
        }

        try applyChangedRecord(record, to: db)
        return true
    }

    // MARK: - Conflict Resolution

    /// Handle conflicts using last-write-wins.
    /// When local wins, updates ck_change_tag and ck_system_fields from server so next push can succeed.
    private func handleConflicts(_ conflicts: [(CKRecord.ID, CKError)], dbQueue: DatabaseQueue) throws {
        NSLog("SyncEngine: Handling \(conflicts.count) conflicts")
        for (recordID, error) in conflicts {
            let recordName = recordID.recordName

            // Log each conflict with details
            if let serverRecord = error.serverRecord {
                let serverModifiedAt = serverRecord["modifiedAt"] as? Int ?? 0
                let title = serverRecord["title"] as? String ?? "(no title)"
                NSLog("SyncEngine: Conflict - \(serverRecord.recordType) '\(title)' (recordName: \(recordName), serverModifiedAt: \(serverModifiedAt))")
            } else {
                NSLog("SyncEngine: Conflict - recordName: \(recordName) (no server record)")
            }

            guard let serverRecord = error.serverRecord else {
                // No server record available - clear metadata and mark for retry
                // This forces a fresh push that will either succeed or get the server record next time
                NSLog("SyncEngine: Conflict for \(recordName) has no serverRecord - clearing metadata for retry")
                try dbQueue.write { db in
                    // Try all tables since we don't know the record type without serverRecord
                    try db.execute(sql: "UPDATE items SET ck_change_tag = NULL, ck_system_fields = NULL, needs_push = 1 WHERE ck_record_name = ?", arguments: [recordName])
                    try db.execute(sql: "UPDATE tags SET ck_change_tag = NULL, ck_system_fields = NULL, needs_push = 1 WHERE ck_record_name = ?", arguments: [recordName])
                    try db.execute(sql: "UPDATE item_tags SET ck_change_tag = NULL, ck_system_fields = NULL, needs_push = 1 WHERE ck_record_name = ?", arguments: [recordName])
                    try db.execute(sql: "UPDATE time_entries SET ck_change_tag = NULL, ck_system_fields = NULL, needs_push = 1 WHERE ck_record_name = ?", arguments: [recordName])
                    try db.execute(sql: "UPDATE saved_searches SET ck_change_tag = NULL, ck_system_fields = NULL, needs_push = 1 WHERE ck_record_name = ?", arguments: [recordName])
                }
                continue
            }

            let serverChangeTag = serverRecord.recordChangeTag
            // Encode server's system fields so we can use them for the retry push
            let serverSystemFields = CKRecordConverters.encodeSystemFields(serverRecord)

            try dbQueue.write { db in
                let serverModifiedAt = serverRecord["modifiedAt"] as? Int ?? 0

                switch serverRecord.recordType {
                case CloudKitRecordType.item:
                    // Try to find by ck_record_name first, then by local ID (for items that haven't synced yet)
                    let localId = recordName.hasPrefix("Item_") ? String(recordName.dropFirst(5)) : recordName
                    let localItem = try Item.filter(Column("ck_record_name") == recordName).fetchOne(db)
                        ?? Item.fetchOne(db, key: localId)

                    if let localItem = localItem {
                        let localTitle = localItem.title ?? "(no title)"
                        if localItem.modifiedAt > serverModifiedAt {
                            // Local wins - update change tag/system fields AND mark for retry
                            // Also set ck_record_name if it was NULL
                            try db.execute(
                                sql: "UPDATE items SET ck_record_name = ?, ck_change_tag = ?, ck_system_fields = ?, needs_push = 1 WHERE id = ?",
                                arguments: [recordName, serverChangeTag, serverSystemFields, localItem.id]
                            )
                            NSLog("SyncEngine: Conflict resolved - LOCAL wins for '\(localTitle)' (local: \(localItem.modifiedAt) > server: \(serverModifiedAt))")
                        } else {
                            // Server wins - apply server version
                            if let item = CKRecordConverters.item(from: serverRecord) {
                                try item.save(db, onConflict: .replace)
                            }
                            NSLog("SyncEngine: Conflict resolved - SERVER wins for '\(localTitle)' (local: \(localItem.modifiedAt) <= server: \(serverModifiedAt))")
                        }
                    } else {
                        NSLog("SyncEngine: Conflict - no local item found for \(recordName), applying server version")
                        if let item = CKRecordConverters.item(from: serverRecord) {
                            try item.save(db, onConflict: .replace)
                        }
                    }

                case CloudKitRecordType.tag:
                    if let localTag = try Tag.filter(Column("ck_record_name") == recordName).fetchOne(db),
                       let localModified = localTag.modifiedAt {
                        if localModified > serverModifiedAt {
                            // Local wins - update change tag/system fields AND mark for retry
                            try db.execute(
                                sql: "UPDATE tags SET ck_change_tag = ?, ck_system_fields = ?, needs_push = 1 WHERE ck_record_name = ?",
                                arguments: [serverChangeTag, serverSystemFields, recordName]
                            )
                            NSLog("SyncEngine: Conflict - local tag wins, marked for retry push")
                        } else {
                            // Server wins
                            if let tag = CKRecordConverters.tag(from: serverRecord) {
                                try tag.save(db, onConflict: .replace)
                            }
                            NSLog("SyncEngine: Conflict - server tag wins")
                        }
                    }

                case CloudKitRecordType.itemTag:
                    // Try to find by ck_record_name first, then by composite key (itemId_tagId)
                    var localItemTag = try ItemTag.filter(Column("ck_record_name") == recordName).fetchOne(db)
                    if localItemTag == nil && recordName.hasPrefix("ItemTag_") {
                        // Parse ItemTag_{itemId}_{tagId}
                        let parts = recordName.dropFirst(8).split(separator: "_", maxSplits: 1)
                        if parts.count == 2 {
                            let itemId = String(parts[0])
                            let tagId = String(parts[1])
                            localItemTag = try ItemTag.filter(Column("item_id") == itemId && Column("tag_id") == tagId).fetchOne(db)
                        }
                    }

                    if let localItemTag = localItemTag, let localModified = localItemTag.modifiedAt {
                        if localModified > serverModifiedAt {
                            // Local wins - mark for retry, also set ck_record_name if NULL
                            try db.execute(
                                sql: "UPDATE item_tags SET ck_record_name = ?, ck_change_tag = ?, ck_system_fields = ?, needs_push = 1 WHERE item_id = ? AND tag_id = ?",
                                arguments: [recordName, serverChangeTag, serverSystemFields, localItemTag.itemId, localItemTag.tagId]
                            )
                            NSLog("SyncEngine: Conflict resolved - LOCAL itemTag wins (local: \(localModified) > server: \(serverModifiedAt))")
                        } else {
                            // Server wins
                            if let itemTag = CKRecordConverters.itemTag(from: serverRecord) {
                                try itemTag.save(db, onConflict: .replace)
                            }
                            NSLog("SyncEngine: Conflict resolved - SERVER itemTag wins (local: \(localModified) <= server: \(serverModifiedAt))")
                        }
                    } else {
                        NSLog("SyncEngine: Conflict - no local itemTag found for \(recordName), applying server version")
                        if let itemTag = CKRecordConverters.itemTag(from: serverRecord) {
                            try itemTag.save(db, onConflict: .replace)
                        }
                    }

                case CloudKitRecordType.timeEntry:
                    if let localTimeEntry = try TimeEntry.filter(Column("ck_record_name") == recordName).fetchOne(db),
                       let localModified = localTimeEntry.modifiedAt {
                        if localModified > serverModifiedAt {
                            // Local wins - mark for retry
                            try db.execute(
                                sql: "UPDATE time_entries SET ck_change_tag = ?, ck_system_fields = ?, needs_push = 1 WHERE ck_record_name = ?",
                                arguments: [serverChangeTag, serverSystemFields, recordName]
                            )
                            NSLog("SyncEngine: Conflict - local timeEntry wins, marked for retry push")
                        } else {
                            // Server wins
                            if let timeEntry = CKRecordConverters.timeEntry(from: serverRecord) {
                                try timeEntry.save(db, onConflict: .replace)
                            }
                            NSLog("SyncEngine: Conflict - server timeEntry wins")
                        }
                    }

                case CloudKitRecordType.savedSearch:
                    if let localSearch = try SavedSearch.filter(Column("ck_record_name") == recordName).fetchOne(db) {
                        if localSearch.modifiedAt > serverModifiedAt {
                            // Local wins - mark for retry
                            try db.execute(
                                sql: "UPDATE saved_searches SET ck_change_tag = ?, ck_system_fields = ?, needs_push = 1 WHERE ck_record_name = ?",
                                arguments: [serverChangeTag, serverSystemFields, recordName]
                            )
                            NSLog("SyncEngine: Conflict - local savedSearch wins, marked for retry push")
                        } else {
                            // Server wins
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

    // MARK: - Helpers

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
                case CloudKitRecordType.item:
                    try db.execute(
                        sql: "UPDATE items SET needs_push = 0, ck_change_tag = ?, ck_system_fields = ? WHERE ck_record_name = ?",
                        arguments: [changeTag, systemFields, recordName]
                    )

                case CloudKitRecordType.tag:
                    try db.execute(
                        sql: "UPDATE tags SET needs_push = 0, ck_change_tag = ?, ck_system_fields = ? WHERE ck_record_name = ?",
                        arguments: [changeTag, systemFields, recordName]
                    )

                case CloudKitRecordType.itemTag:
                    try db.execute(
                        sql: "UPDATE item_tags SET needs_push = 0, ck_change_tag = ?, ck_system_fields = ? WHERE ck_record_name = ?",
                        arguments: [changeTag, systemFields, recordName]
                    )

                case CloudKitRecordType.timeEntry:
                    try db.execute(
                        sql: "UPDATE time_entries SET needs_push = 0, ck_change_tag = ?, ck_system_fields = ? WHERE ck_record_name = ?",
                        arguments: [changeTag, systemFields, recordName]
                    )

                case CloudKitRecordType.savedSearch:
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

                // Clear needs_push, change tag, and system fields so any future re-creation
                // will be treated as a new insert (not an update to a deleted record)
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
}

