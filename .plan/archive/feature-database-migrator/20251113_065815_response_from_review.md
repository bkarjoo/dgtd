**Important: Read `README.md` first to understand your role and workflow before starting this assignment.**

**Status:** REQUIRES CHANGES

**Overall Assessment:**

The requirements document is well-structured and addresses the critical problem of data loss during schema evolution. The proposed GRDB DatabaseMigrator approach is technically sound and feasible. However, there are several critical gaps in the state machine specification and backward compatibility strategy that must be addressed before development begins.

**Requirements Assessment:**

**Completeness:** PARTIAL
- Fresh install scenario: Clearly specified
- Existing database scenario: Ambiguously defined (see critical issues below)
- Future migrations: Adequately addressed
- Edge cases: Listed but not fully specified with handling strategies

**Clarity:** GOOD
- Technical specifications reference correct code locations (Database.swift:32-103)
- GRDB API usage is correctly identified
- Success criteria are measurable
- Scope is well-defined with clear non-requirements

**Feasibility:** CONFIRMED
- GRDB DatabaseMigrator supports all required features
- Migration tracking via `grdb_migrations` table (automatic)
- Transactions are handled automatically by GRDB
- API: `migrator.registerMigration(identifier:migrate:)` and `migrator.migrate(dbQueue)`

**State Machine Analysis:**

**INCOMPLETE - Critical Gaps Identified**

The requirements document lists edge cases but does not specify the **detection logic** or **handling behavior** for each state. Here's what's missing:

**State Detection Logic (MISSING):**

The requirements state "detect existing tables, marks v1 as applied" but do NOT specify:

1. **How to detect "existing database with current schema"?**
   - Check all 5 tables exist?
   - Check table structure matches schema.sql?
   - Check for specific columns/constraints?
   - What if tables exist but with wrong schema (e.g., from manual testing)?

2. **How to differentiate these three states:**
   - State A: Empty database (no tables, no grdb_migrations)
   - State B: Current schema without migrations (5 tables exist, no grdb_migrations)
   - State C: Database with v1 applied (5 tables exist, grdb_migrations has "v1")

**Current implementation** (Database.swift:44-57) checks `db.tableExists(tableName)` for all 5 tables. Should this logic be reused?

**State Transition Specification (INCOMPLETE):**

The requirements list states but don't specify **actions** for each:

| Current State | Detection | Action Required | Specified? |
|---------------|-----------|-----------------|------------|
| Empty database | No tables, no grdb_migrations | Run all migrations from v1 | YES |
| Fresh install | No tables, no grdb_migrations | Run all migrations from v1 | YES |
| Existing current schema | All 5 tables exist, no grdb_migrations | **HOW TO HANDLE?** | **NO** |
| Partially created | Some tables exist | **HOW TO HANDLE?** | **NO** |
| V1 already applied | grdb_migrations contains "v1" | Skip v1, ready for v2+ | IMPLIED |
| Migration failed | Transaction rollback by GRDB | **RECOVERY PROCESS?** | **NO** |
| Corrupted metadata | grdb_migrations exists but invalid | **DETECTION + HANDLING?** | **NO** |

**Edge Case Behavior (NOT SPECIFIED):**

1. **"Existing database (current schema)" Handling:**
   - Requirements say "mark v1 as applied" - but HOW?
   - Do we manually insert into grdb_migrations?
   - Do we use `eraseDatabaseOnSchemaChange` flag?
   - What if detection is wrong (tables exist but wrong schema)?

2. **"Partially created database" Handling:**
   - Current code drops all tables if any are missing (Database.swift:60-88)
   - Should the new implementation do the same?
   - Or should it try to complete the partial migration?
   - Requirements don't specify

3. **Migration Failure Mid-Sequence:**
   - GRDB uses transactions, so rollback is automatic
   - But what does the USER do to recover?
   - Delete database file and reinstall?
   - Retry migration?
   - Requirements don't specify recovery UX

4. **Corrupted Migration Metadata:**
   - What if grdb_migrations table is corrupted?
   - What if it contains invalid identifiers?
   - How do we detect this condition?
   - Requirements don't specify

**Backward Compatibility Analysis:**

**CRITICAL RISK: Ambiguous Detection Strategy**

The requirements state (line 43-44):
> "Existing database (current schema): Detects existing tables, marks v1 as applied, ready for future migrations"

**Problem 1: "Marks v1 as applied" - Implementation Not Specified**

GRDB's `migrate()` method runs migrations that are NOT in the grdb_migrations table. If we want to "mark v1 as applied" without running it, we need to:

**Option A:** Conditionally register migration
```swift
// Check if tables exist
if allTablesExist {
    // Don't register v1, or register as no-op
} else {
    migrator.registerMigration("v1") { db in
        // Create all tables
    }
}
```

**Option B:** Manually insert into grdb_migrations
```swift
if allTablesExist && !hasV1InMigrationTable {
    try db.execute(sql: "INSERT INTO grdb_migrations (identifier) VALUES ('v1')")
}
```

**Neither approach is specified in requirements.** This is a critical implementation detail that affects correctness.

**Problem 2: Schema Validation Not Addressed**

The requirements assume we can reliably detect "current schema" by checking if 5 tables exist. But:

- What if tables exist with WRONG columns (from manual testing)?
- What if tables exist but indexes are missing?
- What if tables exist but triggers are missing?

Schema.sql has:
- 5 tables
- 2 triggers (circular reference prevention)
- 9 indexes

**Should we validate all of these?** Requirements don't specify.

**Problem 3: Risk of False Positives**

If detection logic is wrong (false positive: thinks schema is current but it's actually old), we'll:
1. Mark v1 as applied (incorrectly)
2. Skip creating tables (data loss)
3. App crashes on missing columns/tables

**Mitigation:** Requirements should specify validation strategy, not just existence check.

**Recommendation:** Add a schema version check or comprehensive validation

**Option 1 - Schema Version Marker:**
```sql
CREATE TABLE app_metadata (
    key TEXT PRIMARY KEY,
    value TEXT
);
INSERT INTO app_metadata (key, value) VALUES ('schema_version', '1');
```

Then check for this table/value to detect "migrated database" vs "legacy database"

**Option 2 - Comprehensive Validation:**
Check not just table existence but also:
- Column count and names
- Foreign key constraints
- Index existence

**Option 3 - Accept One-Time Data Loss:**
Requirements mention "one final data loss to transition to the new system" (line 109). Should we just:
1. Drop all tables if grdb_migrations doesn't exist
2. Run all migrations from scratch
3. Document this as a breaking change

**Which approach?** Requirements must specify.

**Testing Strategy Review:**

**Automated Test Coverage: INSUFFICIENT DETAIL**

Requirements list test scenarios (lines 60-66) but don't specify:

**Missing Test Specifications:**

1. **"Test upgrade from current schema" - HOW?**
   - Create a database file with current schema manually?
   - Use GRDB to create tables, then reset grdb_migrations?
   - Copy a pre-existing database file into test bundle?

2. **"Test migration failure handling" - WHAT EXACTLY?**
   - Inject a failure in migration code?
   - Verify rollback occurred?
   - Verify error message?
   - Verify database state is consistent?

3. **"Verify data preservation across migrations" - SPECIFICS?**
   - Insert test data before migration?
   - Run migration?
   - Query data after migration?
   - Which tables/data should be tested?

**Test Case Scenarios Needed:**

The requirements should specify these test cases:

| Test Case | Setup | Expected Outcome | Specified? |
|-----------|-------|------------------|------------|
| TC1: Fresh install | Empty database | All tables created via v1 | YES |
| TC2: Existing current schema | 5 tables + no metadata | v1 marked applied, no data loss | PARTIAL |
| TC3: Empty with metadata | grdb_migrations exists but no tables | **?** | NO |
| TC4: Partial schema | 3 of 5 tables exist | **?** | NO |
| TC5: V1 already applied | grdb_migrations has "v1" | Skip v1 | IMPLIED |
| TC6: Future migration | v1 applied, register v2 | v2 runs, v1 skipped | IMPLIED |
| TC7: Migration fails | Inject error in migration | Rollback, clear error | PARTIAL |
| TC8: All tests pass after migration | Current test suite | No regressions | YES |

**Testing Tools:**

Requirements don't specify if we need:
- In-memory database for tests (faster, no file I/O)
- Temporary database files (more realistic)
- Test fixtures with pre-created database states

**Recommendation:** Add detailed test implementation plan

**Critical Questions - Answers Required Before Development:**

**1. State Detection: How do we reliably detect whether a database has the current schema vs. is empty vs. is from an old version?**

**Answer Required:** Specify exact detection logic
- Check table existence only? (current approach)
- Check schema structure? (columns, constraints, indexes)
- Add schema version marker? (new table)
- Accept that any existing database without grdb_migrations gets dropped? (simplest)

**2. Migration Metadata: Where does GRDB store migration metadata? Can we inspect it to verify which migrations have been applied?**

**Answer:** GRDB stores metadata in `grdb_migrations` table with columns `identifier` (TEXT PRIMARY KEY)
- Can query: `SELECT identifier FROM grdb_migrations`
- Can check: `migrator.appliedIdentifiers(dbQueue)`
- This is handled automatically by GRDB

**3. Failure Recovery: If a migration fails halfway through, what state is the database in? How does the user recover?**

**Answer (Technical):** GRDB uses transactions, so failed migrations are automatically rolled back. Database remains in pre-migration state.

**Answer Required (UX):** What should the app do?
- Show error alert to user?
- Delete database and start fresh?
- Retry migration?
- Log error and continue with old schema?

**4. Testing Fresh vs. Existing: How do we test the "existing database" path in automated tests without manually creating old database files?**

**Answer Required:** Specify test setup approach
- Option A: Create tables manually in test, then run migrator
- Option B: Include pre-created database files in test bundle
- Option C: Use helper to create "legacy" database state
- Option D: Test with grdb_migrations table deletion to simulate legacy state

**5. One-time Transition: The requirements say "one final data loss" is acceptable to transition to the new system. Should we document this for users, or handle it silently?**

**Answer Required:**
- If accepting data loss: Document as breaking change in release notes
- If preserving data: Must implement reliable detection + conditional migration
- Current requirements are ambiguous on this critical decision

**Issues Found:**

- requirements.md:43-44 - "Existing database (current schema)" scenario lacks implementation specification for "marks v1 as applied"
- requirements.md:99-105 - Edge cases listed but handling strategies not specified
- requirements.md:60-66 - Testing requirements lack implementation details
- requirements.md:109-110 - "One final data loss" statement contradicts requirement #6 "No data loss during schema evolution"
- requirements.md:70 - References "Resources/schema.sql" but actual path is "database/schema.sql" (minor)

**Suggestions for Improvement:**

1. **Add State Transition Table** with detection logic and actions for each state
2. **Specify backward compatibility implementation** - choose one approach:
   - Simple: Drop all non-migrated databases (accept one-time data loss)
   - Complex: Detect current schema + manually mark v1 applied
3. **Add detailed test specifications** for each scenario
4. **Clarify data loss policy** - is "one final data loss" acceptable or not?
5. **Add schema validation strategy** if choosing to preserve existing databases
6. **Specify error handling UX** for migration failures
7. **Consider adding schema version metadata table** for future robustness

**Security/Performance Concerns:**

**Security:**
- No SQL injection concerns (using GRDB's safe API)
- Foreign key constraints properly maintained during migration

**Performance:**
- Migration runs in transaction (atomic, rollback on failure)
- Indexes preserved/recreated as part of schema
- First migration (v1) creates all tables - acceptable for fresh install
- Future migrations should be incremental (properly scoped)

**Correctness Concerns:**
- **CRITICAL:** Ambiguous backward compatibility may cause data loss or app crashes
- Schema validation insufficient (checks existence, not structure)
- Partial database state handling not specified

**Best Practice Violations:**

**None Identified** - Requirements follow GRDB best practices for migrations

**However, missing specifications could lead to implementation issues:**
- State machine should be fully specified before coding (as per Baton System README)
- Edge case handling should have explicit specifications
- Test cases should have setup/teardown/assertion details

**Positive Observations:**

1. **Problem clearly identified** - Data loss is unacceptable for production
2. **Appropriate solution chosen** - GRDB DatabaseMigrator is the correct tool
3. **Success criteria are measurable** - Can verify with tests
4. **Code locations specified** - Easy for developers to find what to change
5. **Logging requirements included** - Uses NSLog for debugging
6. **Future-proof design** - Supports adding new migrations easily
7. **Realistic complexity estimate** - MEDIUM is accurate
8. **Priority justified** - HIGH priority for production readiness is correct
9. **Non-requirements clearly stated** - No rollback, no data migration from old system

**Recommendations for Next Steps:**

**DO NOT SEND TO DEV YET - Requirements need updates**

**Required Changes Before Development:**

1. **Add "State Machine Specification" Section**
   - Table of all states (empty, current-schema, migrated, partial, corrupted)
   - Detection logic for each state
   - Action/handling for each state
   - Transition diagram would be helpful

2. **Specify Backward Compatibility Approach** - Choose ONE:
   - **Option A - Simple:** Any database without grdb_migrations → drop all tables → recreate via migrations
     - Document as breaking change
     - One-time data loss accepted
     - Simplest implementation

   - **Option B - Complex:** Detect current schema → manually mark v1 applied → preserve data
     - Requires schema validation logic
     - Higher risk of bugs
     - Zero data loss

   **Recommendation:** Option A (simple) aligns with "one final data loss" statement and reduces complexity

3. **Add Detailed Test Specifications**
   - For each test scenario: setup steps, action, expected outcome, validation
   - Specify test database setup approach (in-memory, temp files, fixtures)

4. **Clarify Data Loss Policy**
   - Either remove "no data loss" from requirements OR remove "one final data loss" statement
   - These are contradictory
   - Recommendation: Accept one-time data loss for transition, then zero data loss for future migrations

5. **Add Error Handling Specification**
   - What happens if migration fails? (user experience)
   - What error messages to show?
   - Should app delete database and retry?

6. **Update File Path Reference**
   - Line 115: "Resources/schema.sql" should be "database/schema.sql"

**After Updates:**
- Send back to project planner for review of changes
- Then send to dev for implementation

**Blockers/Questions:**

**Question for Product/Planning:**

The requirements contain a fundamental contradiction:

- Requirement #6 (line 96): "No data loss during schema evolution"
- Non-requirement (line 109): "Current users in development phase are okay with one final data loss"

**Which is correct?**

**If "no data loss":**
- Must implement complex schema detection
- Must validate existing schema structure
- Must handle edge cases carefully
- Higher implementation risk

**If "one final data loss acceptable":**
- Can use simple approach: drop any non-migrated database
- Lower implementation risk
- Clear user communication needed
- Aligns with "development phase" statement

**Recommendation:** Clarify with product owner before proceeding. Suggest accepting one-time data loss for simplicity and reliability.

**When proceeding with this work, remember to read your README.md as crucial process requirements are documented there.**
