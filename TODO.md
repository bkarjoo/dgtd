# TODO

## Distribution

- Create proper .dmg installer for macOS
  - Archive build with proper signing
  - Create .dmg with background image
  - Include Applications folder symlink for drag-and-drop installation
  - Code signing and notarization for distribution outside App Store

## Archive Functionality

- Archive folder setting (already implemented in SettingsView)
  - Stored in `app_settings` table with key `archive_folder_id`
  - Picker in Settings to select which folder serves as the archive
- Move items to archive
  - Keyboard shortcut or context menu action to move selected item(s) to the archive folder
  - Moves item and all descendants to the archive folder as children
  - Preserves item hierarchy within the archive
- Move items out of archive to root
  - Action to "unarchive" items, moving them from archive folder to root level
  - Should work on selected item(s) when viewing archive contents
  - Maintains sort order when moving to root
- Hide/show archive folder
  - Setting or toolbar toggle to hide the archive folder from the tree view
  - When hidden, archive folder and its contents are not visible
  - When shown, archive folder appears like any other folder
  - State persists across app restarts (stored in UserSettings or app_settings)

## Templates

- Template items can be instantiated into the tree along with their entire descendant hierarchy.
  - Decide whether templates live in the main tree or a dedicated Templates area, and add UI affordances for browsing them.
  - Provide "Create from Template" entry points (context menu, toolbar, quick capture) that prompt for the destination and optional renaming.
  - When instantiating, clone all descendants, preserving structure, tags, notes, and relative sort orders.
  - Consider placeholders/variables for due dates or titles so template instances can adapt at creation time.

## Custom Shortcuts

- Allow users to bind keyboard shortcuts to saved searches and template instantiation commands.
  - Shortcut editor UI in Settings that lists available actions (specific saved searches, specific templates) and lets users assign system-wide key combos.
  - Persist shortcut mappings in `app_settings` (or a new table) and load them at launch.
  - Detect conflicts with existing/default shortcuts and provide inline warnings.
  - Include support for triggering shortcuts even when the search or template panel is not open, with visual feedback that the action ran.

## SQL Search Mode Requirements

- Scope: Replace SmartFolders entirely with a SQL-driven search mode that overlays the existing list, similar to the current tag filter; no new
  item types or tree nodes.
- Invocation & Indicator
    - A magnifying-glass icon sits with the tag filter icon; clicking it enters search mode and opens the search dialog.
    - While a search is active, the icon shows a filled blue background as the affordance that filtering is applied.
    - Clicking the filled icon again reopens the dialog pre-populated with the active query so it can be tweaked or rerun.
    - SQL search and tag filter are mutually exclusive: activating one clears the other.
- Search Dialog
    - Provides a multi-line monospaced SQL editor, Run button, Cancel button, and Clear button.
    - Run executes the SQL, applies the results to the main list (same area used for tag filtering), and closes the dialog. Cancel closes the dialog
      without changing mode. Clear exits search mode entirely, removes the filter, and closes the dialog.
    - Errors from SQLite are surfaced inline with the message and line number when available.
    - Dialog closes automatically after Run; click the filled icon to reopen and modify the query.
- Saved Searches
    - Dialog includes "Save Search…" button that captures a user-provided name + SQL, stored for later reuse; saving immediately runs the query
      and closes the dialog.
    - All saved searches are displayed as a clickable list below the SQL editor within the same dialog; clicking a saved search populates the
      editor with its SQL (does not auto-run, allowing user to modify before clicking Run).
    - Provide "Manage Saved Searches" under Settings next to "Manage Tags" for viewing, renaming, reordering, and deleting saved entries.
- Storage
    - Add a `saved_searches` table: `id` TEXT PK, `name` TEXT NOT NULL, `sql` TEXT NOT NULL, `sort_order` INTEGER, timestamps.
    - Persist the active ad-hoc search (if any) in app settings so a relaunch can restore it with the icon highlighted.
- Query Execution
    - Raw SQL is executed exactly as entered but must be read-only:
        - Reject anything that isn't a single SELECT statement; disallow multiple statements, ATTACH, PRAGMA writes, or DDL/DML.
        - Execute via a dedicated read-only connection/context with a short timeout (~250 ms) so pathological queries cannot freeze the UI.
        - Provide documented helpers (strftime, etc.) instead of bound parameters; we rely on users writing valid SQLite syntax.
    - The query's first column must be `id` values from `items`; extra columns are ignored.
    - Results populate the same list view used elsewhere, so standard selection/edit commands continue to operate on the returned items.
- UX Parity with Tag Filter
    - Search mode behaves like tag filtering: selecting rows shows filtered results, and leaving search mode returns to the previous list.
    - Only one saved search (or the ad-hoc editor contents) can be active at any time; no multi-select.
- Testing
    - Unit coverage for read-only enforcement, timeout behavior, SQL error surfacing, saved-search CRUD, and persistence of the active query.
    - Integration test to ensure toggling the icon, running a query, clearing it, and switching between saved searches works along with tag filters.
- Docs
    - Update help/README to explain SQL search mode, how to invoke it, how to save/manage searches, and reiterate the SELECT-only rule.

## Search Query Help Reference

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
