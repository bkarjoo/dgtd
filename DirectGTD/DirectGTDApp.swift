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
        print("DirectGTDApp: Database initialized")

        // Seed database with sample data (only on first launch)
        let seeder = DatabaseSeeder()
        do {
            try seeder.seed()
            print("DirectGTDApp: Seeding completed")
        } catch {
            print("DirectGTDApp: Seeding error: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
