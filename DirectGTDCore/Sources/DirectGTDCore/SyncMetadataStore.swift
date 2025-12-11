import Foundation
import GRDB

/// Store for sync-related metadata including change tokens.
/// Uses the sync_metadata table to persist key-value pairs.
public class SyncMetadataStore {
    private let dbQueue: DatabaseQueue

    // Well-known keys for sync metadata
    public enum Key {
        /// The server change token for the private database custom zone
        public static let zoneChangeToken = "zone_change_token"
        /// The server change token for the database (subscription changes)
        public static let databaseChangeToken = "database_change_token"
        /// Last successful sync timestamp (Unix epoch)
        public static let lastSyncTimestamp = "last_sync_timestamp"
        /// Device identifier for this client
        public static let deviceId = "device_id"
        /// Whether initial sync has completed ("1" or "0")
        public static let initialSyncComplete = "initial_sync_complete"
        /// Whether sync is enabled by user ("1" or "0")
        public static let syncEnabled = "sync_enabled"
    }

    public init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    // MARK: - Generic Get/Set

    /// Get a Data value for a key
    public func getData(key: String) throws -> Data? {
        return try dbQueue.read { db in
            try SyncMetadata
                .filter(Column("key") == key)
                .fetchOne(db)?
                .value
        }
    }

    /// Set a Data value for a key
    public func setData(key: String, value: Data?) throws {
        try dbQueue.write { db in
            if let value = value {
                let metadata = SyncMetadata(key: key, value: value)
                try metadata.save(db, onConflict: .replace)
            } else {
                try db.execute(
                    sql: "DELETE FROM sync_metadata WHERE key = ?",
                    arguments: [key]
                )
            }
        }
    }

    /// Get a String value for a key
    public func getString(key: String) throws -> String? {
        guard let data = try getData(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Set a String value for a key
    public func setString(key: String, value: String?) throws {
        try setData(key: key, value: value?.data(using: .utf8))
    }

    /// Get an Int value for a key
    public func getInt(key: String) throws -> Int? {
        guard let string = try getString(key: key) else { return nil }
        return Int(string)
    }

    /// Set an Int value for a key
    public func setInt(key: String, value: Int?) throws {
        try setString(key: key, value: value.map { String($0) })
    }

    // MARK: - Change Token Helpers

    /// Get the zone change token as raw Data (CloudKit CKServerChangeToken is archived to Data)
    public func getZoneChangeToken() throws -> Data? {
        return try getData(key: Key.zoneChangeToken)
    }

    /// Set the zone change token (pass archived CKServerChangeToken data)
    public func setZoneChangeToken(_ tokenData: Data?) throws {
        try setData(key: Key.zoneChangeToken, value: tokenData)
    }

    /// Get the database change token as raw Data
    public func getDatabaseChangeToken() throws -> Data? {
        return try getData(key: Key.databaseChangeToken)
    }

    /// Set the database change token
    public func setDatabaseChangeToken(_ tokenData: Data?) throws {
        try setData(key: Key.databaseChangeToken, value: tokenData)
    }

    // MARK: - Sync Timestamp Helpers

    /// Get the last successful sync timestamp
    public func getLastSyncTimestamp() throws -> Int? {
        return try getInt(key: Key.lastSyncTimestamp)
    }

    /// Set the last successful sync timestamp
    public func setLastSyncTimestamp(_ timestamp: Int) throws {
        try setInt(key: Key.lastSyncTimestamp, value: timestamp)
    }

    /// Update last sync timestamp to now
    public func updateLastSyncTimestamp() throws {
        try setLastSyncTimestamp(Int(Date().timeIntervalSince1970))
    }

    // MARK: - Device ID Helpers

    /// Get or create a unique device identifier for this client
    public func getOrCreateDeviceId() throws -> String {
        if let existing = try getString(key: Key.deviceId) {
            return existing
        }

        let newId = UUID().uuidString
        try setString(key: Key.deviceId, value: newId)
        return newId
    }

    // MARK: - Bulk Operations

    /// Clear all sync metadata (useful for resetting sync state)
    public func clearAll() throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM sync_metadata")
        }
        NSLog("SyncMetadataStore: Cleared all sync metadata")
    }

    /// Get all stored metadata keys
    public func getAllKeys() throws -> [String] {
        return try dbQueue.read { db in
            try String.fetchAll(db, sql: "SELECT key FROM sync_metadata")
        }
    }

    // MARK: - Initial Sync Helpers

    /// Check if initial sync has been completed
    public func isInitialSyncComplete() throws -> Bool {
        return try getString(key: Key.initialSyncComplete) == "1"
    }

    /// Mark initial sync as complete
    public func setInitialSyncComplete(_ complete: Bool) throws {
        try setString(key: Key.initialSyncComplete, value: complete ? "1" : "0")
    }

    // MARK: - Sync Enabled Helpers

    /// Check if sync is enabled by user (defaults to true)
    public func isSyncEnabled() throws -> Bool {
        guard let value = try getString(key: Key.syncEnabled) else {
            return true  // Default to enabled
        }
        return value == "1"
    }

    /// Set whether sync is enabled
    public func setSyncEnabled(_ enabled: Bool) throws {
        try setString(key: Key.syncEnabled, value: enabled ? "1" : "0")
    }
}
