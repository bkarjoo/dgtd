import SwiftUI

struct TagEditorView: View {
    @ObservedObject var store: ItemStore
    @Environment(\.dismiss) var dismiss

    let tagToEdit: Tag?
    let onSave: (String, String) -> Void

    @State private var name: String
    @State private var color: Color

    init(store: ItemStore, tagToEdit: Tag? = nil, onSave: @escaping (String, String) -> Void) {
        self.store = store
        self.tagToEdit = tagToEdit
        self.onSave = onSave

        // Initialize state from existing tag or defaults
        _name = State(initialValue: tagToEdit?.name ?? "")
        _color = State(initialValue: Color(hex: tagToEdit?.color ?? "#808080") ?? .gray)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(tagToEdit == nil ? "New Tag" : "Edit Tag")
                .font(.headline)

            // Tag name field
            TextField("Tag name", text: $name)
                .textFieldStyle(.roundedBorder)

            // Color picker
            ColorPicker("Color", selection: $color)

            // Preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Preview:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TagChip(tag: Tag(name: name.isEmpty ? "Tag Name" : name, color: color.toHex()))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    onSave(name, color.toHex())
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

// Helper extension to convert Color to hex string
extension Color {
    func toHex() -> String {
        guard let components = NSColor(self).cgColor.components else {
            return "#808080"
        }

        let r = components[0]
        let g = components[1]
        let b = components[2]

        return String(format: "#%02X%02X%02X",
                      Int(r * 255),
                      Int(g * 255),
                      Int(b * 255))
    }
}
