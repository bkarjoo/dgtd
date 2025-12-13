import DirectGTDCore
//
//  ContentView.swift
//  DirectGTD
//
//  Created by Behrooz Karjoo on 11/11/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var settings = UserSettings()
    @StateObject private var store: ItemStore
    @ObservedObject var syncEngine: SyncEngine
    @State private var showingAddItem = false
    @State private var newItemName = ""
    @State private var showingSettings = false
    @State private var showingTagFilter = false
    @State private var showingSQLSearch = false
    @State private var showingHelp = false
    @State private var rightPaneView: RightPaneView
    @Environment(\.undoManager) var undoManager

    init(syncEngine: SyncEngine) {
        self.syncEngine = syncEngine
        let settings = UserSettings()
        _settings = StateObject(wrappedValue: settings)
        _store = StateObject(wrappedValue: ItemStore(settings: settings))
        _rightPaneView = State(initialValue: settings.rightPaneView)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                // Back button (only when focused)
                if store.isFocused {
                    Button {
                        store.goToParent()
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding()
                }

                Button(action: { showingSettings = true }) {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)
                .padding()

                Button(action: { settings.showCompletedTasks.toggle() }) {
                    Image(systemName: settings.showCompletedTasks ? "eye.fill" : "eye.slash.fill")
                }
                .buttonStyle(.plain)
                .padding()

                Button(action: { showingTagFilter = true }) {
                    Image(systemName: store.filteredByTag != nil ? "tag.fill" : "tag")
                        .foregroundColor(store.filteredByTag != nil ? .accentColor : .primary)
                }
                .buttonStyle(.plain)
                .padding()
                .popover(isPresented: $showingTagFilter, arrowEdge: .bottom) {
                    TagFilterPickerView(store: store, onDismiss: { showingTagFilter = false })
                }

                Button(action: {
                    showingSQLSearch = true
                }) {
                    Image(systemName: "magnifyingglass")
                        .symbolVariant(store.sqlSearchActive ? .circle.fill : .none)
                        .foregroundColor(store.sqlSearchActive ? .accentColor : .primary)
                }
                .buttonStyle(.plain)
                .padding()
                .help("SQL Search")

                Button(action: {
                    if store.focusedItemId != nil {
                        store.focusedItemId = nil
                    } else if let selectedId = store.selectedItemId {
                        store.focusedItemId = selectedId
                    }
                }) {
                    Image(systemName: "scope")
                        .symbolVariant(store.focusedItemId != nil ? .circle.fill : .none)
                        .foregroundColor(store.focusedItemId != nil ? .accentColor : .primary)
                }
                .buttonStyle(.plain)
                .padding()
                .disabled(store.focusedItemId == nil && store.selectedItemId == nil)
                .help("Focus Mode")

                Button(action: {
                    rightPaneView = rightPaneView == .detail ? .noteEditor : .detail
                    settings.rightPaneView = rightPaneView
                }) {
                    Image(systemName: rightPaneView == .noteEditor ? "doc.text.fill" : "doc.text")
                        .foregroundColor(rightPaneView == .noteEditor ? .accentColor : .primary)
                }
                .buttonStyle(.plain)
                .padding()

                SyncMenuButton(syncEngine: syncEngine)
                    .buttonStyle(.plain)
                    .padding()

                Button(action: { undoManager?.undo() }) {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(.plain)
                .padding()
                .disabled(!(undoManager?.canUndo ?? false))

                Button(action: { undoManager?.redo() }) {
                    Image(systemName: "arrow.uturn.forward")
                }
                .buttonStyle(.plain)
                .padding()
                .disabled(!(undoManager?.canRedo ?? false))

                Spacer()

                Button(action: { showingHelp = true }) {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.plain)
                .padding()
                .help("Help (Cmd+/)")

                Button(action: { showingAddItem = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .padding()
            }

            // Split view: Tree on left, Detail on right (or Search Results)
            HSplitView {
                if store.isSearching {
                    SearchResultsView(store: store)
                        .frame(minWidth: 200, idealWidth: 300, maxWidth: .infinity)
                } else {
                    TreeView(store: store, settings: settings)
                        .frame(minWidth: 200, idealWidth: 300, maxWidth: .infinity)
                }

                if rightPaneView == .detail {
                    DetailView(store: store)
                        .frame(minWidth: 300, idealWidth: 500, maxWidth: .infinity)
                } else {
                    NoteEditorView(store: store)
                    .frame(minWidth: 300, idealWidth: 500, maxWidth: .infinity)
                }
            }
        }
        .overlay {
            // Show initial sync progress overlay during first-time sync
            if !syncEngine.isInitialSyncComplete {
                InitialSyncProgressView(syncEngine: syncEngine)
            }
        }
        .alert("New Item", isPresented: $showingAddItem) {
            TextField("Enter name", text: $newItemName)
            Button("Cancel", role: .cancel) {
                newItemName = ""
            }
            Button("Add") {
                addItem()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(settings: settings, store: store, syncEngine: syncEngine)
        }
        .sheet(isPresented: $showingSQLSearch) {
            SQLSearchView(store: store)
        }
        .sheet(isPresented: $showingHelp) {
            if store.noteEditorIsInEditMode {
                MarkdownHelpView()
            } else {
                HelpView()
            }
        }
        .alert("Error", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                store.errorMessage = nil
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .onAppear {
            store.undoManager = undoManager
        }
        .onKeyPress { keyPress in
            if keyPress.key == KeyEquivalent("e") && keyPress.modifiers.contains(.command) {
                // Cmd+E: Switch to note editor and enter edit mode
                if rightPaneView != .noteEditor {
                    rightPaneView = .noteEditor
                    settings.rightPaneView = rightPaneView
                }
                store.requestNoteEditorToggleEditMode()
                return .handled
            }
            if keyPress.key == KeyEquivalent("/") && keyPress.modifiers.contains(.command) {
                showingHelp = true
                return .handled
            }
            if keyPress.key == KeyEquivalent("f") && keyPress.modifiers.contains(.command) {
                // Cmd+Shift+F: Toggle focus mode
                if keyPress.modifiers.contains(.shift) {
                    if store.focusedItemId != nil {
                        store.focusedItemId = nil
                    } else if let selectedId = store.selectedItemId {
                        store.focusedItemId = selectedId
                    }
                    return .handled
                }
                // Cmd+F: Toggle search
                store.isSearching.toggle()
                if !store.isSearching {
                    store.searchText = ""
                }
                return .handled
            }
            if keyPress.key == KeyEquivalent("r") && keyPress.modifiers.contains(.command) {
                store.loadItems()
                return .handled
            }
            return .ignored
        }
    }

    private func addItem() {
        store.createItem(title: newItemName)
        newItemName = ""
    }
}

#Preview {
    ContentView(syncEngine: SyncEngine())
}
