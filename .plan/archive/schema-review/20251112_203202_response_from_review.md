**Important: Read `README.md` first to understand your role and workflow before starting this assignment.**

**Status:** Needs Changes

**Overall Assessment:**
The folders table and overall schema show a good foundation for a GTD application with hierarchical folder organization. However, there are several critical issues that need addressing, particularly around data integrity, circular reference prevention, and schema consistency between the two file locations.

**Issues Found:**

**HIGH PRIORITY:**
- **database/schema.sql:73-79** - Missing indexes for folders table that exist in DirectGTD/database/schema.sql. The secondary schema file is missing `idx_folders_parent_id` and `idx_folders_sort_order` indexes, creating inconsistency.
- **DirectGTD/database/schema.sql:15** - No circular reference prevention for folder hierarchy. A folder could potentially become its own ancestor through a chain of parent_id references.
- **DirectGTD/database/schema.sql:28** - Status field lacks CHECK constraint to validate allowed values (next_action, waiting, someday, completed).
- **DirectGTD/database/schema.sql:41** - Energy level field lacks CHECK constraint for valid values (high, medium, low).

**MEDIUM PRIORITY:**
- **DirectGTD/database/schema.sql:4-16** - No unique constraint on (name, parent_id) combination, allowing duplicate folder names at the same hierarchy level.
- **DirectGTD/database/schema.sql:30** - Context field is not normalized; frequent values like @home, @work would benefit from a separate contexts table.
- **Schema versioning missing** - No schema_version table to track migrations and schema evolution.

**LOW PRIORITY:**
- **DirectGTD/database/schema.sql:11** - is_expanded field uses BOOLEAN type which SQLite stores as INTEGER (0/1); consider explicit INTEGER with CHECK constraint for clarity.

**Suggestions for Improvement:**

1. **Add CHECK constraints for enums:**
   ```sql
   status TEXT DEFAULT 'next_action' CHECK(status IN ('next_action', 'waiting', 'someday', 'completed'))
   energy_level TEXT CHECK(energy_level IN ('high', 'medium', 'low') OR energy_level IS NULL)
   ```

2. **Add unique constraint for folder names:**
   ```sql
   UNIQUE(name, parent_id)
   ```

3. **Consider normalizing contexts:**
   ```sql
   CREATE TABLE contexts (
       id TEXT PRIMARY KEY,
       name TEXT NOT NULL UNIQUE,
       icon TEXT
   );
   ```

4. **Add schema version tracking:**
   ```sql
   CREATE TABLE schema_version (
       version INTEGER PRIMARY KEY,
       applied_at INTEGER NOT NULL
   );
   ```

**Security/Performance Concerns:**

1. **Circular Reference Vulnerability** - The self-referencing parent_id in folders table could create infinite loops in recursive queries. Implement application-level validation or triggers to prevent circular references.

2. **Index Coverage** - Current indexes are good for common queries, but consider composite indexes:
   - `CREATE INDEX idx_items_folder_status ON items(folder_id, status)` for filtering by folder and status
   - `CREATE INDEX idx_items_status_context ON items(status, context)` for GTD workflow queries

3. **Missing timestamp validation** - No guarantee that modified_at >= created_at

**Best Practice Violations:**

1. **Inconsistent schema files** - Having two different versions of schema.sql creates deployment and maintenance risks
2. **TEXT type for IDs** - While valid, consider documenting the ID generation strategy (UUID, ULID, etc.)
3. **No CASCADE options review** - folder_id uses SET NULL while parent_id uses CASCADE; document the reasoning

**Positive Observations:**

- Good use of foreign key constraints with appropriate CASCADE behaviors
- Clear separation of concerns (items, notes, tags)
- Thoughtful GTD-specific fields (status, context, energy_level)
- Well-structured many-to-many relationship for tagging system
- Appropriate use of INTEGER for Unix timestamps
- Good indexing strategy for most common queries

**Recommendations for Next Steps:**

1. **IMMEDIATE**: Synchronize both schema files and add missing indexes
2. **HIGH**: Implement CHECK constraints for enum fields
3. **HIGH**: Add circular reference prevention (trigger or application logic)
4. **MEDIUM**: Consider normalizing contexts into separate table
5. **MEDIUM**: Add schema versioning mechanism
6. **LOW**: Document ID generation strategy and timestamp format

**When proceeding with this work, remember to read your README.md as crucial process requirements are documented there.**