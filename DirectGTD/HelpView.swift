import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.headline)
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            // Shortcuts list
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ShortcutSection(title: "General") {
                        ShortcutRow(keys: "Cmd+?", description: "Show this help screen")
                        ShortcutRow(keys: "Cmd+R", description: "Refresh items from database")
                        ShortcutRow(keys: "Cmd+F", description: "Toggle text search")
                        ShortcutRow(keys: "Cmd+Shift+F", description: "Toggle focus mode")
                        ShortcutRow(keys: "Esc", description: "Cancel editing / Close dialogs")
                    }

                    ShortcutSection(title: "Navigation") {
                        ShortcutRow(keys: "↑ / ↓", description: "Move selection up/down")
                        ShortcutRow(keys: "→", description: "Expand selected item")
                        ShortcutRow(keys: "←", description: "Collapse selected item")
                    }

                    ShortcutSection(title: "Editing") {
                        ShortcutRow(keys: "Space", description: "Edit selected item")
                        ShortcutRow(keys: "Return", description: "Create new item after selection")
                        ShortcutRow(keys: "Delete", description: "Delete selected item")
                        ShortcutRow(keys: "Tab", description: "Indent item (make it a child)")
                        ShortcutRow(keys: "Shift+Tab", description: "Outdent item (promote to sibling)")
                    }

                    ShortcutSection(title: "Create Items") {
                        ShortcutRow(keys: "T", description: "Create task after selection")
                        ShortcutRow(keys: "N", description: "Create note after selection")
                        ShortcutRow(keys: "F", description: "Create folder after selection")
                        ShortcutRow(keys: "P", description: "Create project after selection")
                        ShortcutRow(keys: "E", description: "Create event after selection")
                        ShortcutRow(keys: "I", description: "Quick capture (create item in quick capture folder)")
                    }

                    ShortcutSection(title: "Tasks") {
                        ShortcutRow(keys: ".", description: "Toggle task completion")
                    }

                    ShortcutSection(title: "View") {
                        ShortcutRow(keys: "Cmd+Plus", description: "Increase font size")
                        ShortcutRow(keys: "Cmd+Minus", description: "Decrease font size")
                        ShortcutRow(keys: "Cmd+0", description: "Reset font size to default")
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 500)
    }
}

struct ShortcutSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 4) {
                content()
            }
        }
    }
}

struct ShortcutRow: View {
    let keys: String
    let description: String

    var body: some View {
        HStack {
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(4)
                .frame(width: 150, alignment: .leading)

            Text(description)
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

#Preview {
    HelpView()
}
