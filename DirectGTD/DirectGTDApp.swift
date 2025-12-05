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

        // Disable automatic window tabbing
        NSWindow.allowsAutomaticWindowTabbing = false

        // Initialize database on app launch
        _ = Database.shared
        NSLog("DirectGTDApp: Database initialized")

        // Start automatic backups (checks on launch + 24-hour timer)
        BackupService.shared.startAutomaticBackups()
        NSLog("DirectGTDApp: Backup service started")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
