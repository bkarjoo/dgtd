import Foundation
import GRDB

// MARK: - DatabaseProvider Protocol
public protocol DatabaseProvider {
    func getQueue() -> DatabaseQueue?
}

// MARK: - Database Implementation
open class Database: DatabaseProvider {
    public static let shared = Database()

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

    public init() {}

    private func setupDatabase(on queue: DatabaseQueue) throws {
        NSLog("Database: Starting migration setup")

        // Create and configure the migrator
        var migrator = DatabaseMigrator()

        // Register v1 migration (baseline schema)
        migrator.registerMigration("v1") { db in
            NSLog("Database: Running migration v1 (baseline schema)")

            guard let schemaURL = Bundle.main.url(forResource: "schema", withExtension: "sql") else {
                NSLog("Database: ERROR - schema.sql not found in bundle")
                throw DatabaseError.schemaNotFound
            }

            let schema = try String(contentsOf: schemaURL, encoding: .utf8)
            NSLog("Database: Schema loaded, length: \(schema.count) characters")

            try db.execute(sql: schema)
            NSLog("Database: Migration v1 completed successfully")
        }

        // Register v2 migration (add item_type column)
        migrator.registerMigration("v2") { db in
            NSLog("Database: Running migration v2 (add item_type column)")

            // Check if column already exists (for databases created from updated schema.sql)
            let columnExists = try db.columns(in: "items").contains { $0.name == "item_type" }

            if !columnExists {
                try db.execute(sql: """
                    ALTER TABLE items ADD COLUMN item_type TEXT DEFAULT 'Unknown'
                """)
                NSLog("Database: Added item_type column")
            } else {
                NSLog("Database: item_type column already exists, skipping")
            }

            NSLog("Database: Migration v2 completed successfully")
        }

        // Register v3 migration (add app_settings table)
        migrator.registerMigration("v3") { db in
            NSLog("Database: Running migration v3 (add app_settings table)")

            // Check if table already exists (for databases created from updated schema.sql)
            let tableExists = try db.tableExists("app_settings")

            if !tableExists {
                try db.execute(sql: """
                    CREATE TABLE app_settings (
                        key TEXT PRIMARY KEY,
                        value TEXT
                    )
                """)
                NSLog("Database: Created app_settings table")
            } else {
                NSLog("Database: app_settings table already exists, skipping")
            }

            NSLog("Database: Migration v3 completed successfully")
        }

        // Register v4 migration (add notes column)
        migrator.registerMigration("v4") { db in
            NSLog("Database: Running migration v4 (add notes column)")

            // Check if column already exists (for databases created from updated schema.sql)
            let columnExists = try db.columns(in: "items").contains { $0.name == "notes" }

            if !columnExists {
                try db.execute(sql: """
                    ALTER TABLE items ADD COLUMN notes TEXT
                """)
                NSLog("Database: Added notes column")
            } else {
                NSLog("Database: notes column already exists, skipping")
            }

            NSLog("Database: Migration v4 completed successfully")
        }

        // Register v5 migration (add saved_searches table)
        migrator.registerMigration("v5") { db in
            NSLog("Database: Running migration v5 (add saved_searches table)")

            // Check if table already exists (for databases created from updated schema.sql)
            let tableExists = try db.tableExists("saved_searches")

            if !tableExists {
                try db.execute(sql: """
                    CREATE TABLE saved_searches (
                        id TEXT PRIMARY KEY,
                        name TEXT NOT NULL,
                        sql TEXT NOT NULL,
                        sort_order INTEGER DEFAULT 0,
                        created_at INTEGER NOT NULL,
                        modified_at INTEGER NOT NULL
                    )
                """)
                NSLog("Database: Created saved_searches table")
            } else {
                NSLog("Database: saved_searches table already exists, skipping")
            }

            NSLog("Database: Migration v5 completed successfully")
        }

        // Handle backward compatibility: Detect legacy databases and reset them
        try queue.write { db in
            // State Detection Step 1: Check if grdb_migrations table exists
            let hasMigrationMetadata = try db.tableExists("grdb_migrations")
            NSLog("Database: Migration metadata exists: \(hasMigrationMetadata)")

            if !hasMigrationMetadata {
                // State Detection Step 2: Check if any legacy tables exist
                let requiredTables = ["folders", "items", "tags", "notes", "item_tags"]
                var existingTables: [String] = []

                for tableName in requiredTables {
                    let exists = try db.tableExists(tableName)
                    if exists {
                        existingTables.append(tableName)
                    }
                }

                if !existingTables.isEmpty {
                    // Legacy database detected: Drop all tables for clean transition
                    NSLog("Database: Legacy database detected with tables: \(existingTables.joined(separator: ", "))")
                    NSLog("Database: Performing one-time reset for migration system transition")

                    // Disable foreign keys temporarily
                    try db.execute(sql: "PRAGMA foreign_keys = OFF")
                    NSLog("Database: Disabled foreign keys for table dropping")

                    // Drop tables in reverse dependency order
                    let dropOrder = ["item_tags", "notes", "tags", "items", "folders"]
                    for tableName in dropOrder {
                        if existingTables.contains(tableName) {
                            do {
                                try db.execute(sql: "DROP TABLE IF EXISTS \(tableName)")
                                NSLog("Database: Dropped legacy table '\(tableName)'")
                            } catch {
                                NSLog("Database: WARNING - Failed to drop table '\(tableName)': \(error)")
                            }
                        }
                    }

                    // Drop triggers if they exist
                    let triggers = ["prevent_folder_circular_reference", "prevent_folder_circular_reference_insert"]
                    for triggerName in triggers {
                        do {
                            try db.execute(sql: "DROP TRIGGER IF EXISTS \(triggerName)")
                            NSLog("Database: Dropped trigger '\(triggerName)'")
                        } catch {
                            NSLog("Database: WARNING - Failed to drop trigger '\(triggerName)': \(error)")
                        }
                    }

                    // Re-enable foreign keys
                    try db.execute(sql: "PRAGMA foreign_keys = ON")
                    NSLog("Database: Re-enabled foreign keys")
                    NSLog("Database: Legacy tables cleaned up successfully")
                } else {
                    NSLog("Database: Fresh install detected (no tables, no metadata)")
                }
            } else {
                NSLog("Database: Migrated database detected, using standard GRDB migration logic")
            }
        }

        // Apply all pending migrations
        NSLog("Database: Applying pending migrations...")
        do {
            try migrator.migrate(queue)
            NSLog("Database: Migration system completed successfully")

            // Log applied migrations for debugging
            try queue.read { db in
                let appliedMigrations = try migrator.appliedIdentifiers(db)
                NSLog("Database: Applied migrations: \(appliedMigrations.joined(separator: ", "))")
            }
        } catch {
            NSLog("Database: FATAL ERROR - Migration failed: \(error)")
            throw error
        }
    }

    // Error types for better error handling
    enum DatabaseError: Error {
        case queueNotInitialized
        case schemaNotFound
    }

    open func getQueue() -> DatabaseQueue? {
        return dbQueue
    }
}
