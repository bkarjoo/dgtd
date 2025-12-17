// DirectGTDCore
// Shared code for DirectGTD macOS and iOS apps

import Foundation
import GRDB

// MARK: - DatabaseProvider Protocol
/// Protocol for providing database access across platform targets
public protocol DatabaseProvider: Sendable {
    func getQueue() -> DatabaseQueue?
}

// MARK: - Database Errors
/// Errors related to database operations
public enum DatabaseError: Error {
    case notInitialized
    case queueNotInitialized
    case schemaNotFound
}

// Re-export GRDB types that consumers need
public typealias DatabaseQueue = GRDB.DatabaseQueue
