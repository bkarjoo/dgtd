//
//  DirectGTDApp.swift
//  DirectGTD
//
//  Created by Behrooz Karjoo on 11/11/25.
//

import SwiftUI

@main
struct DirectGTDApp: App {
    init() {
        // Initialize database on app launch
        _ = Database.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
