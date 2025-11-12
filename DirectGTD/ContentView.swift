//
//  ContentView.swift
//  DirectGTD
//
//  Created by Behrooz Karjoo on 11/11/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            FolderTreeView()
        } detail: {
            VStack {
                Image(systemName: "tray")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary)
                Text("Select a folder")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
}
