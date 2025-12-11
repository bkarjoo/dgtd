//
//  SearchView.swift
//  DirectGTD-iOS
//
//  Created by Behrooz Karjoo on 12/9/25.
//

import SwiftUI
import DirectGTDCore

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: TreeViewModel
    @State private var searchText = ""
    @State private var hasTypedSearchText = false
    @FocusState private var isSearchFocused: Bool

    /// Filter viewModel.items by search text (same approach as macOS ItemStore)
    private var searchResults: [Item] {
        guard !searchText.isEmpty else { return [] }
        return viewModel.items.filter { item in
            (item.title ?? "").localizedCaseInsensitiveContains(searchText) ||
            (item.notes ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    ContentUnavailableView(
                        "Search Items",
                        systemImage: "magnifyingglass",
                        description: Text("Type to search titles and notes")
                    )
                } else if searchResults.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("No items match \"\(searchText)\"")
                    )
                } else {
                    ForEach(searchResults, id: \.id) { item in
                        SearchResultRow(item: item, viewModel: viewModel)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectAndJumpToItem(item)
                            }
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search items...")
            .searchFocused($isSearchFocused)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                isSearchFocused = true
            }
            .onChange(of: searchText) { _, newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    if hasTypedSearchText {
                        hasTypedSearchText = false
                        dismiss()
                    }
                } else {
                    hasTypedSearchText = true
                }
            }
        }
    }

    private func selectAndJumpToItem(_ item: Item) {
        // Expand all ancestors so item is visible in tree
        expandAncestors(of: item)

        // Focus on the item's parent (or unfocus if at root)
        viewModel.focusedItemId = item.parentId

        // Select the item
        viewModel.selectedItemId = item.id

        // Close search
        dismiss()
    }

    private func expandAncestors(of item: Item) {
        var currentId: String? = item.parentId

        while let parentId = currentId {
            viewModel.expandedItemIds.insert(parentId)
            if let parent = viewModel.items.first(where: { $0.id == parentId }) {
                currentId = parent.parentId
            } else {
                break
            }
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let item: Item
    let viewModel: TreeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // Item type icon
                itemIcon
                    .foregroundStyle(iconColor)

                // Title with completion strikethrough
                Text(item.title ?? "Untitled")
                    .strikethrough(item.completedAt != nil)
                    .foregroundStyle(item.completedAt != nil ? .secondary : .primary)
            }

            // Breadcrumb path
            if !breadcrumb.isEmpty {
                Text(breadcrumb)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var breadcrumb: String {
        var path: [String] = []
        var currentId: String? = item.parentId

        while let parentId = currentId {
            if let parent = viewModel.items.first(where: { $0.id == parentId }) {
                path.insert(parent.title ?? "Untitled", at: 0)
                currentId = parent.parentId
            } else {
                break
            }
        }

        return path.joined(separator: " > ")
    }

    private var itemIcon: some View {
        Group {
            switch item.itemType {
            case .task:
                if item.completedAt != nil {
                    Image(systemName: "checkmark.circle.fill")
                } else {
                    Image(systemName: "circle")
                }
            case .project:
                Image(systemName: "folder")
            case .folder:
                Image(systemName: "folder.fill")
            case .note:
                Image(systemName: "doc.text")
            default:
                Image(systemName: "doc")
            }
        }
    }

    private var iconColor: Color {
        switch item.itemType {
        case .task:
            return item.completedAt != nil ? .green : .blue
        case .project:
            return .purple
        case .folder:
            return .orange
        case .note:
            return .gray
        default:
            return .secondary
        }
    }
}

#Preview {
    SearchView()
}
