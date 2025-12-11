import Foundation
@testable import DirectGTD

/// Mock implementation of SyncMetadataStore for testing
class MockSyncMetadataStore {
    // MARK: - Storage

    private var storage: [String: Data] = [:]

    // MARK: - Mock Configuration

    /// Set this to make operations throw errors
    var shouldThrowError: Bool = false
    var errorToThrow: Error = NSError(domain: "MockError", code: -1)

    /// Track method calls
    var getDataCallCount: Int = 0
    var setDataCallCount: Int = 0
    var getStringCallCount: Int = 0
    var setStringCallCount: Int = 0
    var getIntCallCount: Int = 0
    var setIntCallCount: Int = 0

    // MARK: - Generic Get/Set

    func getData(key: String) throws -> Data? {
        getDataCallCount += 1

        if shouldThrowError {
            throw errorToThrow
        }

        return storage[key]
    }

    func setData(key: String, value: Data?) throws {
        setDataCallCount += 1

        if shouldThrowError {
            throw errorToThrow
        }

        if let value = value {
            storage[key] = value
        } else {
            storage.removeValue(forKey: key)
        }
    }

    func getString(key: String) throws -> String? {
        getStringCallCount += 1

        if shouldThrowError {
            throw errorToThrow
        }

        guard let data = storage[key] else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func setString(key: String, value: String?) throws {
        setStringCallCount += 1

        if shouldThrowError {
            throw errorToThrow
        }

        if let value = value {
            storage[key] = value.data(using: .utf8)
        } else {
            storage.removeValue(forKey: key)
        }
    }

    func getInt(key: String) throws -> Int? {
        getIntCallCount += 1

        if shouldThrowError {
            throw errorToThrow
        }

        guard let string = try getString(key: key) else { return nil }
        return Int(string)
    }

    func setInt(key: String, value: Int?) throws {
        setIntCallCount += 1

        if shouldThrowError {
            throw errorToThrow
        }

        try setString(key: key, value: value.map { String($0) })
    }

    // MARK: - Change Token Helpers

    func getZoneChangeToken() throws -> Data? {
        return try getData(key: "zone_change_token")
    }

    func setZoneChangeToken(_ tokenData: Data?) throws {
        try setData(key: "zone_change_token", value: tokenData)
    }

    func getDatabaseChangeToken() throws -> Data? {
        return try getData(key: "database_change_token")
    }

    func setDatabaseChangeToken(_ tokenData: Data?) throws {
        try setData(key: "database_change_token", value: tokenData)
    }

    // MARK: - Sync Timestamp Helpers

    func getLastSyncTimestamp() throws -> Int? {
        return try getInt(key: "last_sync_timestamp")
    }

    func setLastSyncTimestamp(_ timestamp: Int) throws {
        try setInt(key: "last_sync_timestamp", value: timestamp)
    }

    func updateLastSyncTimestamp() throws {
        try setLastSyncTimestamp(Int(Date().timeIntervalSince1970))
    }

    // MARK: - Device ID Helpers

    func getOrCreateDeviceId() throws -> String {
        if let existing = try getString(key: "device_id") {
            return existing
        }

        let newId = UUID().uuidString
        try setString(key: "device_id", value: newId)
        return newId
    }

    // MARK: - Initial Sync Helpers

    func isInitialSyncComplete() throws -> Bool {
        return try getString(key: "initial_sync_complete") == "1"
    }

    func setInitialSyncComplete(_ complete: Bool) throws {
        try setString(key: "initial_sync_complete", value: complete ? "1" : "0")
    }

    // MARK: - Sync Enabled Helpers

    func isSyncEnabled() throws -> Bool {
        guard let value = try getString(key: "sync_enabled") else {
            return true  // Default to enabled
        }
        return value == "1"
    }

    func setSyncEnabled(_ enabled: Bool) throws {
        try setString(key: "sync_enabled", value: enabled ? "1" : "0")
    }

    // MARK: - Bulk Operations

    func clearAll() throws {
        if shouldThrowError {
            throw errorToThrow
        }
        storage.removeAll()
    }

    func getAllKeys() throws -> [String] {
        if shouldThrowError {
            throw errorToThrow
        }
        return Array(storage.keys)
    }

    // MARK: - Test Helpers

    /// Reset all mock state
    func reset() {
        storage.removeAll()
        shouldThrowError = false
        getDataCallCount = 0
        setDataCallCount = 0
        getStringCallCount = 0
        setStringCallCount = 0
        getIntCallCount = 0
        setIntCallCount = 0
    }

    /// Get the underlying storage for inspection
    func getStorage() -> [String: Data] {
        return storage
    }

    /// Set storage directly for test setup
    func setStorage(_ newStorage: [String: Data]) {
        storage = newStorage
    }
}
