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
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Text("Search results will appear here")
                .font(.title2)
                .foregroundStyle(.secondary)
                .navigationTitle("Search")
                .searchable(text: $searchText, prompt: "Search items...")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

#Preview {
    SearchView()
}
