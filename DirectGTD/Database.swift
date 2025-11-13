import Foundation
import GRDB

class Database {
    static let shared = Database()

    private var dbQueue: DatabaseQueue?

    private init() {
        do {
            let fileManager = FileManager.default
            let documentsPath = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dbPath = documentsPath.appendingPathComponent("directgtd.sqlite").path

            NSLog("Database: Initializing at path: \(dbPath)")

            dbQueue = try DatabaseQueue(path: dbPath)
            NSLog("Database: DatabaseQueue created successfully")
            try setupDatabase()
            NSLog("Database: Setup completed successfully")
        } catch {
            NSLog("Database: FATAL ERROR - \(error)")
            fatalError("Failed to initialize database: \(error)")
        }
    }

    private func setupDatabase() throws {
        guard let dbQueue = dbQueue else {
            NSLog("Database: ERROR - DatabaseQueue is nil")
            throw DatabaseError.queueNotInitialized
        }

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

        // Handle backward compatibility: Detect legacy databases and reset them
        try dbQueue.write { db in
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
            try migrator.migrate(dbQueue)
            NSLog("Database: Migration system completed successfully")

            // Log applied migrations for debugging
            try dbQueue.read { db in
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

    func getQueue() -> DatabaseQueue? {
        return dbQueue
    }
}
