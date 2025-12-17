import DirectGTDCore
//
//  DirectGTDApp.swift
//  DirectGTD
//
//  Created by Behrooz Karjoo on 11/11/25.
//

import SwiftUI

@main
struct DirectGTDApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var syncEngine: SyncEngine
    @StateObject private var settings = UserSettings()
    @StateObject private var store: ItemStore
    private var apiServer: APIServer?

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

        // Create shared settings and store
        let sharedSettings = UserSettings()
        let sharedStore = ItemStore(settings: sharedSettings)
        _settings = StateObject(wrappedValue: sharedSettings)
        _store = StateObject(wrappedValue: sharedStore)

        // Create sync engine with CloudKit manager and database
        _syncEngine = StateObject(wrappedValue: SyncEngine(
            cloudKitManager: CloudKitManager.shared,
            database: Database.shared
        ))

        // Start API server
        let server = APIServer(itemStore: sharedStore, port: 9876)
        do {
            try server.start()
            NSLog("DirectGTDApp: API server started on port 9876")
        } catch {
            NSLog("DirectGTDApp: Failed to start API server - \(error)")
        }
        apiServer = server
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store, settings: settings, syncEngine: syncEngine)
                .onAppear {
                    // Wire up the sync engine to the app delegate for remote notifications
                    appDelegate.syncEngine = syncEngine

                    // Start the sync engine
                    Task {
                        await syncEngine.start()
                    }
                }
        }
    }
}
