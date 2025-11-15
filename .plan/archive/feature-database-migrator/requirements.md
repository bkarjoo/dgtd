# Feature: GRDB DatabaseMigrator Implementation

## Problem Statement

**Current State:**
The app currently uses a drop-and-recreate approach for database schema changes. When any table is missing, ALL tables are dropped and recreated from schema.sql.

**Critical Issue:**
This approach causes **complete data loss** on every schema change. Any folders, items, tags, notes, or relationships created by the user are permanently deleted when the schema evolves.

**Impact:**
- Development phase: Acceptable (data loss expected during active development)
- Production use: **UNACCEPTABLE** - Users will lose all their GTD data on app updates

## Requirements

### 1. Implement GRDB's DatabaseMigrator

Replace the current drop/recreate logic with GRDB's versioned migration system that:
- Preserves existing data during schema changes
- Applies incremental migrations in sequence
- Tracks which migrations have been applied
- Supports both fresh installs and upgrades from previous versions

### 2. Migration Version Tracking

- Use GRDB's built-in migration versioning system
- Each schema change gets a unique version identifier
- Database tracks which migrations have been applied
- Migrations are idempotent (safe to run multiple times)

### 3. Initial Migration (v1)

Create the baseline migration that:
- Represents the current schema (all 5 tables: folders, items, tags, notes, item_tags)
- Runs on fresh installs
- Is skipped if tables already exist (upgrade path)

### 4. Backward Compatibility (SIMPLE APPROACH)

**Strategy: Clean cutover with one-time data reset**

The migrator handles three scenarios:
- **Fresh install (no tables, no metadata):** Runs all migrations from v1 onwards → Creates all tables
- **Legacy database (tables exist, no metadata):** Drops all tables, runs all migrations from v1 → **One-time data loss**
- **Migrated database (metadata exists with v1):** Skips v1, ready for future migrations → Normal production state

**Detection Logic:**
1. Check for `grdb_migrations` table
2. If missing: Drop any existing tables, run all migrations
3. If present: Use GRDB's standard migration logic

**Why this approach:**
- Simple, reliable, low-risk implementation
- Clear cutover point from legacy to migration system
- Eliminates complexity of schema validation
- Acceptable because all current users are in development phase

### 5. Future Migration Support

Design the system to easily support future schema changes:
- Adding new columns
- Adding new tables
- Modifying constraints
- Data transformations

### 6. Data Loss Policy (CLARIFICATION)

**Transition Policy:**
- **One-time data loss accepted** for transition from old system to migration system
- Any database without migration metadata → treated as legacy → full reset
- This is acceptable because all current users are in development phase
- After migration system is in place: **Zero data loss** for all future schema changes

**Rationale:**
- Simple, reliable implementation
- Lower risk than complex schema detection
- Clear cutover point
- Aligns with development phase status

### 7. Error Handling

- Failed migrations should not leave database in broken state (GRDB handles via transactions)
- Clear error messages for debugging
- Logging of all migration operations (using NSLog)
- **Migration failure UX:** Log error with NSLog, app will continue with existing schema (GRDB automatically rolls back failed migrations)

### 8. Testing Requirements

**Test Approach:** Use in-memory databases for fast, isolated tests

**Test Scenarios:**

| Test Case | Setup | Action | Expected Outcome |
|-----------|-------|--------|------------------|
| TC1: Fresh install | Empty database, no tables | Initialize database | All 5 tables created, grdb_migrations contains "v1" |
| TC2: Legacy database (no metadata) | Create all 5 tables manually, no grdb_migrations | Initialize database | Database reset, all tables recreated, grdb_migrations contains "v1" |
| TC3: V1 already applied | grdb_migrations contains "v1" | Initialize database | No changes, skip v1 migration |
| TC4: Future migration (v2) | grdb_migrations contains "v1", register dummy v2 | Run migrator | V2 applied, grdb_migrations contains ["v1", "v2"] |
| TC5: Migration failure | Inject SQL error in migration | Run migrator | Transaction rolled back, database unchanged, error logged |
| TC6: All tests pass | After migration system implemented | Run full test suite | Zero regressions |

**Test Implementation Details:**
- Use `DatabaseQueue(configuration: Configuration())` for in-memory databases
- Helper function to create "legacy" state: Create tables without using migrator
- Verify using `migrator.appliedIdentifiers(dbQueue)` to check which migrations ran

## State Machine Specification

### Database States

| State | Detection Logic | Handling Action | Notes |
|-------|----------------|-----------------|-------|
| **Empty** | No tables exist, no grdb_migrations table | Run all migrations from v1 | Standard fresh install |
| **Legacy (current schema)** | All 5 tables exist, no grdb_migrations table | **Reset database**: Drop all tables, run all migrations from v1 | Accepts one-time data loss for transition |
| **Migrated (v1)** | grdb_migrations table exists with "v1" entry | Skip v1, ready for future migrations | Normal production state |
| **Partially created** | Some tables exist, no grdb_migrations | **Reset database**: Drop all tables, run all migrations from v1 | Indicates previous failure or manual tampering |
| **Migration in progress** | GRDB transaction active | N/A - GRDB handles atomically | Rollback on failure, commit on success |
| **Corrupted metadata** | grdb_migrations exists but is invalid | Let GRDB handle (will error on migrate()) | Rare edge case, user must delete database file |

### State Detection Implementation

**Detection Order:**
1. Check if `grdb_migrations` table exists
   - If YES and contains "v1" → State: Migrated (v1)
   - If YES but doesn't contain "v1" → State: Corrupted (let GRDB error)
   - If NO → Continue to step 2
2. Check if any of the 5 tables exist
   - If ANY exist → State: Legacy or Partially Created → **DROP ALL TABLES**
   - If NONE exist → State: Empty

**Simplification:**
Instead of complex schema validation, we use a simple rule:
- **If grdb_migrations doesn't exist**: Drop all tables and start fresh
- This ensures clean state for migration system

### State Transition Table

| Current State | Event | Next State | Action |
|---------------|-------|------------|--------|
| Empty | Initialize database | Migrated (v1) | Run v1 migration |
| Legacy | Initialize database | Migrated (v1) | Drop all tables → Run v1 migration |
| Partially Created | Initialize database | Migrated (v1) | Drop all tables → Run v1 migration |
| Migrated (v1) | Initialize database | Migrated (v1) | No action (v1 already applied) |
| Migrated (v1) | Add v2 migration | Migrated (v1, v2) | Run v2 migration only |
| Any | Migration fails | Previous state (rollback) | GRDB transaction rollback |

### Edge Case Handling

**Edge Case 1: Database has current schema but no metadata**
- **Detection:** All 5 tables exist, no grdb_migrations
- **Handling:** Drop all tables, recreate via migrations
- **Result:** One-time data loss (acceptable per requirement #6)

**Edge Case 2: Partial database (some tables missing)**
- **Detection:** 1-4 tables exist, no grdb_migrations
- **Handling:** Drop all existing tables, recreate via migrations
- **Result:** Clean state, no partial/broken databases

**Edge Case 3: Migration fails mid-sequence**
- **Detection:** GRDB catches SQL error during migration
- **Handling:** GRDB automatically rolls back transaction
- **Result:** Database unchanged, error logged with NSLog
- **User action:** Check logs, delete database file if needed, restart app

**Edge Case 4: Corrupted migration metadata**
- **Detection:** grdb_migrations table exists but is invalid
- **Handling:** GRDB will error when trying to read metadata
- **Result:** App initialization fails, error logged
- **User action:** Delete database file, restart app

**Edge Case 5: V1 already applied (standard production case)**
- **Detection:** grdb_migrations contains "v1"
- **Handling:** Skip v1, ready for future migrations
- **Result:** No action, database unchanged

## Technical Specifications

### Location
Modify `DirectGTD/Database.swift` (lines 32-103 contain current migration logic)

### GRDB DatabaseMigrator API

Reference: GRDB documentation on migrations
- Use `DatabaseMigrator()` to create migrator instance
- Use `migrator.registerMigration()` to define each version
- Use `migrator.migrate(dbQueue)` to apply pending migrations

### Current Schema (Baseline v1)

The current schema.sql contains:
1. **folders table:** id, name, parent_id (with circular reference constraints)
2. **items table:** id, title, type, status, etc.
3. **tags table:** id, name, color
4. **notes table:** id, item_id, content (foreign key to items)
5. **item_tags table:** item_id, tag_id (junction table with composite key)

All foreign key relationships and constraints should be preserved.

## Success Criteria

1. ✅ Fresh install creates all tables via migration system
2. ✅ Legacy database (no metadata) resets and transitions to migration system (one-time data loss acceptable)
3. ✅ Migrated database (v1 applied) preserves data and skips v1
4. ✅ Future schema changes can be added as new migrations
5. ✅ All existing tests continue to pass
6. ✅ Migration operations logged with NSLog() for debugging
7. ✅ **Zero data loss for all future migrations** (after migration system is in place)

## Non-Requirements

- **Data migration from old drop/recreate system:** Current users in development phase are okay with one final data loss to transition to the new system
- **Rollback functionality:** Migrations are forward-only (standard GRDB approach)

## References

- Current implementation: `DirectGTD/Database.swift:32-103`
- Schema file: `database/schema.sql`
- GRDB documentation: https://github.com/groue/GRDB.swift#migrations
- Previous work: `.plan/archive/issue-schema-not-applied/` (archived lifecycle folder with migration context)

## Priority

**HIGH** - Required before production release to end users. Current drop/recreate approach is only acceptable during active development phase.

## Estimated Complexity

**MEDIUM** - Well-documented GRDB feature, clear requirements, but requires careful handling of backward compatibility and testing.
