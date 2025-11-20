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
    @State private var showingAddItem = false
    @State private var newItemName = ""
    @State private var showingSettings = false
    @Environment(\.undoManager) var undoManager

    init() {
        let settings = UserSettings()
        _settings = StateObject(wrappedValue: settings)
        _store = StateObject(wrappedValue: ItemStore(settings: settings))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
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

                Button(action: { showingAddItem = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .padding()
            }

            // Split view: Tree on left, Detail on right (or Search)
            HSplitView {
                if store.isSearching {
                    SearchResultsView(store: store)
                        .frame(minWidth: 200, idealWidth: 300, maxWidth: .infinity)
                } else {
                    TreeView(store: store, settings: settings)
                        .frame(minWidth: 200, idealWidth: 300, maxWidth: .infinity)
                }

                DetailView(store: store)
                    .frame(minWidth: 300, idealWidth: 500, maxWidth: .infinity)
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
            SettingsView(settings: settings, store: store)
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
            if keyPress.key == KeyEquivalent("f") && keyPress.modifiers.contains(.command) {
                store.isSearching.toggle()
                if !store.isSearching {
                    store.searchText = ""
                }
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
    ContentView()
}
