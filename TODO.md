# TODO

## Bugs

- **Focus mode item creation issue**: When a folder is focused and you use a shortcut key (T, N, F, P, E) to create a new item, the newly created item is not visible in the focused view. The item is created with its name field in editing mode (blinking cursor), but it's outside the focused subtree. While in this state, keyboard shortcuts don't work and give error beeps (including arrow keys). The user must unfocus to see the created item and regain keyboard functionality.

- **Desktop doesn't refresh after sync**: The macOS desktop version doesn't refresh the page/view after CloudKit sync completes. Users need to manually trigger a refresh to see updated data.

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

## iOS Version

- Develop iOS companion app (see iOS-PROPOSAL.md for phases)

## Custom Shortcuts

- Allow users to bind keyboard shortcuts to saved searches and template instantiation commands.
  - Shortcut editor UI in Settings that lists available actions (specific saved searches, specific templates) and lets users assign system-wide key combos.
  - Persist shortcut mappings in `app_settings` (or a new table) and load them at launch.
  - Detect conflicts with existing/default shortcuts and provide inline warnings.
  - Include support for triggering shortcuts even when the search or template panel is not open, with visual feedback that the action ran.

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
