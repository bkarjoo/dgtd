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

            print("Database: Initializing at path: \(dbPath)")

            dbQueue = try DatabaseQueue(path: dbPath)
            print("Database: DatabaseQueue created successfully")
            try setupDatabase()
            print("Database: Setup completed successfully")
        } catch {
            print("Database: FATAL ERROR - \(error)")
            fatalError("Failed to initialize database: \(error)")
        }
    }

    private func setupDatabase() throws {
        guard let schemaURL = Bundle.main.url(forResource: "schema", withExtension: "sql") else {
            print("Database: ERROR - schema.sql not found in bundle")
            fatalError("schema.sql not found in bundle")
        }

        print("Database: Found schema at: \(schemaURL.path)")

        let schema = try String(contentsOf: schemaURL, encoding: .utf8)
        print("Database: Schema loaded, length: \(schema.count) characters")

        try dbQueue?.write { db in
            // Check if tables already exist
            let tableExists = try db.tableExists("items")
            print("Database: Table 'items' exists: \(tableExists)")

            if !tableExists {
                // Execute the schema
                print("Database: Creating schema...")
                try db.execute(sql: schema)
                print("Database: Schema created successfully")
            } else {
                print("Database: Tables already exist, skipping schema creation")
            }
        }
    }

    func getQueue() -> DatabaseQueue? {
        return dbQueue
    }
}
