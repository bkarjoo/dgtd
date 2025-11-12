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

            dbQueue = try DatabaseQueue(path: dbPath)
            try setupDatabase()
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }

    private func setupDatabase() throws {
        guard let schemaURL = Bundle.main.url(forResource: "schema", withExtension: "sql") else {
            fatalError("schema.sql not found in bundle")
        }

        let schema = try String(contentsOf: schemaURL, encoding: .utf8)

        try dbQueue?.write { db in
            // Check if tables already exist
            let tableExists = try db.tableExists("items")

            if !tableExists {
                // Execute the schema
                try db.execute(sql: schema)
                print("Database schema created successfully")
            } else {
                print("Database already initialized")
            }
        }
    }

    func getQueue() -> DatabaseQueue? {
        return dbQueue
    }
}
