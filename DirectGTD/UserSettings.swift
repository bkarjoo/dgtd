import DirectGTDCore
import Foundation
import SwiftUI
import Combine

class UserSettings: ObservableObject {
    private let defaults: UserDefaults

    // Keys for UserDefaults
    private enum Keys {
        static let fontSize = "fontSize"
        static let expandedItemIds = "expandedItemIds"
        static let horizontalMargin = "horizontalMargin"
        static let verticalMargin = "verticalMargin"
        static let lineSpacing = "lineSpacing"
        static let showCompletedTasks = "showCompletedTasks"
        static let markdownFontSize = "markdownFontSize"
        static let markdownLineSpacing = "markdownLineSpacing"
        static let rightPaneView = "rightPaneView"
    }

    @Published var fontSize: CGFloat {
        didSet {
            defaults.set(fontSize, forKey: Keys.fontSize)
        }
    }

    @Published var expandedItemIds: Set<String> {
        didSet {
            defaults.set(Array(expandedItemIds), forKey: Keys.expandedItemIds)
        }
    }

    @Published var horizontalMargin: CGFloat {
        didSet {
            defaults.set(horizontalMargin, forKey: Keys.horizontalMargin)
        }
    }

    @Published var verticalMargin: CGFloat {
        didSet {
            defaults.set(verticalMargin, forKey: Keys.verticalMargin)
        }
    }

    @Published var lineSpacing: CGFloat {
        didSet {
            defaults.set(lineSpacing, forKey: Keys.lineSpacing)
        }
    }

    @Published var showCompletedTasks: Bool {
        didSet {
            defaults.set(showCompletedTasks, forKey: Keys.showCompletedTasks)
        }
    }

    @Published var markdownFontSize: CGFloat {
        didSet {
            defaults.set(markdownFontSize, forKey: Keys.markdownFontSize)
        }
    }

    @Published var markdownLineSpacing: CGFloat {
        didSet {
            defaults.set(markdownLineSpacing, forKey: Keys.markdownLineSpacing)
        }
    }

    @Published var rightPaneView: RightPaneView {
        didSet {
            defaults.set(rightPaneView.rawValue, forKey: Keys.rightPaneView)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Load fontSize from UserDefaults, default to 13
        self.fontSize = defaults.object(forKey: Keys.fontSize) as? CGFloat ?? 13

        // Load expandedItemIds from UserDefaults, default to empty set
        let savedIds = defaults.stringArray(forKey: Keys.expandedItemIds) ?? []
        self.expandedItemIds = Set(savedIds)

        // Load margins and spacing, defaults: horizontal=8, vertical=4, lineSpacing=0
        self.horizontalMargin = defaults.object(forKey: Keys.horizontalMargin) as? CGFloat ?? 8
        self.verticalMargin = defaults.object(forKey: Keys.verticalMargin) as? CGFloat ?? 4
        self.lineSpacing = defaults.object(forKey: Keys.lineSpacing) as? CGFloat ?? 0

        // Load showCompletedTasks, default to true
        self.showCompletedTasks = defaults.object(forKey: Keys.showCompletedTasks) as? Bool ?? true

        // Load markdownFontSize, default to 14
        self.markdownFontSize = defaults.object(forKey: Keys.markdownFontSize) as? CGFloat ?? 14

        // Load markdownLineSpacing, default to 4
        self.markdownLineSpacing = defaults.object(forKey: Keys.markdownLineSpacing) as? CGFloat ?? 4

        // Load rightPaneView, default to noteEditor
        if let storedPane = defaults.string(forKey: Keys.rightPaneView),
           let pane = RightPaneView(rawValue: storedPane) {
            self.rightPaneView = pane
        } else {
            self.rightPaneView = .noteEditor
        }
    }
}
