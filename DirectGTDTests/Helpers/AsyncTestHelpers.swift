import XCTest

/// Helper utilities for async testing
enum AsyncTestHelpers {
    /// Default timeout for async operations (5 seconds)
    static let defaultTimeout: TimeInterval = 5.0

    /// Short timeout for fast operations (1 second)
    static let shortTimeout: TimeInterval = 1.0

    /// Long timeout for slow operations (10 seconds)
    static let longTimeout: TimeInterval = 10.0

    /// Wait for an async condition to become true
    /// - Parameters:
    ///   - timeout: Maximum time to wait
    ///   - pollInterval: How often to check the condition
    ///   - condition: The condition to check
    /// - Throws: If timeout is reached before condition is met
    static func waitFor(
        timeout: TimeInterval = defaultTimeout,
        pollInterval: TimeInterval = 0.1,
        condition: @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return
            }
            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }

        throw AsyncTestError.timeout(message: "Condition not met within \(timeout) seconds")
    }

    /// Wait for a published value to change
    /// - Parameters:
    ///   - timeout: Maximum time to wait
    ///   - getValue: Closure that returns the current value
    ///   - expectedValue: The value to wait for
    static func waitForValue<T: Equatable>(
        timeout: TimeInterval = defaultTimeout,
        getValue: @escaping () -> T,
        expectedValue: T
    ) async throws {
        try await waitFor(timeout: timeout) {
            getValue() == expectedValue
        }
    }

    /// Create an XCTestExpectation for async testing
    /// - Parameters:
    ///   - description: Description of what we're waiting for
    ///   - testCase: The test case instance
    /// - Returns: A configured expectation
    static func expectation(
        description: String,
        in testCase: XCTestCase
    ) -> XCTestExpectation {
        testCase.expectation(description: description)
    }

    /// Wait for multiple expectations
    /// - Parameters:
    ///   - expectations: Array of expectations to wait for
    ///   - timeout: Maximum time to wait
    ///   - testCase: The test case instance
    static func waitForExpectations(
        _ expectations: [XCTestExpectation],
        timeout: TimeInterval = defaultTimeout,
        in testCase: XCTestCase
    ) async {
        await testCase.fulfillment(of: expectations, timeout: timeout)
    }

    /// Assert that an async operation throws a specific error type
    /// - Parameters:
    ///   - expectedError: The error type to expect
    ///   - operation: The async operation that should throw
    /// - Returns: The thrown error if it matches the expected type
    @discardableResult
    static func assertThrows<T: Error>(
        _ expectedError: T.Type,
        operation: () async throws -> Void
    ) async throws -> T {
        do {
            try await operation()
            throw AsyncTestError.didNotThrow
        } catch let error as T {
            return error
        } catch {
            throw AsyncTestError.wrongErrorType(expected: expectedError, actual: type(of: error))
        }
    }

    /// Assert that an async operation does not throw
    /// - Parameter operation: The async operation that should succeed
    static func assertNoThrow(
        operation: () async throws -> Void
    ) async throws {
        do {
            try await operation()
        } catch {
            throw AsyncTestError.unexpectedError(error)
        }
    }

    /// Measure async performance
    /// - Parameters:
    ///   - iterations: Number of times to run the operation
    ///   - operation: The async operation to measure
    /// - Returns: Average execution time in seconds
    static func measure(
        iterations: Int = 10,
        operation: () async throws -> Void
    ) async throws -> TimeInterval {
        var totalTime: TimeInterval = 0

        for _ in 0..<iterations {
            let start = Date()
            try await operation()
            totalTime += Date().timeIntervalSince(start)
        }

        return totalTime / Double(iterations)
    }

    /// Run an async operation with a timeout
    /// - Parameters:
    ///   - timeout: Maximum time to wait
    ///   - operation: The async operation to run
    /// - Throws: AsyncTestError.timeout if the operation takes too long
    static func withTimeout<T>(
        _ timeout: TimeInterval = defaultTimeout,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Task for the actual operation
            group.addTask {
                try await operation()
            }

            // Task for the timeout
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw AsyncTestError.timeout(message: "Operation timed out after \(timeout) seconds")
            }

            // Return the first result (either success or timeout)
            guard let result = try await group.next() else {
                throw AsyncTestError.unexpectedError(NSError(domain: "AsyncTestHelpers", code: -1))
            }

            // Cancel the remaining task
            group.cancelAll()

            return result
        }
    }
}

/// Errors that can occur during async testing
enum AsyncTestError: Error, LocalizedError {
    case timeout(message: String)
    case didNotThrow
    case wrongErrorType(expected: Any.Type, actual: Any.Type)
    case unexpectedError(Error)

    var errorDescription: String? {
        switch self {
        case .timeout(let message):
            return message
        case .didNotThrow:
            return "Expected operation to throw, but it completed successfully"
        case .wrongErrorType(let expected, let actual):
            return "Expected error of type \(expected), but got \(actual)"
        case .unexpectedError(let error):
            return "Unexpected error: \(error.localizedDescription)"
        }
    }
}

// MARK: - XCTestCase Extensions

extension XCTestCase {
    /// Convenient async assertion wrapper
    func asyncAssertNoThrow(
        _ expression: @escaping () async throws -> Void,
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            try await expression()
        } catch {
            XCTFail("Async operation threw error: \(error). \(message)", file: file, line: line)
        }
    }

    /// Convenient async assertion for throws
    func asyncAssertThrows<T: Error>(
        _ errorType: T.Type,
        _ expression: @escaping () async throws -> Void,
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) async -> T? {
        do {
            try await expression()
            XCTFail("Expected operation to throw \(errorType), but it succeeded. \(message)", file: file, line: line)
            return nil
        } catch let error as T {
            return error
        } catch {
            XCTFail("Expected error of type \(errorType), but got \(type(of: error)). \(message)", file: file, line: line)
            return nil
        }
    }
}
