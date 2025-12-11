//
//  Database.swift
//  DirectGTD-iOS
//
//  Created by Behrooz Karjoo on 12/9/25.
//

import DirectGTDCore
import Foundation
import GRDB

/// iOS Database implementation using GRDB
class Database: DatabaseProvider, @unchecked Sendable {
    static let shared = Database()

    private lazy var dbQueue: DatabaseQueue? = {
        do {
            let fileManager = FileManager.default
            let appSupportPath = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let appFolder = appSupportPath.appendingPathComponent("DirectGTD")
            try fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
            let dbPath = appFolder.appendingPathComponent("directgtd.sqlite").path

            NSLog("Database: Initializing at path: \(dbPath)")

            let queue = try DatabaseQueue(path: dbPath)
            NSLog("Database: DatabaseQueue created successfully")
            try setupDatabase(on: queue)
            NSLog("Database: Setup completed successfully")
            return queue
        } catch {
            NSLog("Database: FATAL ERROR - \(error)")
            fatalError("Failed to initialize database: \(error)")
        }
    }()

    init() {}

    private func setupDatabase(on queue: DatabaseQueue) throws {
        NSLog("Database: Starting migration setup")

        var migrator = DatabaseMigrator()

        // v1: Base schema for iOS (simplified - no schema.sql file needed)
        migrator.registerMigration("v1") { db in
            NSLog("Database: Running migration v1 (base schema)")

            // Items table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS items (
                    id TEXT PRIMARY KEY,
                    title TEXT,
                    item_type TEXT DEFAULT 'Unknown',
                    notes TEXT,
                    parent_id TEXT,
                    sort_order INTEGER DEFAULT 0,
                    created_at INTEGER NOT NULL,
                    modified_at INTEGER NOT NULL,
                    completed_at INTEGER,
                    due_date INTEGER,
                    earliest_start_time INTEGER,
                    ck_record_name TEXT,
                    ck_change_tag TEXT,
                    ck_system_fields BLOB,
                    needs_push INTEGER DEFAULT 0,
                    deleted_at INTEGER,
                    FOREIGN KEY (parent_id) REFERENCES items(id) ON DELETE NO ACTION
                )
            """)

            // Tags table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS tags (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL UNIQUE,
                    color TEXT,
                    created_at INTEGER,
                    modified_at INTEGER,
                    ck_record_name TEXT,
                    ck_change_tag TEXT,
                    ck_system_fields BLOB,
                    needs_push INTEGER DEFAULT 0,
                    deleted_at INTEGER
                )
            """)

            // Item-Tags junction table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS item_tags (
                    item_id TEXT NOT NULL,
                    tag_id TEXT NOT NULL,
                    created_at INTEGER,
                    modified_at INTEGER,
                    ck_record_name TEXT,
                    ck_change_tag TEXT,
                    ck_system_fields BLOB,
                    needs_push INTEGER DEFAULT 0,
                    deleted_at INTEGER,
                    PRIMARY KEY (item_id, tag_id),
                    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE NO ACTION,
                    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE NO ACTION
                )
            """)

            // Time entries table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS time_entries (
                    id TEXT PRIMARY KEY,
                    item_id TEXT NOT NULL,
                    started_at INTEGER NOT NULL,
                    ended_at INTEGER,
                    duration INTEGER,
                    modified_at INTEGER,
                    ck_record_name TEXT,
                    ck_change_tag TEXT,
                    ck_system_fields BLOB,
                    needs_push INTEGER DEFAULT 0,
                    deleted_at INTEGER,
                    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE NO ACTION
                )
            """)

            // Saved searches table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS saved_searches (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    sql TEXT NOT NULL,
                    sort_order INTEGER DEFAULT 0,
                    created_at INTEGER NOT NULL,
                    modified_at INTEGER NOT NULL,
                    ck_record_name TEXT,
                    ck_change_tag TEXT,
                    ck_system_fields BLOB,
                    needs_push INTEGER DEFAULT 0,
                    deleted_at INTEGER
                )
            """)

            // Sync metadata table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS sync_metadata (
                    key TEXT PRIMARY KEY,
                    value BLOB
                )
            """)

            // Indexes
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_parent_id ON items(parent_id)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_item_tags_item ON item_tags(item_id)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_item_tags_tag ON item_tags(tag_id)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_time_entries_item_id ON time_entries(item_id)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_items_ck_record_name ON items(ck_record_name) WHERE ck_record_name IS NOT NULL")

            NSLog("Database: Migration v1 completed")
        }

        // v2: Add app_settings table
        migrator.registerMigration("v2") { db in
            NSLog("Database: Running migration v2 (add app_settings table)")

            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS app_settings (
                    key TEXT PRIMARY KEY,
                    value TEXT
                )
            """)

            NSLog("Database: Migration v2 completed")
        }

        try migrator.migrate(queue)
        NSLog("Database: All migrations completed")
    }

    func getQueue() -> DatabaseQueue? {
        return dbQueue
    }
}
