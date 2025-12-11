import DirectGTDCore
import SwiftUI

struct SQLSearchResultsView: View {
    @ObservedObject var store: ItemStore

    var body: some View {
        VStack(spacing: 0) {
            // Header showing active query info
            HStack {
                Image(systemName: "magnifyingglass.circle.fill")
                    .foregroundColor(.accentColor)
                Text("SQL Search Active")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    store.clearSQLSearch()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear SQL Search")
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Results list
            if store.sqlSearchResults.isEmpty {
                VStack {
                    Spacer()
                    Text("No results")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(resultsItems, id: \.id) { item in
                            HStack {
                                Image(systemName: item.itemType.defaultIcon)
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)

                                Text(item.title ?? "Untitled")
                                    .lineLimit(1)

                                Spacer()

                                if item.completedAt != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(store.selectedItemId == item.id ? Color.accentColor.opacity(0.2) : Color.clear)
                            .cornerRadius(4)
                            .onTapGesture {
                                store.selectedItemId = item.id
                            }
                        }
                    }
                    .padding(8)
                }
            }
        }
    }

    private var resultsItems: [Item] {
        // Iterate over sqlSearchResults to preserve SQL ORDER BY clause
        store.sqlSearchResults.compactMap { id in
            store.items.first { $0.id == id }
        }
    }
}

#Preview {
    let settings = UserSettings()
    let store = ItemStore(settings: settings)
    store.sqlSearchActive = true
    store.sqlSearchResults = []
    return SQLSearchResultsView(store: store)
}
