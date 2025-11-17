import Foundation

// MARK: - Seed Data Error
enum SeedDataError: LocalizedError {
    case configFileNotFound(String)
    case invalidJSON(String)
    case invalidFolderReference(itemTitle: String, folderName: String)
    case invalidTagReference(itemTitle: String, tagName: String)
    case duplicateFolderName(String)
    case duplicateTagName(String)
    case invalidStatusValue(itemTitle: String, status: String)
    case invalidColorFormat(name: String, color: String)
    case invalidEnergyLevel(itemTitle: String, energyLevel: String)
    case invalidNumericRange(itemTitle: String, field: String, value: Int)

    var errorDescription: String? {
        switch self {
        case .configFileNotFound(let fileName):
            return "Seed data configuration file '\(fileName)' not found in bundle"
        case .invalidJSON(let details):
            return "Failed to parse seed data JSON: \(details)"
        case .invalidFolderReference(let itemTitle, let folderName):
            return "Item '\(itemTitle)' references non-existent folder '\(folderName)'"
        case .invalidTagReference(let itemTitle, let tagName):
            return "Item '\(itemTitle)' references non-existent tag '\(tagName)'"
        case .duplicateFolderName(let name):
            return "Duplicate folder name found: '\(name)'"
        case .duplicateTagName(let name):
            return "Duplicate tag name found: '\(name)'"
        case .invalidStatusValue(let itemTitle, let status):
            return "Item '\(itemTitle)' has invalid status '\(status)'. Valid values are: next_action, waiting, someday, completed"
        case .invalidColorFormat(let name, let color):
            return "'\(name)' has invalid color format '\(color)'. Expected format: #RRGGBB (e.g., #3B82F6)"
        case .invalidEnergyLevel(let itemTitle, let energyLevel):
            return "Item '\(itemTitle)' has invalid energy level '\(energyLevel)'. Valid values are: low, medium, high"
        case .invalidNumericRange(let itemTitle, let field, let value):
            return "Item '\(itemTitle)' has invalid value for \(field): \(value). Must be between 0 and 365"
        }
    }
}

// MARK: - Seed Data Models
struct SeedData: Codable {
    let folders: [FolderSeed]
    let tags: [TagSeed]
    let inboxItems: [InboxItemSeed]
    let projects: [ProjectSeed]
    let nextActions: [ItemSeed]
    let waitingItems: [ItemSeed]
    let somedayItems: [ItemSeed]
    let referenceItems: [ItemSeed]
    let completedItems: [ItemSeed]
}

struct FolderSeed: Codable {
    let name: String
    let icon: String
    let color: String
    let sortOrder: Int
}

struct TagSeed: Codable {
    let name: String
    let color: String
}

struct InboxItemSeed: Codable {
    let title: String
    let description: String?
    let tags: [String]?
}

struct ProjectSeed: Codable {
    let title: String
    let description: String?
    let status: String
    let folder: String
    let context: String?
    let tags: [String]?
    let subItems: [SubItemSeed]?
    let notes: [NoteSeed]?
}

struct SubItemSeed: Codable {
    let title: String
    let description: String?
}

struct NoteSeed: Codable {
    let content: String
}

struct ItemSeed: Codable {
    let title: String
    let description: String?
    let status: String
    let folder: String
    let context: String?
    let dueInDays: Int?
    let timeEstimate: Int?
    let energyLevel: String?
    let tags: [String]?
    let completedDaysAgo: Int?
}

class DatabaseSeeder {
    private let repository: ItemRepository
    private let configFileName: String

    init(repository: ItemRepository = ItemRepository(), configFileName: String = "SeedData.json") {
        self.repository = repository
        self.configFileName = configFileName
    }

    func seed() throws {
        // Check if already seeded
        let folders = try repository.getAllFolders()
        print("DatabaseSeeder: Found \(folders.count) existing folders")
        if !folders.isEmpty {
            print("Database already contains data, skipping seed")
            return
        }

        print("Seeding database with sample data...")

        // Load seed data from config file
        let seedData = try loadSeedData()

        // Create folders and store them in a dictionary
        var folderMap: [String: Folder] = [:]
        for folderSeed in seedData.folders {
            // Check for duplicate folder names
            guard folderMap[folderSeed.name] == nil else {
                throw SeedDataError.duplicateFolderName(folderSeed.name)
            }

            // Validate color format
            try validateColorFormat(folderSeed.color, for: "Folder '\(folderSeed.name)'")

            let folder = Folder(
                name: folderSeed.name,
                icon: folderSeed.icon,
                color: folderSeed.color,
                sortOrder: folderSeed.sortOrder
            )
            try repository.createFolder(folder)
            folderMap[folderSeed.name] = folder
        }

        // Create tags and store them in a dictionary
        var tagMap: [String: Tag] = [:]
        for tagSeed in seedData.tags {
            // Check for duplicate tag names
            guard tagMap[tagSeed.name] == nil else {
                throw SeedDataError.duplicateTagName(tagSeed.name)
            }

            // Validate color format
            try validateColorFormat(tagSeed.color, for: "Tag '\(tagSeed.name)'")

            let tag = Tag(name: tagSeed.name, color: tagSeed.color)
            try repository.createTag(tag)
            tagMap[tagSeed.name] = tag
        }

        // Create inbox items
        for inboxItemSeed in seedData.inboxItems {
            let item = try repository.addToInbox(
                title: inboxItemSeed.title,
                description: inboxItemSeed.description
            )

            // Add tags if specified
            if let tagNames = inboxItemSeed.tags {
                for tagName in tagNames {
                    guard let tag = tagMap[tagName] else {
                        throw SeedDataError.invalidTagReference(itemTitle: inboxItemSeed.title, tagName: tagName)
                    }
                    try repository.addTagToItem(itemId: item.id, tagId: tag.id)
                }
            }
        }

        // Create projects
        for projectSeed in seedData.projects {
            // Validate folder reference
            guard let folder = folderMap[projectSeed.folder] else {
                throw SeedDataError.invalidFolderReference(itemTitle: projectSeed.title, folderName: projectSeed.folder)
            }

            // Validate status
            try validateStatus(projectSeed.status, for: projectSeed.title)

            let project = Item(
                title: projectSeed.title,
                description: projectSeed.description,
                status: projectSeed.status,
                folderId: folder.id,
                context: projectSeed.context,
                isProject: true
            )
            try repository.create(project)

            // Add tags
            if let tagNames = projectSeed.tags {
                for tagName in tagNames {
                    guard let tag = tagMap[tagName] else {
                        throw SeedDataError.invalidTagReference(itemTitle: projectSeed.title, tagName: tagName)
                    }
                    try repository.addTagToItem(itemId: project.id, tagId: tag.id)
                }
            }

            // Add sub-items
            if let subItems = projectSeed.subItems {
                for subItemSeed in subItems {
                    _ = try repository.addSubItem(
                        parentId: project.id,
                        title: subItemSeed.title,
                        description: subItemSeed.description
                    )
                }
            }

            // Add notes
            if let notes = projectSeed.notes {
                for noteSeed in notes {
                    let note = Note(itemId: project.id, content: noteSeed.content)
                    try repository.createNote(note)
                }
            }
        }

        // Create next actions
        for actionSeed in seedData.nextActions {
            try createItemFromSeed(actionSeed, folderMap: folderMap, tagMap: tagMap)
        }

        // Create waiting items
        for waitingSeed in seedData.waitingItems {
            try createItemFromSeed(waitingSeed, folderMap: folderMap, tagMap: tagMap)
        }

        // Create someday items
        for somedaySeed in seedData.somedayItems {
            try createItemFromSeed(somedaySeed, folderMap: folderMap, tagMap: tagMap)
        }

        // Create reference items
        for referenceSeed in seedData.referenceItems {
            try createItemFromSeed(referenceSeed, folderMap: folderMap, tagMap: tagMap)
        }

        // Create completed items
        for completedSeed in seedData.completedItems {
            try createItemFromSeed(completedSeed, folderMap: folderMap, tagMap: tagMap)
        }

        print("Database seeded successfully with sample GTD data!")
    }

    private func loadSeedData() throws -> SeedData {
        guard let url = Bundle.main.url(forResource: configFileName.replacingOccurrences(of: ".json", with: ""), withExtension: "json") else {
            throw SeedDataError.configFileNotFound(configFileName)
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(SeedData.self, from: data)
        } catch {
            throw SeedDataError.invalidJSON(error.localizedDescription)
        }
    }

    // MARK: - Validation Helper Methods

    private func validateStatus(_ status: String, for itemTitle: String) throws {
        let validStatuses = ["next_action", "waiting", "someday", "completed"]
        guard validStatuses.contains(status) else {
            throw SeedDataError.invalidStatusValue(itemTitle: itemTitle, status: status)
        }
    }

    private func validateColorFormat(_ color: String, for name: String) throws {
        let hexColorRegex = "^#[0-9A-Fa-f]{6}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", hexColorRegex)
        guard predicate.evaluate(with: color) else {
            throw SeedDataError.invalidColorFormat(name: name, color: color)
        }
    }

    private func validateEnergyLevel(_ energyLevel: String, for itemTitle: String) throws {
        let validLevels = ["low", "medium", "high"]
        guard validLevels.contains(energyLevel) else {
            throw SeedDataError.invalidEnergyLevel(itemTitle: itemTitle, energyLevel: energyLevel)
        }
    }

    private func validateNumericRange(_ value: Int, field: String, for itemTitle: String) throws {
        guard value >= 0 && value <= 365 else {
            throw SeedDataError.invalidNumericRange(itemTitle: itemTitle, field: field, value: value)
        }
    }

    private func createItemFromSeed(_ itemSeed: ItemSeed, folderMap: [String: Folder], tagMap: [String: Tag]) throws {
        // Validate folder reference
        guard let folder = folderMap[itemSeed.folder] else {
            throw SeedDataError.invalidFolderReference(itemTitle: itemSeed.title, folderName: itemSeed.folder)
        }

        // Validate status
        try validateStatus(itemSeed.status, for: itemSeed.title)

        // Validate energy level if present
        if let energyLevel = itemSeed.energyLevel {
            try validateEnergyLevel(energyLevel, for: itemSeed.title)
        }

        // Validate numeric ranges
        if let timeEstimate = itemSeed.timeEstimate {
            try validateNumericRange(timeEstimate, field: "timeEstimate", for: itemSeed.title)
        }

        var dueDate: Int?
        if let dueInDays = itemSeed.dueInDays {
            try validateNumericRange(dueInDays, field: "dueInDays", for: itemSeed.title)
            dueDate = Int(Date().addingTimeInterval(86400 * Double(dueInDays)).timeIntervalSince1970)
        }

        var completedAt: Int?
        if let completedDaysAgo = itemSeed.completedDaysAgo {
            try validateNumericRange(completedDaysAgo, field: "completedDaysAgo", for: itemSeed.title)
            completedAt = Int(Date().addingTimeInterval(-86400 * Double(completedDaysAgo)).timeIntervalSince1970)
        }

        var item = Item(
            title: itemSeed.title,
            description: itemSeed.description,
            status: itemSeed.status,
            folderId: folder.id,
            context: itemSeed.context,
            completedAt: completedAt,
            dueDate: dueDate,
            energyLevel: itemSeed.energyLevel,
            timeEstimate: itemSeed.timeEstimate
        )
        try repository.create(item)

        // Add tags
        if let tagNames = itemSeed.tags {
            for tagName in tagNames {
                guard let tag = tagMap[tagName] else {
                    throw SeedDataError.invalidTagReference(itemTitle: itemSeed.title, tagName: tagName)
                }
                try repository.addTagToItem(itemId: item.id, tagId: tag.id)
            }
        }
    }
}
