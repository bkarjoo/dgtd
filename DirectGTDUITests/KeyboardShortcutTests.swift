import XCTest

/// UI tests for critical keyboard shortcuts
/// These tests verify that core keyboard shortcuts work as expected
final class KeyboardShortcutTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()

        // Wait for app to be ready
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "App window should appear")
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - Item Creation Tests

    /// **REGRESSION TEST FOR COMMIT fb49709**
    /// Tests that pressing Enter creates a new item in the main tree view.
    ///
    /// **BUG**: This test currently FAILS because the Enter key shortcut was broken
    /// in commit fb49709 ("Add quick capture, settings UI, item types, and task management features").
    /// The `.keyboardShortcut(.defaultAction)` was moved exclusively into the Quick Capture sheet,
    /// removing it from the main item creation flow.
    ///
    /// **Expected behavior**: Pressing Enter anywhere in the tree view should create a new item
    /// **Actual behavior**: Enter key does nothing; only works inside Quick Capture sheet
    ///
    /// **How to reproduce manually**:
    /// 1. Launch DirectGTD
    /// 2. Focus on the tree view
    /// 3. Press Enter
    /// 4. Expected: New item created
    /// 5. Actual: Nothing happens
    ///
    func testEnterKeyCreatesNewItem() throws {
        // Arrange: Count initial items
        let initialItemCount = app.outlines.firstMatch.cells.count

        // Act: Press Enter to create new item
        app.typeKey(.return, modifierFlags: [])

        // Give UI time to update
        Thread.sleep(forTimeInterval: 0.5)

        // Assert: New item should be created
        let newItemCount = app.outlines.firstMatch.cells.count
        XCTAssertEqual(newItemCount, initialItemCount + 1,
                       """
                       ❌ REGRESSION: Enter key failed to create new item!

                       Expected: \(initialItemCount + 1) items
                       Actual: \(newItemCount) items

                       This broke in commit fb49709 when .keyboardShortcut(.defaultAction)
                       was moved into the Quick Capture sheet only.

                       The Enter key shortcut MUST work in the main tree view.
                       This is CORE FUNCTIONALITY.
                       """)
    }

    /// Tests that Enter key works inside the Quick Capture sheet
    /// (This should PASS - the shortcut works here, just not in main view)
    func testEnterKeyWorksInQuickCaptureSheet() throws {
        // Arrange: Open Quick Capture sheet
        // This assumes there's a way to trigger Quick Capture (e.g., Cmd+K or menu item)
        // Adjust the trigger mechanism based on how Quick Capture is accessed

        // Try to find and click Quick Capture button/menu
        // This might need adjustment based on actual UI
        let quickCaptureButton = app.buttons["Quick Capture"]
        if quickCaptureButton.exists {
            quickCaptureButton.click()
        } else {
            // Try keyboard shortcut if there is one
            // Skip test if we can't open Quick Capture
            throw XCTSkip("Quick Capture sheet not accessible in UI test")
        }

        // Wait for sheet to appear
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 2), "Quick Capture sheet should appear")

        // Count initial items
        let initialItemCount = app.outlines.firstMatch.cells.count

        // Act: Type item title and press Enter
        let textField = sheet.textFields.firstMatch
        XCTAssertTrue(textField.exists, "Text field should exist in Quick Capture sheet")
        textField.click()
        textField.typeText("Test Quick Capture Item")
        textField.typeKey(.return, modifierFlags: [])

        // Wait for sheet to dismiss and item to be created
        Thread.sleep(forTimeInterval: 0.5)

        // Assert: Sheet should close and item should be created
        XCTAssertFalse(sheet.exists, "Quick Capture sheet should close after adding item")

        let newItemCount = app.outlines.firstMatch.cells.count
        XCTAssertEqual(newItemCount, initialItemCount + 1,
                       "Quick Capture Enter key should create new item")
    }

    // MARK: - Other Critical Shortcuts

    /// Tests that Tab key indents an item
    func testTabKeyIndentsItem() throws {
        // TODO: Implement once we have reliable item selection/creation
        throw XCTSkip("Not implemented yet - need base UI test infrastructure")
    }

    /// Tests that Shift+Tab outdents an item
    func testShiftTabKeyOutdentsItem() throws {
        // TODO: Implement once we have reliable item selection/creation
        throw XCTSkip("Not implemented yet - need base UI test infrastructure")
    }

    /// Tests that Delete key removes an item
    func testDeleteKeyRemovesItem() throws {
        throw XCTSkip("UI test hangs - needs manual testing instead")
    }

    /// Tests that Cmd+N creates a new item
    func testCmdNCreatesNewItem() throws {
        // Arrange: Count initial items
        let initialItemCount = app.outlines.firstMatch.cells.count

        // Act: Press Cmd+N
        app.typeKey("n", modifierFlags: .command)

        // Give UI time to update
        Thread.sleep(forTimeInterval: 0.5)

        // Assert: New item should be created
        let newItemCount = app.outlines.firstMatch.cells.count
        XCTAssertEqual(newItemCount, initialItemCount + 1,
                       "Cmd+N should create new item")
    }
}
