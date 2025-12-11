import Foundation
import CloudKit
import Combine

/// Protocol abstracting CloudKit operations to enable testing without iCloud dependency
protocol CloudKitManagerProtocol: AnyObject {
    // Configuration
    var zoneID: CKRecordZone.ID { get }

    // Published state
    var accountStatus: CKAccountStatus { get }
    var isZoneReady: Bool { get }
    var accountStatusPublisher: Published<CKAccountStatus>.Publisher { get }
    var isZoneReadyPublisher: Published<Bool>.Publisher { get }

    // Computed properties
    var isAccountAvailable: Bool { get }

    // Async operations
    func checkAccountStatus() async throws -> CKAccountStatus
    func ensureZoneExists() async throws
    func initialize() async throws
    func registerForSubscriptions() async throws
    func unregisterSubscriptions() async throws

    // Helper methods
    func recordID(for recordName: String) -> CKRecord.ID
    func newRecord(type: String, recordName: String) -> CKRecord
}
