# Issue: Database Schema Not Being Applied

## Problem Statement

The database schema.sql file is not being applied to the database on app launch, resulting in the seeding process failing with:

```
DirectGTDApp: Seeding error: SQLite error 1: no such table: folders - while executing SELECT * FROM "folders" ORDER BY "sort_order"
```

## Current Behavior

1. App launches successfully
2. Database.swift initializes and creates directgtd.sqlite in Documents directory
3. Database initialization reports "Database initialized"
4. However, the schema.sql is not being executed
5. When DatabaseSeeder tries to seed data, it fails because tables don't exist
6. App continues to run but with an empty/broken database

## Expected Behavior

1. App launches
2. Database.swift creates directgtd.sqlite
3. schema.sql is located in the app bundle
4. Schema is executed, creating all tables (folders, items, tags, notes, etc.)
5. DatabaseSeeder successfully seeds the database with sample data
6. App displays the seeded data in the UI

## Investigation Required

The review team should investigate:

1. **Is schema.sql included in the app bundle?**
   - Check if `database/schema.sql` is being copied to the app bundle during build
   - Verify it's in the "Copy Bundle Resources" build phase in Xcode

2. **Is the schema.sql path resolution working?**
   - The code uses `Bundle.main.url(forResource: "schema", withExtension: "sql")`
   - This might not find the file if it's not in the root of bundle resources
   - May need to check subdirectories or specify a bundle path

3. **Is the schema execution happening?**
   - Database.swift checks if tables exist before executing schema
   - If `items` table exists from a previous run, schema is skipped
   - But folders table is missing, suggesting partial/incomplete schema execution

4. **Is there an error being silently swallowed?**
   - Database.swift uses print() statements instead of NSLog()
   - These messages aren't appearing in system logs
   - Need to verify if setupDatabase() is actually being called and completing

## Edge Cases to Consider

- What happens on first launch vs subsequent launches?
- What happens if schema.sql is found but execution fails?
- What happens if the database file exists but is corrupted?
- Should we handle schema migrations in the future?

## Success Criteria

- schema.sql is located and loaded successfully
- All tables are created in the database
- DatabaseSeeder runs without errors
- App displays seeded folder data in the UI
- Appropriate logging shows all steps completed successfully
