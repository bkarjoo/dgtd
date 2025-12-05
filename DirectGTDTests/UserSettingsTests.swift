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

        // Create new instance to verify persistence
        let newSettings = UserSettings(defaults: testDefaults)
        XCTAssertEqual(newSettings.fontSize, 16)
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

        // Create new instance to verify persistence
        let newSettings = UserSettings(defaults: testDefaults)
        XCTAssertEqual(newSettings.expandedItemIds, ["item1", "item2", "item3"])
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

        let newSettings = UserSettings(defaults: testDefaults)
        XCTAssertEqual(newSettings.horizontalMargin, 12)
    }

    func testVerticalMarginPersistence() throws {
        settings.verticalMargin = 6

        let newSettings = UserSettings(defaults: testDefaults)
        XCTAssertEqual(newSettings.verticalMargin, 6)
    }

    func testLineSpacingPersistence() throws {
        settings.lineSpacing = 2

        let newSettings = UserSettings(defaults: testDefaults)
        XCTAssertEqual(newSettings.lineSpacing, 2)
    }

    // MARK: - ShowCompletedTasks Tests

    func testShowCompletedTasksDefaultsToTrue() throws {
        XCTAssertTrue(settings.showCompletedTasks)
    }

    func testShowCompletedTasksPersistence() throws {
        settings.showCompletedTasks = false

        let newSettings = UserSettings(defaults: testDefaults)
        XCTAssertFalse(newSettings.showCompletedTasks)
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

        let newSettings = UserSettings(defaults: testDefaults)
        XCTAssertEqual(newSettings.markdownFontSize, 18)
    }

    func testMarkdownLineSpacingPersistence() throws {
        settings.markdownLineSpacing = 6

        let newSettings = UserSettings(defaults: testDefaults)
        XCTAssertEqual(newSettings.markdownLineSpacing, 6)
    }

    // MARK: - RightPaneView Tests

    func testRightPaneViewDefaultsToNoteEditor() throws {
        XCTAssertEqual(settings.rightPaneView, .noteEditor)
    }

    func testRightPaneViewPersistence() throws {
        settings.rightPaneView = .detail

        let newSettings = UserSettings(defaults: testDefaults)
        XCTAssertEqual(newSettings.rightPaneView, .detail)
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

        // Create new instance
        let newSettings = UserSettings(defaults: testDefaults)

        // Verify all settings persisted
        XCTAssertEqual(newSettings.fontSize, 15)
        XCTAssertEqual(newSettings.horizontalMargin, 10)
        XCTAssertEqual(newSettings.verticalMargin, 5)
        XCTAssertEqual(newSettings.lineSpacing, 3)
        XCTAssertEqual(newSettings.showCompletedTasks, false)
        XCTAssertEqual(newSettings.markdownFontSize, 16)
        XCTAssertEqual(newSettings.markdownLineSpacing, 5)
        XCTAssertEqual(newSettings.rightPaneView, .detail)
        XCTAssertEqual(newSettings.expandedItemIds, ["a", "b", "c"])
    }

    func testSettingsIndependenceAcrossInstances() throws {
        let settings1 = UserSettings(defaults: testDefaults)
        let settings2 = UserSettings(defaults: testDefaults)

        settings1.fontSize = 20
        XCTAssertEqual(settings2.fontSize, 13) // settings2 should still have default

        // But after creating a fresh instance, it should pick up the persisted value
        let settings3 = UserSettings(defaults: testDefaults)
        XCTAssertEqual(settings3.fontSize, 20)
    }
}
