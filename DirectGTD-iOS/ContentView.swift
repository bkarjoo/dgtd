//
//  ContentView.swift
//  DirectGTD-iOS
//
//  Created by Behrooz Karjoo on 12/9/25.
//

import SwiftUI
import DirectGTDCore
import UIKit

// MARK: - SearchTextField (UIKit wrapper for suggestion-free keyboard)

struct SearchTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onCommit: () -> Void = {}
    @Binding var isFirstResponder: Bool

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.autocapitalizationType = .none
        textField.smartQuotesType = .no
        textField.smartDashesType = .no
        textField.smartInsertDeleteType = .no
        textField.returnKeyType = .search
        textField.clearButtonMode = .never
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        // Handle focus changes
        if isFirstResponder && !uiView.isFirstResponder {
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        } else if !isFirstResponder && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SearchTextField

        init(_ parent: SearchTextField) {
            self.parent = parent
        }

        @objc func textChanged(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onCommit()
            return true
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            DispatchQueue.main.async {
                self.parent.isFirstResponder = true
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            DispatchQueue.main.async {
                self.parent.isFirstResponder = false
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = TreeViewModel()
    @State private var isSearchMode = false
    @State private var searchText = ""
    @State private var showingSettings = false
    @State private var showingQuickCapture = false
    @State private var isSearchFieldFocused = false
    @Environment(\.scenePhase) private var scenePhase

    /// Search results - filter items by title and notes
    private var searchResults: [Item] {
        guard !searchText.isEmpty else { return [] }
        return viewModel.items.filter { item in
            (item.title ?? "").localizedCaseInsensitiveContains(searchText) ||
            (item.notes ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Whether to show the search results overlay
    private var shouldShowSearchResults: Bool {
        isSearchMode && !searchText.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar - hidden in search mode
            if !isSearchMode {
                headerBar
            }

            // Main content area with overlay
            ZStack {
                // Tree view (always present, may be covered by search results)
                TreeView()
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 30, coordinateSpace: .global)
                            .onEnded { value in
                                if value.translation.width > 80 &&
                                   abs(value.translation.height) < 50 &&
                                   viewModel.isFocused {
                                    viewModel.goToParent()
                                }
                            }
                    )

                // Search results overlay - covers tree when there's search text
                if shouldShowSearchResults {
                    searchResultsOverlay
                }

                // Floating action button - hidden in search mode
                if !isSearchMode {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                showingQuickCapture = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Color.accentColor)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 16)
                        }
                    }
                }
            }

            // Search bar at bottom when in search mode - OUTSIDE the ZStack so it's never covered
            if isSearchMode {
                searchBar
            }
        }
        .environmentObject(viewModel)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showingQuickCapture) {
            QuickCaptureView()
                .environmentObject(viewModel)
        }
        .task {
            await viewModel.syncAndReload()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                let application = UIApplication.shared
                var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

                backgroundTaskID = application.beginBackgroundTask(withName: "DirectGTD Sync") {
                    if backgroundTaskID != .invalid {
                        application.endBackgroundTask(backgroundTaskID)
                        backgroundTaskID = .invalid
                    }
                }

                Task {
                    await viewModel.syncAndReload()
                    if backgroundTaskID != .invalid {
                        application.endBackgroundTask(backgroundTaskID)
                    }
                }
            case .active:
                Task {
                    await viewModel.syncAndReload()
                }
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .onChange(of: isSearchFieldFocused) { _, focused in
            // When keyboard is dismissed, exit search mode
            if !focused && isSearchMode {
                exitSearchMode()
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            // Back button (only when focused)
            if viewModel.isFocused {
                Button {
                    viewModel.goToParent()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        if let parentTitle = viewModel.focusedItemParentTitle {
                            Text(parentTitle)
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Right side buttons
            HStack(spacing: 16) {
                Button {
                    enterSearchMode()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.plain)

                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                SearchTextField(
                    text: $searchText,
                    placeholder: "Search items...",
                    isFirstResponder: $isSearchFieldFocused
                )
                .frame(height: 20)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)

            Button("Cancel") {
                exitSearchMode()
            }
            .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - Search Results Overlay

    private var searchResultsOverlay: some View {
        Group {
            if searchResults.isEmpty {
                VStack {
                    Spacer()
                    Text("No results for \"\(searchText)\"")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(searchResults, id: \.id) { item in
                            SearchResultRow(item: item, viewModel: viewModel)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectAndFocusItem(item)
                                }
                            Divider()
                                .padding(.leading)
                        }
                    }
                }
                .background(Color(.systemBackground))
            }
        }
    }

    // MARK: - Search Actions

    private func enterSearchMode() {
        isSearchMode = true
        isSearchFieldFocused = true
    }

    private func exitSearchMode() {
        isSearchMode = false
        searchText = ""
        isSearchFieldFocused = false
    }

    private func selectAndFocusItem(_ item: Item) {
        // Expand all ancestors
        var currentId: String? = item.parentId
        while let parentId = currentId {
            viewModel.expandedItemIds.insert(parentId)
            if let parent = viewModel.items.first(where: { $0.id == parentId }) {
                currentId = parent.parentId
            } else {
                break
            }
        }

        // Focus on the item (so it becomes the root of the view)
        viewModel.focusedItemId = item.id

        // Select it
        viewModel.selectedItemId = item.id

        // Exit search mode
        exitSearchMode()
    }
}

#Preview {
    ContentView()
}
