import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: UserSettings
    @ObservedObject var store: ItemStore
    @Environment(\.dismiss) var dismiss
    @State private var quickCaptureFolderId: String?

    var body: some View {
        Form {
            Section("Quick Capture") {
                Picker("Quick Capture Folder", selection: $quickCaptureFolderId) {
                    Text("None").tag(String?.none)
                    ForEach(folderItems, id: \.id) { folder in
                        Text(folder.title ?? "Untitled").tag(String?.some(folder.id))
                    }
                }
                .onChange(of: quickCaptureFolderId) { oldValue, newValue in
                    saveQuickCaptureFolder(newValue)
                }
            }

            Section("Tree") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Font Size: \(Int(settings.fontSize))")
                    Slider(value: $settings.fontSize, in: 8...48, step: 1)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Horizontal Margin: \(Int(settings.horizontalMargin))")
                    Slider(value: $settings.horizontalMargin, in: 0...32, step: 1)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Vertical Margin: \(Int(settings.verticalMargin))")
                    Slider(value: $settings.verticalMargin, in: 0...16, step: 1)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Line Spacing: \(Int(settings.lineSpacing))")
                    Slider(value: $settings.lineSpacing, in: 0...16, step: 1)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 400)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            loadQuickCaptureFolder()
        }
    }

    private var folderItems: [Item] {
        store.items.filter { $0.itemType == .folder }
    }

    private func loadQuickCaptureFolder() {
        let repository = ItemRepository()
        quickCaptureFolderId = try? repository.getSetting(key: "quick_capture_folder_id")
    }

    private func saveQuickCaptureFolder(_ folderId: String?) {
        let repository = ItemRepository()
        try? repository.setSetting(key: "quick_capture_folder_id", value: folderId)
    }
}

#Preview {
    let settings = UserSettings()
    SettingsView(settings: settings, store: ItemStore(settings: settings))
}
