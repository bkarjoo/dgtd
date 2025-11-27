# TODO

## Distribution

- Create proper .dmg installer for macOS
  - Archive build with proper signing
  - Create .dmg with background image
  - Include Applications folder symlink for drag-and-drop installation
  - Code signing and notarization for distribution outside App Store

## SmartFolders Requirements

- Scope: SmartFolders are items of type SmartFolder that display dynamic query results; target users are SQL-proficient, so UI is minimal.
- Storage
    - Add a smart_folder_query TEXT column (nullable) to items.
    - SmartFolder rows must have item_type = 'SmartFolder' and non‑NULL smart_folder_query.
    - Migration should leave existing data untouched; seeded SmartFolders will populate this column.
- Query Execution
    - Run the SQL exactly as stored, but enforce READ‑ONLY:
        - Use SQLite's authorizer (or simple parser) to reject any statement that isn't a single SELECT.
        - Disallow multiple statements, ATTACH, PRAGMA writes, etc.
        - Execute via a dedicated read-only connection/context with a short timeout (e.g., 250 ms) so expensive queries can't freeze the UI.
    - Parameters:
        - Provide ? bindings for dynamic values if needed (e.g., :now), or allow users to call strftime('%s','now') directly; document whichever
          approach is chosen.
    - Result set should be item IDs; if a query returns extra columns, ignore them.
- UI/UX
    - Tree view shows SmartFolders alongside other items (icon already defined).
    - Selecting a SmartFolder runs its query and displays the result list in the main pane; selection/edit commands operate on the result items.
    - SmartFolder editor:
        - Text field (multi-line, monospaced) for raw SQL.
        - "Test Query" button that runs the SQL and reports count + example item titles.
        - Error surface shows SQLite error message with line number if parse/run fails.
        - Collapsible "Schema Reference" panel listing tables/columns and common snippets (joins to item_tags, date helpers).
    - No GUI query builder—SQL is the only authoring method.
- Seeding
    - On first run (or via migration), insert a handful of SmartFolders with predefined SQL (Overdue, Due Today, Due This Week, Ready to Start,
      Completed) to serve as documentation/examples. Users can edit the SQL directly.
- Testing
    - Unit tests ensuring:
        - Non-SELECT queries (e.g., DELETE) are rejected.
        - Queries with syntax errors show the error and don't crash.
        - Sample queries return expected item IDs given synthetic data.
        - Performance: a pathological query times out and surfaces a friendly error.
    - Integration test verifying SmartFolder selection updates the visible list and honors tag/visibility rules if applicable.
- Docs
    - Update in-app help/README to explain SmartFolders, the schema snippet, and sample queries.
    - Call out that queries are raw SQLite and that only SELECT statements are allowed.

This keeps the feature power-user focused: raw SQL only, but safe, documented, and integrated with the existing item tree.

## SmartFolder Query Help Reference

### Available Tables

**items**
- `id` TEXT PRIMARY KEY
- `title` TEXT
- `item_type` TEXT (Unknown, Task, Project, Note, Folder, Template, SmartFolder, Alias, Heading, Link, Attachment, Event)
- `notes` TEXT
- `parent_id` TEXT
- `sort_order` INTEGER
- `created_at` INTEGER (Unix timestamp)
- `modified_at` INTEGER (Unix timestamp)
- `completed_at` INTEGER (Unix timestamp, NULL if not completed)
- `due_date` INTEGER (Unix timestamp)
- `earliest_start_time` INTEGER (Unix timestamp)

**tags**
- `id` TEXT PRIMARY KEY
- `name` TEXT
- `color` TEXT

**item_tags**
- `item_id` TEXT
- `tag_id` TEXT

**app_settings**
- `key` TEXT PRIMARY KEY
- `value` TEXT

### Common Query Patterns

**Overdue Tasks**
```sql
SELECT id FROM items
WHERE item_type = 'Task'
  AND completed_at IS NULL
  AND due_date < strftime('%s', 'now')
ORDER BY due_date ASC
```

**Due Today**
```sql
SELECT id FROM items
WHERE item_type = 'Task'
  AND completed_at IS NULL
  AND date(due_date, 'unixepoch') = date('now')
ORDER BY due_date ASC
```

**Due This Week**
```sql
SELECT id FROM items
WHERE item_type = 'Task'
  AND completed_at IS NULL
  AND due_date BETWEEN strftime('%s', 'now')
    AND strftime('%s', 'now', '+7 days')
ORDER BY due_date ASC
```

**Ready to Start** (no earliest start time or already started)
```sql
SELECT id FROM items
WHERE item_type = 'Task'
  AND completed_at IS NULL
  AND (earliest_start_time IS NULL OR earliest_start_time <= strftime('%s', 'now'))
ORDER BY due_date ASC
```

**Recently Completed** (last 7 days)
```sql
SELECT id FROM items
WHERE item_type = 'Task'
  AND completed_at >= strftime('%s', 'now', '-7 days')
ORDER BY completed_at DESC
```

**Items with Specific Tag**
```sql
SELECT i.id FROM items i
JOIN item_tags it ON i.id = it.item_id
JOIN tags t ON it.tag_id = t.id
WHERE t.name = 'Important'
ORDER BY i.modified_at DESC
```

**Untagged Items**
```sql
SELECT id FROM items
WHERE id NOT IN (SELECT item_id FROM item_tags)
  AND item_type IN ('Task', 'Project')
ORDER BY modified_at DESC
```

**Items Without Notes**
```sql
SELECT id FROM items
WHERE (notes IS NULL OR notes = '')
  AND item_type = 'Task'
ORDER BY created_at DESC
```

### Date/Time Helpers

- Current timestamp: `strftime('%s', 'now')`
- Today start: `strftime('%s', 'now', 'start of day')`
- Tomorrow: `strftime('%s', 'now', '+1 day')`
- Next week: `strftime('%s', 'now', '+7 days')`
- Date comparison: `date(timestamp, 'unixepoch') = date('now')`
- Format date: `datetime(timestamp, 'unixepoch')`

### Query Requirements

- Queries MUST be SELECT statements only
- Queries MUST return `id` as the first column (extra columns ignored)
- Query timeout: 250ms
- No multiple statements, no ATTACH, no PRAGMA writes
- Use `strftime('%s', 'now')` for current time (no bound parameters needed)
