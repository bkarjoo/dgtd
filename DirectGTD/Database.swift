import DirectGTDCore
import Foundation
import GRDB

// MARK: - Database Implementation
open class Database: DatabaseProvider, @unchecked Sendable {
    public static let shared = Database()

    private static let pendingRestoreKey = "pendingRestorePath"

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

            // Check for pending restore before opening database
            if let pendingPath = UserDefaults.standard.string(forKey: Database.pendingRestoreKey) {
                NSLog("Database: Found pending restore from \(pendingPath)")
                Database.performPendingRestore(from: pendingPath, to: dbPath, fileManager: fileManager)
                UserDefaults.standard.removeObject(forKey: Database.pendingRestoreKey)
            }

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

    private static func performPendingRestore(from backupPath: String, to dbPath: String, fileManager: FileManager) {
        let walPath = dbPath + "-wal"
        let shmPath = dbPath + "-shm"
        let tempPath = dbPath + ".restore_tmp"

        guard fileManager.fileExists(atPath: backupPath) else {
            NSLog("Database: Pending restore skipped - backup missing at \(backupPath)")
            return
        }

        do {
            // Copy backup to a temporary location first so we never delete the live DB before a successful copy
            if fileManager.fileExists(atPath: tempPath) {
                try fileManager.removeItem(atPath: tempPath)
            }
            try fileManager.copyItem(atPath: backupPath, toPath: tempPath)

            // Remove existing database files
            if fileManager.fileExists(atPath: dbPath) {
                try fileManager.removeItem(atPath: dbPath)
            }
            if fileManager.fileExists(atPath: walPath) {
                try fileManager.removeItem(atPath: walPath)
            }
            if fileManager.fileExists(atPath: shmPath) {
                try fileManager.removeItem(atPath: shmPath)
            }

            // Move restored database into place
            try fileManager.moveItem(atPath: tempPath, toPath: dbPath)
            NSLog("Database: Restore completed successfully from \(backupPath)")
        } catch {
            // Ensure temporary file is cleaned up if anything failed
            try? fileManager.removeItem(atPath: tempPath)
            NSLog("Database: Restore failed - \(error)")
            // Continue with whatever database state exists
        }
    }

    /// Schedule a restore to happen on next app launch
    static func scheduleRestore(from backupPath: String) {
        UserDefaults.standard.set(backupPath, forKey: pendingRestoreKey)
        NSLog("Database: Scheduled restore from \(backupPath) for next launch")
    }

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

        // Register v6 migration (add show_ancestors column to saved_searches)
        migrator.registerMigration("v6") { db in
            NSLog("Database: Running migration v6 (add show_ancestors column)")

            // Check if column already exists (for databases created from updated schema.sql)
            let columnExists = try db.columns(in: "saved_searches").contains { $0.name == "show_ancestors" }

            if !columnExists {
                try db.execute(sql: """
                    ALTER TABLE saved_searches ADD COLUMN show_ancestors INTEGER NOT NULL DEFAULT 1
                """)
                NSLog("Database: Added show_ancestors column with default value 1")
            } else {
                NSLog("Database: show_ancestors column already exists, skipping")
            }

            NSLog("Database: Migration v6 completed successfully")
        }

        // Register v7 migration (remove show_ancestors column)
        migrator.registerMigration("v7") { db in
            NSLog("Database: Running migration v7 (remove show_ancestors column)")

            let columnExists = try db.columns(in: "saved_searches").contains { $0.name == "show_ancestors" }
            guard columnExists else {
                NSLog("Database: show_ancestors column already removed, skipping")
                return
            }

            try db.execute(sql: """
                CREATE TABLE saved_searches_new (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    sql TEXT NOT NULL,
                    sort_order INTEGER DEFAULT 0,
                    created_at INTEGER NOT NULL,
                    modified_at INTEGER NOT NULL
                )
            """)

            try db.execute(sql: """
                INSERT INTO saved_searches_new (id, name, sql, sort_order, created_at, modified_at)
                SELECT id, name, sql, sort_order, created_at, modified_at FROM saved_searches
            """)

            try db.execute(sql: "DROP TABLE saved_searches")
            try db.execute(sql: "ALTER TABLE saved_searches_new RENAME TO saved_searches")

            NSLog("Database: Migration v7 completed successfully")
        }

        // Register v8 migration (add time_entries table)
        migrator.registerMigration("v8") { db in
            NSLog("Database: Running migration v8 (add time_entries table)")

            let tableExists = try db.tableExists("time_entries")

            guard !tableExists else {
                NSLog("Database: time_entries table already exists, skipping")
                return
            }

            try db.execute(sql: """
                CREATE TABLE time_entries (
                    id TEXT PRIMARY KEY,
                    item_id TEXT NOT NULL,
                    started_at INTEGER NOT NULL,
                    ended_at INTEGER,
                    duration INTEGER,
                    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
                )
            """)
            NSLog("Database: Created time_entries table")

            try db.execute(sql: "CREATE INDEX idx_time_entries_item_id ON time_entries(item_id)")
            try db.execute(sql: "CREATE INDEX idx_time_entries_started_at ON time_entries(started_at)")
            NSLog("Database: Created indexes for time_entries")

            NSLog("Database: Migration v8 completed successfully")
        }

        // Register v9 migration (CloudKit sync fields)
        migrator.registerMigration("v9") { db in
            NSLog("Database: Running migration v9 (CloudKit sync fields)")

            // Disable foreign keys for table recreation
            try db.execute(sql: "PRAGMA foreign_keys = OFF")

            // ============================================
            // PART 1: Add modified_at to tables missing it
            // ============================================

            // item_tags needs timestamps for conflict resolution
            if try !db.columns(in: "item_tags").contains(where: { $0.name == "created_at" }) {
                try db.execute(sql: "ALTER TABLE item_tags ADD COLUMN created_at INTEGER")
                try db.execute(sql: "ALTER TABLE item_tags ADD COLUMN modified_at INTEGER")
                try db.execute(sql: "UPDATE item_tags SET created_at = strftime('%s', 'now'), modified_at = strftime('%s', 'now') WHERE created_at IS NULL")
                NSLog("Database: Added timestamps to item_tags")
            }

            // time_entries needs modified_at
            if try !db.columns(in: "time_entries").contains(where: { $0.name == "modified_at" }) {
                try db.execute(sql: "ALTER TABLE time_entries ADD COLUMN modified_at INTEGER")
                try db.execute(sql: "UPDATE time_entries SET modified_at = COALESCE(ended_at, started_at) WHERE modified_at IS NULL")
                NSLog("Database: Added modified_at to time_entries")
            }

            // tags needs timestamps
            if try !db.columns(in: "tags").contains(where: { $0.name == "created_at" }) {
                try db.execute(sql: "ALTER TABLE tags ADD COLUMN created_at INTEGER")
                try db.execute(sql: "ALTER TABLE tags ADD COLUMN modified_at INTEGER")
                try db.execute(sql: "UPDATE tags SET created_at = strftime('%s', 'now'), modified_at = strftime('%s', 'now') WHERE created_at IS NULL")
                NSLog("Database: Added timestamps to tags")
            }

            // ============================================
            // PART 2: Add sync tracking columns to all tables
            // ============================================

            // items: sync fields
            if try !db.columns(in: "items").contains(where: { $0.name == "ck_record_name" }) {
                try db.execute(sql: "ALTER TABLE items ADD COLUMN ck_record_name TEXT")
                try db.execute(sql: "ALTER TABLE items ADD COLUMN ck_change_tag TEXT")
                try db.execute(sql: "ALTER TABLE items ADD COLUMN needs_push INTEGER DEFAULT 1")
                try db.execute(sql: "ALTER TABLE items ADD COLUMN deleted_at INTEGER")
                NSLog("Database: Added sync fields to items")
            }

            // tags: sync fields
            if try !db.columns(in: "tags").contains(where: { $0.name == "ck_record_name" }) {
                try db.execute(sql: "ALTER TABLE tags ADD COLUMN ck_record_name TEXT")
                try db.execute(sql: "ALTER TABLE tags ADD COLUMN ck_change_tag TEXT")
                try db.execute(sql: "ALTER TABLE tags ADD COLUMN needs_push INTEGER DEFAULT 1")
                try db.execute(sql: "ALTER TABLE tags ADD COLUMN deleted_at INTEGER")
                NSLog("Database: Added sync fields to tags")
            }

            // item_tags: sync fields
            if try !db.columns(in: "item_tags").contains(where: { $0.name == "ck_record_name" }) {
                try db.execute(sql: "ALTER TABLE item_tags ADD COLUMN ck_record_name TEXT")
                try db.execute(sql: "ALTER TABLE item_tags ADD COLUMN ck_change_tag TEXT")
                try db.execute(sql: "ALTER TABLE item_tags ADD COLUMN needs_push INTEGER DEFAULT 1")
                try db.execute(sql: "ALTER TABLE item_tags ADD COLUMN deleted_at INTEGER")
                NSLog("Database: Added sync fields to item_tags")
            }

            // time_entries: sync fields
            if try !db.columns(in: "time_entries").contains(where: { $0.name == "ck_record_name" }) {
                try db.execute(sql: "ALTER TABLE time_entries ADD COLUMN ck_record_name TEXT")
                try db.execute(sql: "ALTER TABLE time_entries ADD COLUMN ck_change_tag TEXT")
                try db.execute(sql: "ALTER TABLE time_entries ADD COLUMN needs_push INTEGER DEFAULT 1")
                try db.execute(sql: "ALTER TABLE time_entries ADD COLUMN deleted_at INTEGER")
                NSLog("Database: Added sync fields to time_entries")
            }

            // saved_searches: sync fields
            if try !db.columns(in: "saved_searches").contains(where: { $0.name == "ck_record_name" }) {
                try db.execute(sql: "ALTER TABLE saved_searches ADD COLUMN ck_record_name TEXT")
                try db.execute(sql: "ALTER TABLE saved_searches ADD COLUMN ck_change_tag TEXT")
                try db.execute(sql: "ALTER TABLE saved_searches ADD COLUMN needs_push INTEGER DEFAULT 1")
                try db.execute(sql: "ALTER TABLE saved_searches ADD COLUMN deleted_at INTEGER")
                NSLog("Database: Added sync fields to saved_searches")
            }

            // ============================================
            // PART 3: Create sync_metadata table
            // ============================================

            if try !db.tableExists("sync_metadata") {
                try db.execute(sql: """
                    CREATE TABLE sync_metadata (
                        key TEXT PRIMARY KEY,
                        value BLOB
                    )
                """)
                NSLog("Database: Created sync_metadata table")
            }

            // ============================================
            // PART 4: Create indexes
            // ============================================

            // Unique indexes on ck_record_name
            try db.execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS idx_items_ck_record_name ON items(ck_record_name) WHERE ck_record_name IS NOT NULL")
            try db.execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS idx_tags_ck_record_name ON tags(ck_record_name) WHERE ck_record_name IS NOT NULL")
            try db.execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS idx_item_tags_ck_record_name ON item_tags(ck_record_name) WHERE ck_record_name IS NOT NULL")
            try db.execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS idx_time_entries_ck_record_name ON time_entries(ck_record_name) WHERE ck_record_name IS NOT NULL")
            try db.execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS idx_saved_searches_ck_record_name ON saved_searches(ck_record_name) WHERE ck_record_name IS NOT NULL")

            // Indexes for efficient dirty queries
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_items_needs_push ON items(needs_push) WHERE needs_push = 1")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_tags_needs_push ON tags(needs_push) WHERE needs_push = 1")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_item_tags_needs_push ON item_tags(needs_push) WHERE needs_push = 1")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_time_entries_needs_push ON time_entries(needs_push) WHERE needs_push = 1")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_saved_searches_needs_push ON saved_searches(needs_push) WHERE needs_push = 1")

            NSLog("Database: Created sync indexes")

            // ============================================
            // PART 5: Recreate tables to remove CASCADE deletes
            // ============================================

            // Recreate item_tags without CASCADE
            try db.execute(sql: """
                CREATE TABLE item_tags_new (
                    item_id TEXT NOT NULL,
                    tag_id TEXT NOT NULL,
                    created_at INTEGER,
                    modified_at INTEGER,
                    ck_record_name TEXT,
                    ck_change_tag TEXT,
                    needs_push INTEGER DEFAULT 1,
                    deleted_at INTEGER,
                    PRIMARY KEY (item_id, tag_id),
                    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE NO ACTION,
                    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE NO ACTION
                )
            """)
            try db.execute(sql: "INSERT INTO item_tags_new SELECT item_id, tag_id, created_at, modified_at, ck_record_name, ck_change_tag, needs_push, deleted_at FROM item_tags")
            try db.execute(sql: "DROP TABLE item_tags")
            try db.execute(sql: "ALTER TABLE item_tags_new RENAME TO item_tags")
            // Recreate all indexes that existed before migration
            try db.execute(sql: "CREATE INDEX idx_item_tags_item ON item_tags(item_id)")
            try db.execute(sql: "CREATE INDEX idx_item_tags_tag ON item_tags(tag_id)")
            try db.execute(sql: "CREATE UNIQUE INDEX idx_item_tags_ck_record_name ON item_tags(ck_record_name) WHERE ck_record_name IS NOT NULL")
            try db.execute(sql: "CREATE INDEX idx_item_tags_needs_push ON item_tags(needs_push) WHERE needs_push = 1")
            NSLog("Database: Recreated item_tags without CASCADE")

            // Recreate time_entries without CASCADE
            try db.execute(sql: """
                CREATE TABLE time_entries_new (
                    id TEXT PRIMARY KEY,
                    item_id TEXT NOT NULL,
                    started_at INTEGER NOT NULL,
                    ended_at INTEGER,
                    duration INTEGER,
                    modified_at INTEGER,
                    ck_record_name TEXT,
                    ck_change_tag TEXT,
                    needs_push INTEGER DEFAULT 1,
                    deleted_at INTEGER,
                    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE NO ACTION
                )
            """)
            try db.execute(sql: "INSERT INTO time_entries_new SELECT id, item_id, started_at, ended_at, duration, modified_at, ck_record_name, ck_change_tag, needs_push, deleted_at FROM time_entries")
            try db.execute(sql: "DROP TABLE time_entries")
            try db.execute(sql: "ALTER TABLE time_entries_new RENAME TO time_entries")
            try db.execute(sql: "CREATE UNIQUE INDEX idx_time_entries_ck_record_name ON time_entries(ck_record_name) WHERE ck_record_name IS NOT NULL")
            try db.execute(sql: "CREATE INDEX idx_time_entries_needs_push ON time_entries(needs_push) WHERE needs_push = 1")
            try db.execute(sql: "CREATE INDEX idx_time_entries_item_id ON time_entries(item_id)")
            try db.execute(sql: "CREATE INDEX idx_time_entries_started_at ON time_entries(started_at)")
            NSLog("Database: Recreated time_entries without CASCADE")

            // Recreate items without CASCADE on parent_id
            try db.execute(sql: """
                CREATE TABLE items_new (
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
                    needs_push INTEGER DEFAULT 1,
                    deleted_at INTEGER,
                    FOREIGN KEY (parent_id) REFERENCES items(id) ON DELETE NO ACTION
                )
            """)
            try db.execute(sql: "INSERT INTO items_new SELECT id, title, item_type, notes, parent_id, sort_order, created_at, modified_at, completed_at, due_date, earliest_start_time, ck_record_name, ck_change_tag, needs_push, deleted_at FROM items")
            try db.execute(sql: "DROP TABLE items")
            try db.execute(sql: "ALTER TABLE items_new RENAME TO items")
            try db.execute(sql: "CREATE UNIQUE INDEX idx_items_ck_record_name ON items(ck_record_name) WHERE ck_record_name IS NOT NULL")
            try db.execute(sql: "CREATE INDEX idx_items_needs_push ON items(needs_push) WHERE needs_push = 1")
            try db.execute(sql: "CREATE INDEX idx_parent_id ON items(parent_id)")
            NSLog("Database: Recreated items without CASCADE")

            // ============================================
            // PART 6: Bootstrap existing data for first sync
            // ============================================

            try db.execute(sql: "UPDATE items SET ck_record_name = 'Item_' || id WHERE ck_record_name IS NULL")
            try db.execute(sql: "UPDATE tags SET ck_record_name = 'Tag_' || id WHERE ck_record_name IS NULL")
            try db.execute(sql: "UPDATE item_tags SET ck_record_name = 'ItemTag_' || item_id || '_' || tag_id WHERE ck_record_name IS NULL")
            try db.execute(sql: "UPDATE time_entries SET ck_record_name = 'TimeEntry_' || id WHERE ck_record_name IS NULL")
            try db.execute(sql: "UPDATE saved_searches SET ck_record_name = 'SavedSearch_' || id WHERE ck_record_name IS NULL")

            // All existing data needs initial push
            try db.execute(sql: "UPDATE items SET needs_push = 1")
            try db.execute(sql: "UPDATE tags SET needs_push = 1")
            try db.execute(sql: "UPDATE item_tags SET needs_push = 1")
            try db.execute(sql: "UPDATE time_entries SET needs_push = 1")
            try db.execute(sql: "UPDATE saved_searches SET needs_push = 1")

            NSLog("Database: Bootstrapped existing data for sync")

            // Re-enable foreign keys
            try db.execute(sql: "PRAGMA foreign_keys = ON")

            NSLog("Database: Migration v9 completed successfully")
        }

        // Register v10 migration (add ck_system_fields for CKRecord system field restoration)
        migrator.registerMigration("v10") { db in
            NSLog("Database: Running migration v10 (add ck_system_fields column)")

            // items: add ck_system_fields
            if try !db.columns(in: "items").contains(where: { $0.name == "ck_system_fields" }) {
                try db.execute(sql: "ALTER TABLE items ADD COLUMN ck_system_fields BLOB")
                NSLog("Database: Added ck_system_fields to items")
            }

            // tags: add ck_system_fields
            if try !db.columns(in: "tags").contains(where: { $0.name == "ck_system_fields" }) {
                try db.execute(sql: "ALTER TABLE tags ADD COLUMN ck_system_fields BLOB")
                NSLog("Database: Added ck_system_fields to tags")
            }

            // item_tags: add ck_system_fields
            if try !db.columns(in: "item_tags").contains(where: { $0.name == "ck_system_fields" }) {
                try db.execute(sql: "ALTER TABLE item_tags ADD COLUMN ck_system_fields BLOB")
                NSLog("Database: Added ck_system_fields to item_tags")
            }

            // time_entries: add ck_system_fields
            if try !db.columns(in: "time_entries").contains(where: { $0.name == "ck_system_fields" }) {
                try db.execute(sql: "ALTER TABLE time_entries ADD COLUMN ck_system_fields BLOB")
                NSLog("Database: Added ck_system_fields to time_entries")
            }

            // saved_searches: add ck_system_fields
            if try !db.columns(in: "saved_searches").contains(where: { $0.name == "ck_system_fields" }) {
                try db.execute(sql: "ALTER TABLE saved_searches ADD COLUMN ck_system_fields BLOB")
                NSLog("Database: Added ck_system_fields to saved_searches")
            }

            NSLog("Database: Migration v10 completed successfully")
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
