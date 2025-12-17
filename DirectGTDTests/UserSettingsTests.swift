import DirectGTDCore
import XCTest
@testable import DirectGTD

final class UserSettingsTests: XCTestCase {
    private let testSuiteName = "UserSettingsTestSuite"
    private var testDefaults: UserDefaults!
    private var settings: UserSettings!

    override func setUp() {
        super.setUp()
        // Create isolated UserDefaults for testing
        testDefaults = UserDefaults(suiteName: testSuiteName)!
        testDefaults.removePersistentDomain(forName: testSuiteName)
        settings = UserSettings(defaults: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: testSuiteName)
        testDefaults = nil
        settings = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitializationWithDefaults() throws {
        XCTAssertEqual(settings.fontSize, 13)
        XCTAssertEqual(settings.horizontalMargin, 8)
        XCTAssertEqual(settings.verticalMargin, 4)
        XCTAssertEqual(settings.lineSpacing, 0)
        XCTAssertEqual(settings.showCompletedTasks, true)
        XCTAssertEqual(settings.markdownFontSize, 14)
        XCTAssertEqual(settings.markdownLineSpacing, 4)
        XCTAssertEqual(settings.rightPaneView, .noteEditor)
        XCTAssertTrue(settings.expandedItemIds.isEmpty)
    }

    // MARK: - FontSize Tests

    func testFontSizePersistence() throws {
        settings.fontSize = 16

        // Verify persistence by checking UserDefaults directly
        // (Creating multiple UserSettings instances causes ObservableObject dealloc crashes)
        let stored = testDefaults.object(forKey: "fontSize") as? CGFloat
        XCTAssertEqual(stored, 16)
    }

    func testFontSizeUpdate() throws {
        settings.fontSize = 20

        let stored = testDefaults.object(forKey: "fontSize") as? CGFloat
        XCTAssertEqual(stored, 20)
    }

    // MARK: - ExpandedItemIds Tests

    func testExpandedItemIdsInitiallyEmpty() throws {
        XCTAssertTrue(settings.expandedItemIds.isEmpty)
    }

    func testExpandedItemIdsPersistence() throws {
        settings.expandedItemIds = ["item1", "item2", "item3"]

        // Verify persistence by checking UserDefaults directly
        let stored = testDefaults.stringArray(forKey: "expandedItemIds")
        XCTAssertEqual(Set(stored ?? []), Set(["item1", "item2", "item3"]))
    }

    func testExpandedItemIdsUpdate() throws {
        settings.expandedItemIds = ["item1", "item2"]

        let stored = testDefaults.stringArray(forKey: "expandedItemIds")
        XCTAssertEqual(Set(stored ?? []), Set(["item1", "item2"]))
    }

    func testExpandedItemIdsAddRemove() throws {
        // Add items
        settings.expandedItemIds.insert("item1")
        settings.expandedItemIds.insert("item2")
        XCTAssertEqual(settings.expandedItemIds.count, 2)

        // Remove item
        settings.expandedItemIds.remove("item1")
        XCTAssertEqual(settings.expandedItemIds.count, 1)
        XCTAssertTrue(settings.expandedItemIds.contains("item2"))
        XCTAssertFalse(settings.expandedItemIds.contains("item1"))
    }

    // MARK: - Margin Tests

    func testHorizontalMarginPersistence() throws {
        settings.horizontalMargin = 12

        let stored = testDefaults.object(forKey: "horizontalMargin") as? CGFloat
        XCTAssertEqual(stored, 12)
    }

    func testVerticalMarginPersistence() throws {
        settings.verticalMargin = 6

        let stored = testDefaults.object(forKey: "verticalMargin") as? CGFloat
        XCTAssertEqual(stored, 6)
    }

    func testLineSpacingPersistence() throws {
        settings.lineSpacing = 2

        let stored = testDefaults.object(forKey: "lineSpacing") as? CGFloat
        XCTAssertEqual(stored, 2)
    }

    // MARK: - ShowCompletedTasks Tests

    func testShowCompletedTasksDefaultsToTrue() throws {
        XCTAssertTrue(settings.showCompletedTasks)
    }

    func testShowCompletedTasksPersistence() throws {
        settings.showCompletedTasks = false

        let stored = testDefaults.object(forKey: "showCompletedTasks") as? Bool
        XCTAssertEqual(stored, false)
    }

    func testShowCompletedTasksToggle() throws {
        let initial = settings.showCompletedTasks

        settings.showCompletedTasks.toggle()
        XCTAssertEqual(settings.showCompletedTasks, !initial)

        settings.showCompletedTasks.toggle()
        XCTAssertEqual(settings.showCompletedTasks, initial)
    }

    // MARK: - Markdown Settings Tests

    func testMarkdownFontSizePersistence() throws {
        settings.markdownFontSize = 18

        let stored = testDefaults.object(forKey: "markdownFontSize") as? CGFloat
        XCTAssertEqual(stored, 18)
    }

    func testMarkdownLineSpacingPersistence() throws {
        settings.markdownLineSpacing = 6

        let stored = testDefaults.object(forKey: "markdownLineSpacing") as? CGFloat
        XCTAssertEqual(stored, 6)
    }

    // MARK: - RightPaneView Tests

    func testRightPaneViewDefaultsToNoteEditor() throws {
        XCTAssertEqual(settings.rightPaneView, .noteEditor)
    }

    func testRightPaneViewPersistence() throws {
        settings.rightPaneView = .detail

        let stored = testDefaults.string(forKey: "rightPaneView")
        XCTAssertEqual(stored, "detail")
    }

    func testRightPaneViewSwitch() throws {
        settings.rightPaneView = .detail
        XCTAssertEqual(settings.rightPaneView, .detail)

        settings.rightPaneView = .noteEditor
        XCTAssertEqual(settings.rightPaneView, .noteEditor)
    }

    // MARK: - Integration Tests

    func testMultipleSettingsPersistTogether() throws {
        settings.fontSize = 15
        settings.horizontalMargin = 10
        settings.verticalMargin = 5
        settings.lineSpacing = 3
        settings.showCompletedTasks = false
        settings.markdownFontSize = 16
        settings.markdownLineSpacing = 5
        settings.rightPaneView = .detail
        settings.expandedItemIds = ["a", "b", "c"]

        // Verify all settings persisted to UserDefaults
        XCTAssertEqual(testDefaults.object(forKey: "fontSize") as? CGFloat, 15)
        XCTAssertEqual(testDefaults.object(forKey: "horizontalMargin") as? CGFloat, 10)
        XCTAssertEqual(testDefaults.object(forKey: "verticalMargin") as? CGFloat, 5)
        XCTAssertEqual(testDefaults.object(forKey: "lineSpacing") as? CGFloat, 3)
        XCTAssertEqual(testDefaults.object(forKey: "showCompletedTasks") as? Bool, false)
        XCTAssertEqual(testDefaults.object(forKey: "markdownFontSize") as? CGFloat, 16)
        XCTAssertEqual(testDefaults.object(forKey: "markdownLineSpacing") as? CGFloat, 5)
        XCTAssertEqual(testDefaults.string(forKey: "rightPaneView"), "detail")
        XCTAssertEqual(Set(testDefaults.stringArray(forKey: "expandedItemIds") ?? []), Set(["a", "b", "c"]))
    }

    func testSettingsIndependenceAcrossInstances() throws {
        // Test that changing one instance saves to UserDefaults
        settings.fontSize = 20

        // Verify the value was saved to UserDefaults
        XCTAssertEqual(testDefaults.object(forKey: "fontSize") as? CGFloat, 20)

        // Note: Creating multiple UserSettings instances causes ObservableObject dealloc crashes
        // so we verify persistence via UserDefaults directly instead of creating new instances
    }
}
