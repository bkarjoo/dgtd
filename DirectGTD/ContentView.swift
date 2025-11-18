//
//  ContentView.swift
//  DirectGTD
//
//  Created by Behrooz Karjoo on 11/11/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = ItemStore()
    @State private var showingAddItem = false
    @State private var newItemName = ""

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Spacer()
                Button(action: { showingAddItem = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .padding()
            }
            .border(Color.red)

            // Tree view
            TreeView(store: store)
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
    }

    private func addItem() {
        store.createItem(title: newItemName)
        newItemName = ""
    }
}

#Preview {
    ContentView()
}
