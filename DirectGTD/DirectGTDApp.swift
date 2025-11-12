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

        // Seed database with sample data (only on first launch)
        let seeder = DatabaseSeeder()
        try? seeder.seed()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
