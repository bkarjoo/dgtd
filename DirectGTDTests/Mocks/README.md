# Mock Infrastructure Documentation

## Overview

This directory contains mock implementations and protocols for testing CloudKit sync functionality without requiring iCloud connectivity.

## Components

### CloudKitManagerProtocol

Protocol defining the interface for CloudKit operations. Production code should use `CloudKitManager` which will conform to this protocol.

**Purpose**: Enable dependency injection and mocking in tests.

### MockCloudKitManager

Mock implementation of `CloudKitManagerProtocol` for testing.

**Features**:
- Simulates all CloudKit operations synchronously
- Configurable success/failure scenarios
- Tracks method call counts for verification
- No actual CloudKit dependency

**Usage Example**:
```swift
func testSyncOperationWithAvailableAccount() async throws {
    let mockManager = MockCloudKitManager()
    mockManager.configureForSuccess()

    // Your test code here
    try await mockManager.initialize()

    XCTAssertTrue(mockManager.isAccountAvailable)
    XCTAssertEqual(mockManager.initializeCallCount, 1)
}
```

**Configuration Methods**:
- `configureForSuccess()` - Setup for happy path
- `configureForNoAccount()` - Simulate no iCloud account
- `configureForZoneFailure()` - Simulate zone creation failure
- `reset()` - Clear all state between tests

**Controllable Behaviors**:
- `mockAccountStatus` - What account status to return
- `shouldFailZoneCreation` - Make zone operations fail
- `zoneAlreadyExists` - Simulate existing zone
- `shouldFailSubscriptionRegistration` - Make subscription fail
- `subscriptionAlreadyExists` - Simulate existing subscription
- `errorToThrow` - Custom error to throw

### MockSyncMetadataStore

Mock implementation of `SyncMetadataStore` for isolated testing.

**Features**:
- In-memory storage (no database dependency)
- All operations are synchronous
- Configurable error throwing
- Method call counting
- Storage inspection for verification

**Usage Example**:
```swift
func testMetadataStorage() throws {
    let mockStore = MockSyncMetadataStore()

    try mockStore.setString(key: "test", value: "hello")
    let result = try mockStore.getString(key: "test")

    XCTAssertEqual(result, "hello")
    XCTAssertEqual(mockStore.setStringCallCount, 1)
}
```

**Test Helpers**:
- `reset()` - Clear all state
- `getStorage()` - Inspect internal storage
- `setStorage(_ :)` - Pre-populate storage for tests

## Async Test Helpers

Utilities for testing async operations located in `Helpers/AsyncTestHelpers.swift`.

### Waiting for Conditions

```swift
// Wait for a condition to become true
try await AsyncTestHelpers.waitFor(timeout: 5.0) {
    someValue == expectedValue
}

// Wait for a specific value
try await AsyncTestHelpers.waitForValue(
    getValue: { manager.accountStatus },
    expectedValue: .available
)
```

### Timeouts

```swift
// Run operation with timeout
let result = try await AsyncTestHelpers.withTimeout(5.0) {
    try await someSlowOperation()
}
```

### Error Assertions

```swift
// Assert operation throws specific error type
let error = try await AsyncTestHelpers.assertThrows(CloudKitError.self) {
    try await failingOperation()
}

// Assert operation succeeds
try await AsyncTestHelpers.assertNoThrow {
    try await successfulOperation()
}
```

### XCTestCase Extensions

```swift
// Convenient async assertions
await asyncAssertNoThrow {
    try await operation()
}

let error = await asyncAssertThrows(CloudKitError.self) {
    try await failingOperation()
}
```

### Performance Measurement

```swift
let avgTime = try await AsyncTestHelpers.measure(iterations: 10) {
    try await operationToMeasure()
}
print("Average time: \(avgTime)s")
```

## Testing Patterns

### Pattern 1: Basic Mock Usage

```swift
final class MyAsyncTests: XCTestCase {
    var mockManager: MockCloudKitManager!

    override func setUp() {
        super.setUp()
        mockManager = MockCloudKitManager()
        mockManager.configureForSuccess()
    }

    override func tearDown() {
        mockManager = nil
        super.tearDown()
    }

    func testSomething() async throws {
        try await mockManager.initialize()
        XCTAssertTrue(mockManager.isZoneReady)
    }
}
```

### Pattern 2: Error Scenario Testing

```swift
func testHandlesNoAccount() async throws {
    mockManager.configureForNoAccount()

    let error = await asyncAssertThrows(CloudKitError.self) {
        try await mockManager.initialize()
    }

    if case .accountNotAvailable(let message) = error {
        XCTAssertTrue(message.contains("No iCloud account"))
    } else {
        XCTFail("Wrong error type")
    }
}
```

### Pattern 3: State Verification

```swift
func testPublishedPropertiesUpdate() async throws {
    XCTAssertFalse(mockManager.isAccountAvailable)

    try await mockManager.checkAccountStatus()

    XCTAssertTrue(mockManager.isAccountAvailable)
    XCTAssertEqual(mockManager.accountStatus, .available)
}
```

### Pattern 4: Method Call Tracking

```swift
func testInitializeCallsRequiredMethods() async throws {
    try await mockManager.initialize()

    XCTAssertEqual(mockManager.checkAccountStatusCallCount, 1)
    XCTAssertEqual(mockManager.ensureZoneExistsCallCount, 1)
}
```

## Best Practices

1. **Always reset mocks between tests**: Use `setUp()` and `tearDown()` to ensure clean state

2. **Use configuration helpers**: Prefer `configureForSuccess()` over manual property setting

3. **Verify both behavior and state**: Check return values AND call counts

4. **Test error paths**: Don't just test happy paths

5. **Use async helpers**: Leverage `AsyncTestHelpers` for cleaner async tests

6. **Isolate tests**: Each test should be independent and not rely on execution order

## Future Enhancements

- [ ] Add Combine publisher testing utilities
- [ ] Add helper for simulating CloudKit records
- [ ] Add builder pattern for complex mock scenarios
- [ ] Add mock for ItemRepository
- [ ] Add mock for SyncEngine
