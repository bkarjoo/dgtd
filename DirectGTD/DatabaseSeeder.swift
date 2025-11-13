import Foundation

class DatabaseSeeder {
    private let repository: ItemRepository

    init(repository: ItemRepository = ItemRepository()) {
        self.repository = repository
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

        // Create default folders (fully customizable by user)
        let inboxFolder = Folder(name: "Inbox", icon: "tray", color: "#3B82F6", sortOrder: 0)
        let projectsFolder = Folder(name: "Projects", icon: "folder", color: "#8B5CF6", sortOrder: 1)
        let referenceFolder = Folder(name: "Reference", icon: "doc.text", color: "#10B981", sortOrder: 2)
        let trashFolder = Folder(name: "Trash", icon: "trash", color: "#EF4444", sortOrder: 3)

        try repository.createFolder(inboxFolder)
        try repository.createFolder(projectsFolder)
        try repository.createFolder(referenceFolder)
        try repository.createFolder(trashFolder)

        // Create some tags
        let workTag = Tag(name: "work", color: "#3B82F6")
        let personalTag = Tag(name: "personal", color: "#10B981")
        let urgentTag = Tag(name: "urgent", color: "#EF4444")

        try repository.createTag(workTag)
        try repository.createTag(personalTag)
        try repository.createTag(urgentTag)

        // Inbox items
        let inboxItem1 = try repository.addToInbox(
            title: "Review quarterly budget",
            description: "Need to go through Q4 numbers before Friday meeting"
        )
        try repository.addTagToItem(itemId: inboxItem1.id, tagId: workTag.id)
        try repository.addTagToItem(itemId: inboxItem1.id, tagId: urgentTag.id)

        let inboxItem2 = try repository.addToInbox(
            title: "Call dentist for appointment",
            description: "Overdue for cleaning"
        )
        try repository.addTagToItem(itemId: inboxItem2.id, tagId: personalTag.id)

        let inboxItem3 = try repository.addToInbox(
            title: "Research new project management tools"
        )
        try repository.addTagToItem(itemId: inboxItem3.id, tagId: workTag.id)

        // Create a project with sub-items
        var websiteProject = Item(
            title: "Redesign company website",
            description: "Complete overhaul of company site with modern design",
            status: "next_action",
            folderId: projectsFolder.id,
            context: "@computer",
            isProject: true
        )
        try repository.create(websiteProject)
        try repository.addTagToItem(itemId: websiteProject.id, tagId: workTag.id)

        let subItem1 = try repository.addSubItem(
            parentId: websiteProject.id,
            title: "Create wireframes for homepage",
            description: "Work with design team"
        )

        let subItem2 = try repository.addSubItem(
            parentId: websiteProject.id,
            title: "Review hosting options",
            description: "Compare pricing for Vercel, Netlify, AWS"
        )

        let subItem3 = try repository.addSubItem(
            parentId: websiteProject.id,
            title: "Set up staging environment"
        )

        // Add a note to the project
        let projectNote = Note(
            itemId: websiteProject.id,
            content: "Discussed with team - targeting launch date of March 1st. Budget approved for $5000."
        )
        try repository.createNote(projectNote)

        // Next actions
        var nextAction1 = Item(
            title: "Send proposal to client",
            description: "Follow up on last week's meeting",
            status: "next_action",
            folderId: projectsFolder.id,
            context: "@computer",
            dueDate: Int(Date().addingTimeInterval(86400 * 3).timeIntervalSince1970) // 3 days from now
        )
        try repository.create(nextAction1)
        try repository.addTagToItem(itemId: nextAction1.id, tagId: workTag.id)
        try repository.addTagToItem(itemId: nextAction1.id, tagId: urgentTag.id)

        var nextAction2 = Item(
            title: "Buy groceries",
            status: "next_action",
            folderId: projectsFolder.id,
            context: "@errands",
            timeEstimate: 45
        )
        try repository.create(nextAction2)
        try repository.addTagToItem(itemId: nextAction2.id, tagId: personalTag.id)

        var nextAction3 = Item(
            title: "Review pull requests",
            description: "Check PRs from the team",
            status: "next_action",
            folderId: projectsFolder.id,
            context: "@computer",
            energyLevel: "medium",
            timeEstimate: 30
        )
        try repository.create(nextAction3)
        try repository.addTagToItem(itemId: nextAction3.id, tagId: workTag.id)

        // Waiting items
        var waitingItem1 = Item(
            title: "Feedback from Sarah on design mockups",
            status: "waiting",
            folderId: projectsFolder.id,
            context: "@waiting"
        )
        try repository.create(waitingItem1)
        try repository.addTagToItem(itemId: waitingItem1.id, tagId: workTag.id)

        var waitingItem2 = Item(
            title: "Approval for vacation request",
            status: "waiting",
            folderId: projectsFolder.id,
            context: "@waiting"
        )
        try repository.create(waitingItem2)
        try repository.addTagToItem(itemId: waitingItem2.id, tagId: personalTag.id)

        // Someday/Maybe items
        var somedayItem1 = Item(
            title: "Learn SwiftUI animations",
            status: "someday",
            folderId: projectsFolder.id
        )
        try repository.create(somedayItem1)
        try repository.addTagToItem(itemId: somedayItem1.id, tagId: personalTag.id)

        var somedayItem2 = Item(
            title: "Write blog post about GTD methodology",
            status: "someday",
            folderId: projectsFolder.id
        )
        try repository.create(somedayItem2)
        try repository.addTagToItem(itemId: somedayItem2.id, tagId: workTag.id)

        // Reference items
        var referenceItem1 = Item(
            title: "Password manager master password",
            description: "Stored in secure location",
            status: "next_action",
            folderId: referenceFolder.id
        )
        try repository.create(referenceItem1)

        var referenceItem2 = Item(
            title: "Meeting notes from 2025-11-05",
            description: "Quarterly planning session",
            status: "next_action",
            folderId: referenceFolder.id
        )
        try repository.create(referenceItem2)
        try repository.addTagToItem(itemId: referenceItem2.id, tagId: workTag.id)

        // Completed item
        var completedItem = Item(
            title: "Complete onboarding documentation",
            status: "completed",
            folderId: projectsFolder.id,
            completedAt: Int(Date().addingTimeInterval(-86400).timeIntervalSince1970) // completed yesterday
        )
        try repository.create(completedItem)
        try repository.addTagToItem(itemId: completedItem.id, tagId: workTag.id)

        print("Database seeded successfully with sample GTD data!")
    }
}
