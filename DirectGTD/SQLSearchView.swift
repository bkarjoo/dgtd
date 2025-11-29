import SwiftUI
import AppKit

// Custom TextEditor that disables smart quotes
struct PlainTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        // Disable smart quotes and other automatic substitutions
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        // Set monospaced font
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

        textView.delegate = context.coordinator
        textView.string = text

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PlainTextEditor

        init(_ parent: PlainTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

struct SQLSearchView: View {
    @ObservedObject var store: ItemStore
    @Environment(\.dismiss) var dismiss
    @State private var queryText: String = ""
    @State private var errorMessage: String?
    @State private var showingSaveDialog: Bool = false
    @State private var searchName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SQL Search")
                    .font(.headline)
                Spacer()
                Button("Close") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            // SQL Editor
            VStack(alignment: .leading, spacing: 8) {
                Text("SQL Query")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                PlainTextEditor(text: $queryText)
                    .frame(height: 120)
                    .border(Color.gray.opacity(0.3))

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 4)
                }
            }
            .padding()

            // Buttons
            HStack {
                Button("Run") {
                    runQuery()
                }
                .keyboardShortcut(.return, modifiers: .command)

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("Clear") {
                    clearSearch()
                }

                Spacer()

                Button("Save Search...") {
                    showingSaveDialog = true
                }
                .disabled(queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            // Saved Searches
            VStack(alignment: .leading, spacing: 8) {
                Text("Saved Searches")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 8)

                if store.savedSearches.isEmpty {
                    Text("No saved searches")
                        .foregroundColor(.secondary)
                        .italic()
                        .padding()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(store.savedSearches) { search in
                                Button(action: {
                                    loadSavedSearch(search)
                                }) {
                                    HStack {
                                        Image(systemName: "magnifyingglass")
                                            .font(.caption)
                                        Text(search.name)
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                }
                                .buttonStyle(.plain)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(4)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxHeight: 150)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: 600, height: 500)
        .onAppear {
            queryText = store.sqlSearchQuery
            store.loadSavedSearches()
        }
        .alert("Save Search", isPresented: $showingSaveDialog) {
            TextField("Search name", text: $searchName)
            Button("Cancel", role: .cancel) {
                searchName = ""
            }
            Button("Save") {
                saveSearch()
            }
        } message: {
            Text("Enter a name for this search")
        }
    }

    private func runQuery() {
        errorMessage = nil
        let trimmedQuery = queryText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            errorMessage = "Query cannot be empty"
            return
        }

        // Execute query asynchronously (runs off main thread with timeout)
        Task {
            do {
                try await store.executeSQLSearch(query: trimmedQuery)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func clearSearch() {
        store.clearSQLSearch()
        dismiss()
    }

    private func loadSavedSearch(_ search: SavedSearch) {
        queryText = search.sql
        errorMessage = nil
    }

    private func saveSearch() {
        let trimmedQuery = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = searchName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else { return }

        do {
            try store.saveSQLSearch(name: trimmedName, sql: trimmedQuery)
            searchName = ""
            // Run the query after saving
            runQuery()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    let settings = UserSettings()
    SQLSearchView(store: ItemStore(settings: settings))
}
