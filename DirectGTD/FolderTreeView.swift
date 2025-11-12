import SwiftUI

// Mock folder structure for styling
struct MockFolder: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    var children: [MockFolder]?
    var isExpanded: Bool = true
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

    var body: some View {
        List {
            ForEach(folders) { folder in
                FolderRowView(folder: folder, level: 0)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Folders")
    }
}

struct FolderRowView: View {
    let folder: MockFolder
    let level: Int
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                // Indentation for nested folders
                if level > 0 {
                    Color.clear
                        .frame(width: CGFloat(level * 20))
                }

                // Disclosure indicator for folders with children
                if let children = folder.children, !children.isEmpty {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                } else if level > 0 {
                    // Spacer to align with expanded folders
                    Color.clear
                        .frame(width: 16, height: 16)
                }

                // Folder icon
                Image(systemName: folder.icon)
                    .font(.system(size: 16))
                    .foregroundColor(folder.color)
                    .frame(width: 20, height: 20)

                // Folder name
                Text(folder.name)
                    .font(.system(size: 14))

                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())

            // Children (nested folders)
            if let children = folder.children, isExpanded {
                ForEach(children) { child in
                    FolderRowView(folder: child, level: level + 1)
                }
            }
        }
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
