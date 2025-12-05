import XCTest
@testable import DirectGTD

final class UserSettingsTests: XCTestCase {
    private let testSuiteName = "UserSettingsTests"
    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        // Create isolated UserDefaults for testing
        testDefaults = UserDefaults(suiteName: testSuiteName)!
        testDefaults.removePersistentDomain(forName: testSuiteName)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: testSuiteName)
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitializationWithDefaults() throws {
        let settings = UserSettings()

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
        var settings = UserSettings()
        settings.fontSize = 16

        // Create new instance to verify persistence
        settings = UserSettings()
        XCTAssertEqual(settings.fontSize, 16)
    }

    func testFontSizeUpdate() throws {
        let settings = UserSettings()
        settings.fontSize = 20

        let stored = UserDefaults.standard.object(forKey: "fontSize") as? CGFloat
        XCTAssertEqual(stored, 20)
    }

    // MARK: - ExpandedItemIds Tests

    func testExpandedItemIdsInitiallyEmpty() throws {
        let settings = UserSettings()
        XCTAssertTrue(settings.expandedItemIds.isEmpty)
    }

    func testExpandedItemIdsPersistence() throws {
        var settings = UserSettings()
        settings.expandedItemIds = ["item1", "item2", "item3"]

        // Create new instance to verify persistence
        settings = UserSettings()
        XCTAssertEqual(settings.expandedItemIds, ["item1", "item2", "item3"])
    }

    func testExpandedItemIdsUpdate() throws {
        let settings = UserSettings()
        settings.expandedItemIds = ["item1", "item2"]

        let stored = UserDefaults.standard.stringArray(forKey: "expandedItemIds")
        XCTAssertEqual(Set(stored ?? []), Set(["item1", "item2"]))
    }

    func testExpandedItemIdsAddRemove() throws {
        let settings = UserSettings()

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
        var settings = UserSettings()
        settings.horizontalMargin = 12

        settings = UserSettings()
        XCTAssertEqual(settings.horizontalMargin, 12)
    }

    func testVerticalMarginPersistence() throws {
        var settings = UserSettings()
        settings.verticalMargin = 6

        settings = UserSettings()
        XCTAssertEqual(settings.verticalMargin, 6)
    }

    func testLineSpacingPersistence() throws {
        var settings = UserSettings()
        settings.lineSpacing = 2

        settings = UserSettings()
        XCTAssertEqual(settings.lineSpacing, 2)
    }

    // MARK: - ShowCompletedTasks Tests

    func testShowCompletedTasksDefaultsToTrue() throws {
        let settings = UserSettings()
        XCTAssertTrue(settings.showCompletedTasks)
    }

    func testShowCompletedTasksPersistence() throws {
        var settings = UserSettings()
        settings.showCompletedTasks = false

        settings = UserSettings()
        XCTAssertFalse(settings.showCompletedTasks)
    }

    func testShowCompletedTasksToggle() throws {
        let settings = UserSettings()
        let initial = settings.showCompletedTasks

        settings.showCompletedTasks.toggle()
        XCTAssertEqual(settings.showCompletedTasks, !initial)

        settings.showCompletedTasks.toggle()
        XCTAssertEqual(settings.showCompletedTasks, initial)
    }

    // MARK: - Markdown Settings Tests

    func testMarkdownFontSizePersistence() throws {
        var settings = UserSettings()
        settings.markdownFontSize = 18

        settings = UserSettings()
        XCTAssertEqual(settings.markdownFontSize, 18)
    }

    func testMarkdownLineSpacingPersistence() throws {
        var settings = UserSettings()
        settings.markdownLineSpacing = 6

        settings = UserSettings()
        XCTAssertEqual(settings.markdownLineSpacing, 6)
    }

    // MARK: - RightPaneView Tests

    func testRightPaneViewDefaultsToNoteEditor() throws {
        let settings = UserSettings()
        XCTAssertEqual(settings.rightPaneView, .noteEditor)
    }

    func testRightPaneViewPersistence() throws {
        var settings = UserSettings()
        settings.rightPaneView = .detail

        settings = UserSettings()
        XCTAssertEqual(settings.rightPaneView, .detail)
    }

    func testRightPaneViewSwitch() throws {
        let settings = UserSettings()

        settings.rightPaneView = .detail
        XCTAssertEqual(settings.rightPaneView, .detail)

        settings.rightPaneView = .noteEditor
        XCTAssertEqual(settings.rightPaneView, .noteEditor)
    }

    // MARK: - Integration Tests

    func testMultipleSettingsPersistTogether() throws {
        var settings = UserSettings()
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
        settings = UserSettings()

        // Verify all settings persisted
        XCTAssertEqual(settings.fontSize, 15)
        XCTAssertEqual(settings.horizontalMargin, 10)
        XCTAssertEqual(settings.verticalMargin, 5)
        XCTAssertEqual(settings.lineSpacing, 3)
        XCTAssertEqual(settings.showCompletedTasks, false)
        XCTAssertEqual(settings.markdownFontSize, 16)
        XCTAssertEqual(settings.markdownLineSpacing, 5)
        XCTAssertEqual(settings.rightPaneView, .detail)
        XCTAssertEqual(settings.expandedItemIds, ["a", "b", "c"])
    }

    func testSettingsIndependenceAcrossInstances() throws {
        let settings1 = UserSettings()
        let settings2 = UserSettings()

        settings1.fontSize = 20
        XCTAssertEqual(settings2.fontSize, 13) // settings2 should still have default

        // But after creating a fresh instance, it should pick up the persisted value
        let settings3 = UserSettings()
        XCTAssertEqual(settings3.fontSize, 20)
    }
}
