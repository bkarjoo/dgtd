import Foundation
import SwiftUI
import Combine

class UserSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    // Keys for UserDefaults
    private enum Keys {
        static let fontSize = "fontSize"
        static let expandedItemIds = "expandedItemIds"
        static let horizontalMargin = "horizontalMargin"
        static let verticalMargin = "verticalMargin"
        static let lineSpacing = "lineSpacing"
        static let showCompletedTasks = "showCompletedTasks"
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

    init() {
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
    }
}
