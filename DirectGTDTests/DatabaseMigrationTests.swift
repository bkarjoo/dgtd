//
//  DatabaseMigrationTests.swift
//  DirectGTDTests
//
//  Test cases for GRDB DatabaseMigrator implementation
//

import Foundation
import Testing
import GRDB
@testable import DirectGTD

struct DatabaseMigrationTests {

    // MARK: - Test Case 1: Fresh Install

    @Test func testFreshInstall() throws {
        // Setup: Empty database (no tables, no metadata)
        let dbQueue = try DatabaseQueue()

        // Action: Run the migration system
        var migrator = createMigrator()
        try migrator.migrate(dbQueue)

        // Expected Outcome: All 5 tables created, grdb_migrations contains "v1"
        try dbQueue.read { db in
            // Verify all required tables exist
            #expect(try db.tableExists("folders") == true)
            #expect(try db.tableExists("items") == true)
            #expect(try db.tableExists("tags") == true)
            #expect(try db.tableExists("notes") == true)
            #expect(try db.tableExists("item_tags") == true)

            // Verify migration metadata
            let appliedMigrations = try migrator.appliedIdentifiers(db)
            #expect(appliedMigrations.contains("v1"))
            #expect(appliedMigrations.count == 1)
        }
    }

    // MARK: - Test Case 2: Legacy Database (No Metadata)

    @Test func testLegacyDatabase() throws {
        // Setup: Create all 5 tables manually without migrator (legacy state)
        let dbQueue = try DatabaseQueue()

        try dbQueue.write { db in
            // Create legacy schema manually (simplified version for test)
            try db.execute(sql: """
                CREATE TABLE folders (id TEXT PRIMARY KEY, name TEXT NOT NULL);
                CREATE TABLE items (id TEXT PRIMARY KEY, title TEXT NOT NULL);
                CREATE TABLE tags (id TEXT PRIMARY KEY, name TEXT NOT NULL);
                CREATE TABLE notes (id TEXT PRIMARY KEY, content TEXT NOT NULL);
                CREATE TABLE item_tags (item_id TEXT, tag_id TEXT, PRIMARY KEY (item_id, tag_id));
            """)

            // Verify legacy tables exist
            #expect(try db.tableExists("folders") == true)
            #expect(try db.tableExists("items") == true)
        }

        // Action: Detect legacy state and reset
        try dbQueue.write { db in
            let hasMigrationMetadata = try db.tableExists("grdb_migrations")
            #expect(!hasMigrationMetadata) // Confirm no metadata

            if !hasMigrationMetadata {
                // Simulate the legacy detection logic from Database.swift
                let requiredTables = ["folders", "items", "tags", "notes", "item_tags"]
                var existingTables: [String] = []

                for tableName in requiredTables {
                    if try db.tableExists(tableName) {
                        existingTables.append(tableName)
                    }
                }

                // Drop all legacy tables
                try db.execute(sql: "PRAGMA foreign_keys = OFF")
                let dropOrder = ["item_tags", "notes", "tags", "items", "folders"]
                for tableName in dropOrder {
                    if existingTables.contains(tableName) {
                        try db.execute(sql: "DROP TABLE IF EXISTS \(tableName)")
                    }
                }
                try db.execute(sql: "PRAGMA foreign_keys = ON")
            }
        }

        // Run migrations
        var migrator = createMigrator()
        try migrator.migrate(dbQueue)

        // Expected Outcome: Tables recreated via migration, grdb_migrations contains "v1"
        try dbQueue.read { db in
            #expect(try db.tableExists("folders") == true)
            #expect(try db.tableExists("items") == true)

            let appliedMigrations = try migrator.appliedIdentifiers(db)
            #expect(appliedMigrations.contains("v1"))
        }
    }

    // MARK: - Test Case 3: V1 Already Applied

    @Test func testV1AlreadyApplied() throws {
        // Setup: Database with v1 migration already applied
        let dbQueue = try DatabaseQueue()
        var migrator = createMigrator()
        try migrator.migrate(dbQueue)

        // Verify initial state
        try dbQueue.read { db in
            let initialMigrations = try migrator.appliedIdentifiers(db)
            #expect(initialMigrations.contains("v1"))
        }

        // Action: Run migrator again
        try migrator.migrate(dbQueue)

        // Expected Outcome: No changes, v1 migration skipped
        try dbQueue.read { db in
            let finalMigrations = try migrator.appliedIdentifiers(db)
            #expect(finalMigrations.contains("v1"))
            #expect(finalMigrations.count == 1)
        }

        // Verify tables still exist
        try dbQueue.read { db in
            #expect(try db.tableExists("folders") == true)
            #expect(try db.tableExists("items") == true)
        }
    }

    // MARK: - Test Case 4: Future Migration (v2)

    @Test func testFutureMigration() throws {
        // Setup: Database with v1 applied
        let dbQueue = try DatabaseQueue()
        var migrator = createMigrator()
        try migrator.migrate(dbQueue)

        // Register a dummy v2 migration
        migrator.registerMigration("v2") { db in
            try db.execute(sql: "CREATE TABLE test_v2 (id TEXT PRIMARY KEY)")
        }

        // Action: Run migrator with v2
        try migrator.migrate(dbQueue)

        // Expected Outcome: V2 applied, grdb_migrations contains ["v1", "v2"]
        try dbQueue.read { db in
            let appliedMigrations = try migrator.appliedIdentifiers(db)
            #expect(appliedMigrations.contains("v1"))
            #expect(appliedMigrations.contains("v2"))
            #expect(appliedMigrations.count == 2)

            // Verify v2 table was created
            #expect(try db.tableExists("test_v2") == true)
        }
    }

    // MARK: - Test Case 5: Migration Failure

    @Test func testMigrationFailure() throws {
        // Setup: Fresh database
        let dbQueue = try DatabaseQueue()

        // Create migrator with intentionally broken migration
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.execute(sql: "CREATE TABLE folders (id TEXT PRIMARY KEY)")
        }
        migrator.registerMigration("v2_broken") { db in
            // Invalid SQL to trigger failure
            try db.execute(sql: "CREATE INVALID SYNTAX")
        }

        // Action: Attempt to run migrations
        do {
            try migrator.migrate(dbQueue)
            Issue.record("Migration should have failed but succeeded")
        } catch {
            // Expected: Migration should fail
            // GRDB automatically rolls back the transaction
        }

        // Expected Outcome: Transaction rolled back, only v1 applied, error logged
        try dbQueue.read { db in
            let appliedMigrations = try migrator.appliedIdentifiers(db)
            #expect(appliedMigrations.contains("v1"))
            #expect(!appliedMigrations.contains("v2_broken"))

            // Verify database is still in valid state with v1
            #expect(try db.tableExists("folders") == true)
            let testBrokenExists = try db.tableExists("test_broken")
            #expect(testBrokenExists == false)
        }
    }

    // MARK: - Test Case 6: Regression Testing
    // Note: This will be verified by running the full existing test suite
    // This test ensures the migration system doesn't break existing functionality

    @Test func testMigrationDoesNotBreakExistingFunctionality() throws {
        // Setup: Create database with migration system
        let dbQueue = try DatabaseQueue()
        var migrator = createMigrator()
        try migrator.migrate(dbQueue)

        // Test: Perform basic database operations that existing code depends on
        try dbQueue.write { db in
            // Insert a folder
            try db.execute(sql: """
                INSERT INTO folders (id, name, created_at, modified_at)
                VALUES ('test-folder-1', 'Test Folder', \(Date().timeIntervalSince1970), \(Date().timeIntervalSince1970))
            """)

            // Insert an item
            try db.execute(sql: """
                INSERT INTO items (id, title, created_at, modified_at)
                VALUES ('test-item-1', 'Test Item', \(Date().timeIntervalSince1970), \(Date().timeIntervalSince1970))
            """)

            // Insert a tag
            try db.execute(sql: """
                INSERT INTO tags (id, name)
                VALUES ('test-tag-1', 'Test Tag')
            """)
        }

        // Verify data was inserted successfully
        try dbQueue.read { db in
            let folderCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM folders")
            let itemCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")
            let tagCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM tags")

            #expect(folderCount == 1)
            #expect(itemCount == 1)
            #expect(tagCount == 1)
        }

        // Verify foreign key constraints still work
        try dbQueue.write { db in
            // Try to insert item with invalid folder_id
            do {
                try db.execute(sql: """
                    INSERT INTO items (id, title, folder_id, created_at, modified_at)
                    VALUES ('test-item-2', 'Invalid Item', 'non-existent-folder', \(Date().timeIntervalSince1970), \(Date().timeIntervalSince1970))
                """)
                // This should fail due to foreign key constraint
                Issue.record("Foreign key constraint should have prevented this insert")
            } catch {
                // Expected: Foreign key constraint violation
            }
        }
    }

    // MARK: - Helper Functions

    /// Create a migrator with the same configuration as Database.swift
    private func createMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        // Register v1 migration (baseline schema)
        migrator.registerMigration("v1") { db in
            // Load schema from bundle
            guard let schemaURL = Bundle.main.url(forResource: "schema", withExtension: "sql") else {
                throw DatabaseError.schemaNotFound
            }

            let schema = try String(contentsOf: schemaURL, encoding: .utf8)
            try db.execute(sql: schema)
        }

        return migrator
    }

    // Match the error enum from Database.swift
    enum DatabaseError: Error {
        case schemaNotFound
    }
}
