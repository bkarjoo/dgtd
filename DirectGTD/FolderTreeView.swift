import SwiftUI

// Mock folder structure for styling
struct MockFolder: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    var children: [MockFolder]?

    static func == (lhs: MockFolder, rhs: MockFolder) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct FolderTreeView: View {
    @State private var folders: [MockFolder] = [
        MockFolder(name: "Inbox", icon: "tray.fill", color: .blue, children: nil),
        MockFolder(name: "Projects", icon: "folder.fill", color: .purple, children: [
            MockFolder(name: "Work", icon: "briefcase.fill", color: .orange, children: [
                MockFolder(name: "Q4 Goals", icon: "target", color: .red, children: nil),
                MockFolder(name: "Team Projects", icon: "person.2.fill", color: .green, children: nil)
            ]),
            MockFolder(name: "Personal", icon: "house.fill", color: .pink, children: [
                MockFolder(name: "Health", icon: "heart.fill", color: .red, children: nil),
                MockFolder(name: "Learning", icon: "book.fill", color: .blue, children: nil)
            ])
        ]),
        MockFolder(name: "Reference", icon: "doc.text.fill", color: .green, children: nil),
        MockFolder(name: "Trash", icon: "trash.fill", color: .red, children: nil)
    ]

    // Keep expansion state at container level (not inside rows)
    @State private var expanded: Set<UUID> = []

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(visibleFolders(), id: \.folder.id) { item in
                    FolderRow(
                        folder: item.folder,
                        depth: item.depth,
                        isExpanded: expanded.contains(item.folder.id),
                        toggle: { toggle(item.folder.id) }
                    )
                }
            }
            // Disable implicit row animations that cause leftover space
            .animation(nil, value: expanded)
            .padding(.horizontal, 8)
        }
        .navigationTitle("Folders")
        .onAppear {
            // Expand Projects folder by default
            if let projectsFolder = folders.first(where: { $0.name == "Projects" }) {
                expanded.insert(projectsFolder.id)
            }
        }
    }

    private func toggle(_ id: UUID) {
        if expanded.contains(id) {
            expanded.remove(id)
        } else {
            expanded.insert(id)
        }
    }

    // Flatten the visible tree based on expanded state
    private func visibleFolders() -> [(folder: MockFolder, depth: Int)] {
        var result: [(MockFolder, Int)] = []

        func walk(_ folders: [MockFolder], depth: Int) {
            for folder in folders {
                result.append((folder, depth))
                if expanded.contains(folder.id), let children = folder.children {
                    walk(children, depth: depth + 1)
                }
            }
        }

        walk(folders, depth: 0)
        return result
    }
}

struct FolderRow: View {
    let folder: MockFolder
    let depth: Int
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Indentation for nested folders
            if depth > 0 {
                Rectangle()
                    .frame(width: CGFloat(depth) * 20, height: 0)
                    .opacity(0)
            }

            // Disclosure indicator for folders with children
            if let children = folder.children, !children.isEmpty {
                Button(action: toggle) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                // Reserve space for chevron to keep alignment consistent
                Color.clear
                    .frame(width: 20, height: 20)
            }

            // Folder icon
            Image(systemName: folder.icon)
                .font(.system(size: 16))
                .foregroundColor(folder.color)
                .frame(width: 20, height: 20)

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
