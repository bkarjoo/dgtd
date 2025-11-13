import SwiftUI

struct FolderTreeView: View {
    @State private var folders: [Folder] = []
    private let repository = ItemRepository()

    var body: some View {
        VStack {
            if folders.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No folders found")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Database may be empty")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(visibleFolders(), id: \.folder.id) { item in
                            FolderRow(
                                folder: item.folder,
                                depth: item.depth,
                                toggle: { toggleFolder(item.folder) }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
        .navigationTitle("Folders")
        .toolbar {
            ToolbarItem {
                Button("Reset DB") {
                    resetDatabase()
                }
            }
        }
        .onAppear {
            loadFolders()
        }
    }

    private func resetDatabase() {
        do {
            // Delete all folders
            let allFolders = try repository.getAllFolders()
            for folder in allFolders {
                try repository.deleteFolder(folderId: folder.id)
            }

            // Reseed
            let seeder = DatabaseSeeder()
            try seeder.seed()

            // Reload
            loadFolders()
        } catch {
            print("Error resetting database: \(error)")
        }
    }

    private func loadFolders() {
        do {
            folders = try repository.getAllFolders()
            print("Loaded \(folders.count) folders from database")
            for folder in folders {
                print("  - \(folder.name) (id: \(folder.id), parent: \(folder.parentId ?? "nil"))")
            }
        } catch {
            print("Error loading folders: \(error)")
        }
    }

    private func toggleFolder(_ folder: Folder) {
        do {
            try repository.toggleFolderExpansion(folderId: folder.id)
            loadFolders() // Reload to get updated state
        } catch {
            print("Error toggling folder: \(error)")
        }
    }

    // Flatten the visible tree based on expanded state from database
    private func visibleFolders() -> [(folder: Folder, depth: Int)] {
        var result: [(Folder, Int)] = []

        // Build a map of folder ID to its children
        var childrenMap: [String: [Folder]] = [:]
        for folder in folders {
            if let parentId = folder.parentId {
                childrenMap[parentId, default: []].append(folder)
            }
        }

        // Sort children by sort_order
        for key in childrenMap.keys {
            childrenMap[key]?.sort { $0.sortOrder < $1.sortOrder }
        }

        // Get root folders (those without a parent)
        let rootFolders = folders
            .filter { $0.parentId == nil }
            .sorted { $0.sortOrder < $1.sortOrder }

        func walk(_ folders: [Folder], depth: Int) {
            for folder in folders {
                result.append((folder, depth))
                if folder.isExpanded, let children = childrenMap[folder.id] {
                    walk(children, depth: depth + 1)
                }
            }
        }

        walk(rootFolders, depth: 0)
        return result
    }
}

struct FolderRow: View {
    let folder: Folder
    let depth: Int
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Indentation for nested folders
            if depth > 0 {
                Rectangle()
                    .frame(width: CGFloat(depth) * 20, height: 0)
                    .opacity(0)
            }

            // Disclosure indicator for folders with children (shown if folder has potential children based on hierarchy)
            // We'll show chevron for all folders for now, but can optimize later to check if children exist
            Button(action: toggle) {
                Image(systemName: folder.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Folder icon
            if let iconName = folder.icon {
                Image(systemName: iconName)
                    .font(.system(size: 16))
                    .foregroundColor(colorFromHex(folder.color))
                    .frame(width: 20, height: 20)
            }

            // Folder name
            Text(folder.name)
                .font(.system(size: 14))
                .lineLimit(1)

            Spacer()
        }
        .contentShape(Rectangle())
        .padding(.vertical, 6)
        .background(Color.clear)
    }

    private func colorFromHex(_ hex: String?) -> Color {
        guard let hex = hex else { return .blue }

        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var hexNumber: UInt64 = 0

        if scanner.scanHexInt64(&hexNumber) {
            let r = Double((hexNumber & 0xff0000) >> 16) / 255
            let g = Double((hexNumber & 0x00ff00) >> 8) / 255
            let b = Double(hexNumber & 0x0000ff) / 255
            return Color(red: r, green: g, blue: b)
        }

        return .blue
    }
}

#Preview {
    NavigationSplitView {
        FolderTreeView()
    } detail: {
        Text("Select a folder")
            .font(.title)
            .foregroundColor(.secondary)
    }
}
