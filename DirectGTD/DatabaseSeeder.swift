import Foundation

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
                    if let tag = tagMap[tagName] {
                        try repository.addTagToItem(itemId: item.id, tagId: tag.id)
                    }
                }
            }
        }

        // Create projects
        for projectSeed in seedData.projects {
            guard let folder = folderMap[projectSeed.folder] else {
                print("Warning: Folder '\(projectSeed.folder)' not found for project '\(projectSeed.title)'")
                continue
            }

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
                    if let tag = tagMap[tagName] {
                        try repository.addTagToItem(itemId: project.id, tagId: tag.id)
                    }
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
            throw NSError(domain: "DatabaseSeeder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find \(configFileName) in bundle"])
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(SeedData.self, from: data)
    }

    private func createItemFromSeed(_ itemSeed: ItemSeed, folderMap: [String: Folder], tagMap: [String: Tag]) throws {
        guard let folder = folderMap[itemSeed.folder] else {
            print("Warning: Folder '\(itemSeed.folder)' not found for item '\(itemSeed.title)'")
            return
        }

        var dueDate: Int?
        if let dueInDays = itemSeed.dueInDays {
            dueDate = Int(Date().addingTimeInterval(86400 * Double(dueInDays)).timeIntervalSince1970)
        }

        var completedAt: Int?
        if let completedDaysAgo = itemSeed.completedDaysAgo {
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
                if let tag = tagMap[tagName] {
                    try repository.addTagToItem(itemId: item.id, tagId: tag.id)
                }
            }
        }
    }
}
