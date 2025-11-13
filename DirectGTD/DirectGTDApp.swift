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
        NSLog("DirectGTDApp: Program started")
        // Initialize database on app launch
        _ = Database.shared
        NSLog("DirectGTDApp: Database initialized")

        // Seed database with sample data (only on first launch)
        let seeder = DatabaseSeeder()
        do {
            try seeder.seed()
            NSLog("DirectGTDApp: Seeding completed")
        } catch {
            NSLog("DirectGTDApp: Seeding error: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
