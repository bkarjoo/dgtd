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
        guard let schemaURL = Bundle.main.url(forResource: "schema", withExtension: "sql") else {
            NSLog("Database: ERROR - schema.sql not found in bundle")
            fatalError("schema.sql not found in bundle")
        }

        NSLog("Database: Found schema at: \(schemaURL.path)")

        let schema = try String(contentsOf: schemaURL, encoding: .utf8)
        NSLog("Database: Schema loaded, length: \(schema.count) characters")

        try dbQueue?.write { db in
            // Check if ALL required tables exist
            let requiredTables = ["folders", "items", "tags", "notes", "item_tags"]
            var missingTables: [String] = []
            var existingTables: [String] = []

            for tableName in requiredTables {
                let exists = try db.tableExists(tableName)
                if exists {
                    existingTables.append(tableName)
                } else {
                    missingTables.append(tableName)
                }
                NSLog("Database: Table '\(tableName)' exists: \(exists)")
            }

            // If any tables are missing, we need to migrate
            if !missingTables.isEmpty {
                NSLog("Database: Migration needed - missing tables: \(missingTables.joined(separator: ", "))")

                // Drop all existing tables to ensure clean slate
                // Drop in reverse order to handle foreign keys properly
                if !existingTables.isEmpty {
                    NSLog("Database: Dropping existing tables: \(existingTables.joined(separator: ", "))")

                    // Disable foreign keys temporarily to allow dropping tables
                    try db.execute(sql: "PRAGMA foreign_keys = OFF")
                    NSLog("Database: Disabled foreign keys for migration")

                    // Drop tables in reverse order (dependencies first)
                    let dropOrder = ["item_tags", "notes", "tags", "items", "folders"]
                    for tableName in dropOrder {
                        if existingTables.contains(tableName) {
                            do {
                                try db.execute(sql: "DROP TABLE IF EXISTS \(tableName)")
                                NSLog("Database: Dropped table '\(tableName)'")
                            } catch {
                                NSLog("Database: WARNING - Failed to drop table '\(tableName)': \(error)")
                            }
                        }
                    }

                    // Re-enable foreign keys
                    try db.execute(sql: "PRAGMA foreign_keys = ON")
                    NSLog("Database: Re-enabled foreign keys")
                }

                // Execute the full schema to create all tables
                NSLog("Database: Creating fresh schema...")
                do {
                    try db.execute(sql: schema)
                    NSLog("Database: Schema created successfully")
                } catch {
                    NSLog("Database: FATAL ERROR - Schema creation failed: \(error)")
                    throw error
                }
            } else {
                NSLog("Database: All required tables exist, no migration needed")
            }
        }
    }

    func getQueue() -> DatabaseQueue? {
        return dbQueue
    }
}
