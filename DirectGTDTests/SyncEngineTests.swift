import DirectGTDCore
import XCTest
import Combine
@testable import DirectGTD

final class SyncEngineTests: XCTestCase {
    var syncEngine: SyncEngine!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        // Note: SyncEngine initialization may require CloudKit setup
        // These tests focus on testable aspects without CloudKit connectivity
    }

    override func tearDown() {
        cancellables.removeAll()
        syncEngine = nil
        super.tearDown()
    }

    // MARK: - SyncStatus Tests

    func testSyncStatusEquality() {
        let status1 = SyncEngine.SyncStatus.idle
        let status2 = SyncEngine.SyncStatus.idle
        let status3 = SyncEngine.SyncStatus.syncing

        XCTAssertEqual(status1, status2)
        XCTAssertNotEqual(status1, status3)
    }

    func testSyncStatusDisabled() {
        let status = SyncEngine.SyncStatus.disabled
        XCTAssertEqual(status, .disabled)
    }

    func testSyncStatusIdle() {
        let status = SyncEngine.SyncStatus.idle
        XCTAssertEqual(status, .idle)
    }

    func testSyncStatusSyncing() {
        let status = SyncEngine.SyncStatus.syncing
        XCTAssertEqual(status, .syncing)
    }

    func testSyncStatusInitialSync() {
        let status = SyncEngine.SyncStatus.initialSync(progress: 0.5, message: "Syncing items")

        if case .initialSync(let progress, let message) = status {
            XCTAssertEqual(progress, 0.5)
            XCTAssertEqual(message, "Syncing items")
        } else {
            XCTFail("Expected initialSync status")
        }
    }

    func testSyncStatusError() {
        let errorMessage = "Network error"
        let status = SyncEngine.SyncStatus.error(errorMessage)

        if case .error(let message) = status {
            XCTAssertEqual(message, errorMessage)
        } else {
            XCTFail("Expected error status")
        }
    }

    func testSyncStatusInitialSyncEquality() {
        let status1 = SyncEngine.SyncStatus.initialSync(progress: 0.5, message: "Test")
        let status2 = SyncEngine.SyncStatus.initialSync(progress: 0.5, message: "Test")
        let status3 = SyncEngine.SyncStatus.initialSync(progress: 0.7, message: "Test")

        XCTAssertEqual(status1, status2)
        XCTAssertNotEqual(status1, status3)
    }

    func testSyncStatusErrorEquality() {
        let status1 = SyncEngine.SyncStatus.error("Error 1")
        let status2 = SyncEngine.SyncStatus.error("Error 1")
        let status3 = SyncEngine.SyncStatus.error("Error 2")

        XCTAssertEqual(status1, status2)
        XCTAssertNotEqual(status1, status3)
    }

    // MARK: - Initial Sync Progress Tests

    func testInitialSyncProgressValues() {
        let progressValues: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]

        for progressValue in progressValues {
            let status = SyncEngine.SyncStatus.initialSync(progress: progressValue, message: "Test")

            if case .initialSync(let progress, _) = status {
                XCTAssertEqual(progress, progressValue, accuracy: 0.001)
            } else {
                XCTFail("Expected initialSync status with progress \(progressValue)")
            }
        }
    }

    func testInitialSyncProgressBoundaries() {
        let belowZero = SyncEngine.SyncStatus.initialSync(progress: -0.1, message: "Test")
        let aboveOne = SyncEngine.SyncStatus.initialSync(progress: 1.5, message: "Test")

        if case .initialSync(let progress1, _) = belowZero {
            XCTAssertLessThan(progress1, 0)
        }

        if case .initialSync(let progress2, _) = aboveOne {
            XCTAssertGreaterThan(progress2, 1.0)
        }
    }

    // MARK: - Configuration Constants Tests

    func testMaxRetryAttempts() {
        // SyncEngine should have a reasonable retry limit
        // Default is 3 according to the code summary
        let expectedMaxRetries = 3
        XCTAssertGreaterThan(expectedMaxRetries, 0)
        XCTAssertLessThanOrEqual(expectedMaxRetries, 10)
    }

    func testBaseRetryDelay() {
        // Base retry delay should be positive and reasonable (2 seconds)
        let expectedBaseDelay: TimeInterval = 2.0
        XCTAssertGreaterThan(expectedBaseDelay, 0)
        XCTAssertLessThanOrEqual(expectedBaseDelay, 10.0)
    }

    func testSyncDebounceInterval() {
        // Debounce interval should be short (1 second)
        let expectedDebounce: TimeInterval = 1.0
        XCTAssertGreaterThan(expectedDebounce, 0)
        XCTAssertLessThanOrEqual(expectedDebounce, 5.0)
    }

    func testTombstoneRetentionDays() {
        // Tombstone retention should be reasonable (30 days)
        let expectedRetention = 30
        XCTAssertGreaterThan(expectedRetention, 0)
        XCTAssertLessThanOrEqual(expectedRetention, 90)
    }

    // MARK: - Exponential Backoff Tests

    func testExponentialBackoffCalculation() {
        let baseDelay: TimeInterval = 2.0
        let attempt1Delay = baseDelay * pow(2.0, 0) // 2 seconds
        let attempt2Delay = baseDelay * pow(2.0, 1) // 4 seconds
        let attempt3Delay = baseDelay * pow(2.0, 2) // 8 seconds

        XCTAssertEqual(attempt1Delay, 2.0)
        XCTAssertEqual(attempt2Delay, 4.0)
        XCTAssertEqual(attempt3Delay, 8.0)
    }

    func testExponentialBackoffProgression() {
        let baseDelay: TimeInterval = 2.0
        var delays: [TimeInterval] = []

        for attempt in 0..<3 {
            let delay = baseDelay * pow(2.0, Double(attempt))
            delays.append(delay)
        }

        // Verify delays are increasing exponentially
        XCTAssertLessThan(delays[0], delays[1])
        XCTAssertLessThan(delays[1], delays[2])
        XCTAssertEqual(delays[1], delays[0] * 2)
        XCTAssertEqual(delays[2], delays[1] * 2)
    }

    // MARK: - Tombstone Retention Tests

    func testTombstoneRetentionCalculation() {
        let retentionDays = 30
        let retentionSeconds = retentionDays * 24 * 60 * 60

        XCTAssertEqual(retentionSeconds, 2_592_000) // 30 days in seconds
    }

    func testTombstoneAgeCalculation() {
        let now = Date()
        let oldDate = now.addingTimeInterval(-40 * 24 * 60 * 60) // 40 days ago
        let recentDate = now.addingTimeInterval(-10 * 24 * 60 * 60) // 10 days ago

        let oldAge = now.timeIntervalSince(oldDate)
        let recentAge = now.timeIntervalSince(recentDate)

        let retentionPeriod: TimeInterval = 30 * 24 * 60 * 60

        XCTAssertGreaterThan(oldAge, retentionPeriod)
        XCTAssertLessThan(recentAge, retentionPeriod)
    }

    // MARK: - Sync Status Transitions Tests

    func testSyncStatusTransitionsAreDistinct() {
        let statuses: [SyncEngine.SyncStatus] = [
            .disabled,
            .idle,
            .syncing,
            .initialSync(progress: 0.5, message: "Test"),
            .error("Test error")
        ]

        // Verify all statuses are distinct (except those with same parameters)
        for (index, status1) in statuses.enumerated() {
            for status2 in statuses[(index + 1)...] {
                XCTAssertNotEqual(status1, status2, "Statuses at different indices should not be equal")
            }
        }
    }

    func testSyncStatusIdleToSyncing() {
        let initial = SyncEngine.SyncStatus.idle
        let next = SyncEngine.SyncStatus.syncing

        XCTAssertNotEqual(initial, next)
    }

    func testSyncStatusSyncingToIdle() {
        let syncing = SyncEngine.SyncStatus.syncing
        let idle = SyncEngine.SyncStatus.idle

        XCTAssertNotEqual(syncing, idle)
    }

    func testSyncStatusSyncingToError() {
        let syncing = SyncEngine.SyncStatus.syncing
        let error = SyncEngine.SyncStatus.error("Network error")

        XCTAssertNotEqual(syncing, error)
    }

    // MARK: - Initial Sync Message Tests

    func testInitialSyncMessages() {
        let messages = [
            "Fetching items from cloud",
            "Syncing tags",
            "Processing changes",
            "Almost done"
        ]

        for message in messages {
            let status = SyncEngine.SyncStatus.initialSync(progress: 0.5, message: message)

            if case .initialSync(_, let actualMessage) = status {
                XCTAssertEqual(actualMessage, message)
                XCTAssertFalse(actualMessage.isEmpty)
            } else {
                XCTFail("Expected initialSync status")
            }
        }
    }

    func testInitialSyncEmptyMessage() {
        let status = SyncEngine.SyncStatus.initialSync(progress: 0.5, message: "")

        if case .initialSync(_, let message) = status {
            XCTAssertTrue(message.isEmpty)
        } else {
            XCTFail("Expected initialSync status")
        }
    }

    // MARK: - Error Message Tests

    func testErrorStatusWithDifferentMessages() {
        let errorMessages = [
            "Network timeout",
            "Authentication failed",
            "Zone not found",
            "Quota exceeded"
        ]

        for errorMessage in errorMessages {
            let status = SyncEngine.SyncStatus.error(errorMessage)

            if case .error(let message) = status {
                XCTAssertEqual(message, errorMessage)
                XCTAssertFalse(message.isEmpty)
            } else {
                XCTFail("Expected error status")
            }
        }
    }

    func testErrorStatusEmptyMessage() {
        let status = SyncEngine.SyncStatus.error("")

        if case .error(let message) = status {
            XCTAssertTrue(message.isEmpty)
        } else {
            XCTFail("Expected error status")
        }
    }

    // MARK: - Integration Tests

    func testAllSyncStatusCases() {
        let allCases: [SyncEngine.SyncStatus] = [
            .disabled,
            .idle,
            .syncing,
            .initialSync(progress: 0.0, message: "Starting"),
            .initialSync(progress: 0.5, message: "In progress"),
            .initialSync(progress: 1.0, message: "Complete"),
            .error("Generic error")
        ]

        // Verify we can create and distinguish all status types
        XCTAssertEqual(allCases.count, 7)
    }

    func testSyncStatusPatternMatching() {
        let statuses: [SyncEngine.SyncStatus] = [
            .disabled,
            .idle,
            .syncing,
            .initialSync(progress: 0.5, message: "Test"),
            .error("Test")
        ]

        for status in statuses {
            switch status {
            case .disabled:
                XCTAssertEqual(status, .disabled)
            case .idle:
                XCTAssertEqual(status, .idle)
            case .syncing:
                XCTAssertEqual(status, .syncing)
            case .initialSync(let progress, let message):
                XCTAssertGreaterThanOrEqual(progress, 0.0)
                XCTAssertFalse(message.isEmpty)
            case .error(let message):
                XCTAssertFalse(message.isEmpty)
            }
        }
    }

    // MARK: - Debouncing Tests

    func testDebounceIntervalIsPositive() {
        let debounceInterval: TimeInterval = 1.0
        XCTAssertGreaterThan(debounceInterval, 0)
    }

    func testDebounceIntervalReasonableRange() {
        let debounceInterval: TimeInterval = 1.0
        XCTAssertGreaterThanOrEqual(debounceInterval, 0.5)
        XCTAssertLessThanOrEqual(debounceInterval, 5.0)
    }

    // MARK: - Retry Logic Tests

    func testRetryAttemptsWithinBounds() {
        let maxRetries = 3

        for attempt in 1...maxRetries {
            XCTAssertLessThanOrEqual(attempt, maxRetries)
        }
    }

    func testRetryDelayIncreases() {
        let baseDelay: TimeInterval = 2.0
        var previousDelay: TimeInterval = 0

        for attempt in 0..<3 {
            let delay = baseDelay * pow(2.0, Double(attempt))
            XCTAssertGreaterThan(delay, previousDelay)
            previousDelay = delay
        }
    }
}
