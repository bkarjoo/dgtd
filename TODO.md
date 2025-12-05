# TODO

## CloudKit Sync

Bi-directional sync between local SQLite (via GRDB) and CloudKit private database, enabling data to sync across Mac and future iOS devices.

### Strategy
- **Private database** with custom zone for all user data
- **Full bi-directional sync** with offline support
- **Last-write-wins** conflict resolution (using `modified_at` timestamps on all tables)
- **Change tracking** via local `needs_push` flag + CloudKit change tokens
- **Tombstone lifecycle**: Mark `needs_push=1` on delete, flip to `needs_push=0` after CloudKit confirms, purge after 30 days

### Configuration
- Container ID: `iCloud.com.directgtd`
- Zone name: `DirectGTDZone`
- Sync targets: items, tags, item_tags, time_entries, saved_searches

### Schema Changes (Migration v9)

```sql
-- ============================================
-- PART 1: Add modified_at to tables missing it
-- ============================================

-- item_tags needs timestamps for conflict resolution
ALTER TABLE item_tags ADD COLUMN created_at INTEGER;
ALTER TABLE item_tags ADD COLUMN modified_at INTEGER;
UPDATE item_tags SET created_at = strftime('%s', 'now'), modified_at = strftime('%s', 'now') WHERE created_at IS NULL;

-- time_entries needs modified_at (already has started_at but not modified_at)
ALTER TABLE time_entries ADD COLUMN modified_at INTEGER;
UPDATE time_entries SET modified_at = COALESCE(ended_at, started_at) WHERE modified_at IS NULL;

-- ============================================
-- PART 2: Add sync tracking columns to all tables
-- ============================================

-- items: sync fields
ALTER TABLE items ADD COLUMN ck_record_name TEXT;
ALTER TABLE items ADD COLUMN ck_change_tag TEXT;
ALTER TABLE items ADD COLUMN needs_push INTEGER DEFAULT 1;  -- 1 = dirty, 0 = synced
ALTER TABLE items ADD COLUMN deleted_at INTEGER;  -- NULL = not deleted, timestamp = soft-deleted

-- tags: sync fields
ALTER TABLE tags ADD COLUMN ck_record_name TEXT;
ALTER TABLE tags ADD COLUMN ck_change_tag TEXT;
ALTER TABLE tags ADD COLUMN needs_push INTEGER DEFAULT 1;
ALTER TABLE tags ADD COLUMN deleted_at INTEGER;
ALTER TABLE tags ADD COLUMN created_at INTEGER;
ALTER TABLE tags ADD COLUMN modified_at INTEGER;
UPDATE tags SET created_at = strftime('%s', 'now'), modified_at = strftime('%s', 'now') WHERE created_at IS NULL;

-- item_tags: sync fields
ALTER TABLE item_tags ADD COLUMN ck_record_name TEXT;
ALTER TABLE item_tags ADD COLUMN ck_change_tag TEXT;
ALTER TABLE item_tags ADD COLUMN needs_push INTEGER DEFAULT 1;
ALTER TABLE item_tags ADD COLUMN deleted_at INTEGER;

-- time_entries: sync fields
ALTER TABLE time_entries ADD COLUMN ck_record_name TEXT;
ALTER TABLE time_entries ADD COLUMN ck_change_tag TEXT;
ALTER TABLE time_entries ADD COLUMN needs_push INTEGER DEFAULT 1;
ALTER TABLE time_entries ADD COLUMN deleted_at INTEGER;

-- saved_searches: sync fields (already has created_at, modified_at)
ALTER TABLE saved_searches ADD COLUMN ck_record_name TEXT;
ALTER TABLE saved_searches ADD COLUMN ck_change_tag TEXT;
ALTER TABLE saved_searches ADD COLUMN needs_push INTEGER DEFAULT 1;
ALTER TABLE saved_searches ADD COLUMN deleted_at INTEGER;

-- ============================================
-- PART 3: Unique indexes on ck_record_name
-- ============================================

CREATE UNIQUE INDEX idx_items_ck_record_name ON items(ck_record_name) WHERE ck_record_name IS NOT NULL;
CREATE UNIQUE INDEX idx_tags_ck_record_name ON tags(ck_record_name) WHERE ck_record_name IS NOT NULL;
CREATE UNIQUE INDEX idx_item_tags_ck_record_name ON item_tags(ck_record_name) WHERE ck_record_name IS NOT NULL;
CREATE UNIQUE INDEX idx_time_entries_ck_record_name ON time_entries(ck_record_name) WHERE ck_record_name IS NOT NULL;
CREATE UNIQUE INDEX idx_saved_searches_ck_record_name ON saved_searches(ck_record_name) WHERE ck_record_name IS NOT NULL;

-- ============================================
-- PART 4: Indexes for efficient dirty queries
-- ============================================

CREATE INDEX idx_items_needs_push ON items(needs_push) WHERE needs_push = 1;
CREATE INDEX idx_tags_needs_push ON tags(needs_push) WHERE needs_push = 1;
CREATE INDEX idx_item_tags_needs_push ON item_tags(needs_push) WHERE needs_push = 1;
CREATE INDEX idx_time_entries_needs_push ON time_entries(needs_push) WHERE needs_push = 1;
CREATE INDEX idx_saved_searches_needs_push ON saved_searches(needs_push) WHERE needs_push = 1;

-- ============================================
-- PART 5: Sync metadata table
-- ============================================

CREATE TABLE sync_metadata (
    key TEXT PRIMARY KEY,
    value BLOB  -- Stores serialized data (change tokens, timestamps)
);
-- Keys:
--   'zone_change_token'      - CKServerChangeToken (archived NSData)
--   'database_change_token'  - CKServerChangeToken (archived NSData)
--   'last_push_timestamp'    - Unix timestamp
--   'last_pull_timestamp'    - Unix timestamp
--   'initial_sync_complete'  - '1' or '0'

-- ============================================
-- PART 6: Remove CASCADE deletes (new table structure)
-- ============================================

-- Recreate item_tags without CASCADE (soft-delete aware, FK still enforced)
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
);
INSERT INTO item_tags_new SELECT item_id, tag_id, created_at, modified_at, ck_record_name, ck_change_tag, needs_push, deleted_at FROM item_tags;
DROP TABLE item_tags;
ALTER TABLE item_tags_new RENAME TO item_tags;
CREATE UNIQUE INDEX idx_item_tags_ck_record_name ON item_tags(ck_record_name) WHERE ck_record_name IS NOT NULL;
CREATE INDEX idx_item_tags_needs_push ON item_tags(needs_push) WHERE needs_push = 1;

-- Recreate time_entries without CASCADE (FK preserved)
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
);
INSERT INTO time_entries_new SELECT id, item_id, started_at, ended_at, duration, modified_at, ck_record_name, ck_change_tag, needs_push, deleted_at FROM time_entries;
DROP TABLE time_entries;
ALTER TABLE time_entries_new RENAME TO time_entries;
CREATE UNIQUE INDEX idx_time_entries_ck_record_name ON time_entries(ck_record_name) WHERE ck_record_name IS NOT NULL;
CREATE INDEX idx_time_entries_needs_push ON time_entries(needs_push) WHERE needs_push = 1;
CREATE INDEX idx_time_entries_item_id ON time_entries(item_id);
CREATE INDEX idx_time_entries_started_at ON time_entries(started_at);

-- Recreate items without CASCADE on parent_id (FK preserved)
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
);
INSERT INTO items_new SELECT id, title, item_type, notes, parent_id, sort_order, created_at, modified_at, completed_at, due_date, earliest_start_time, ck_record_name, ck_change_tag, needs_push, deleted_at FROM items;
DROP TABLE items;
ALTER TABLE items_new RENAME TO items;
CREATE UNIQUE INDEX idx_items_ck_record_name ON items(ck_record_name) WHERE ck_record_name IS NOT NULL;
CREATE INDEX idx_items_needs_push ON items(needs_push) WHERE needs_push = 1;
CREATE INDEX idx_parent_id ON items(parent_id);

-- ============================================
-- PART 7: Bootstrap existing data for first sync
-- ============================================

-- Assign deterministic ck_record_name based on existing id (prevents duplicates on first sync)
UPDATE items SET ck_record_name = 'Item_' || id WHERE ck_record_name IS NULL;
UPDATE tags SET ck_record_name = 'Tag_' || id WHERE ck_record_name IS NULL;
UPDATE item_tags SET ck_record_name = 'ItemTag_' || item_id || '_' || tag_id WHERE ck_record_name IS NULL;
UPDATE time_entries SET ck_record_name = 'TimeEntry_' || id WHERE ck_record_name IS NULL;
UPDATE saved_searches SET ck_record_name = 'SavedSearch_' || id WHERE ck_record_name IS NULL;

-- All existing data needs initial push
UPDATE items SET needs_push = 1;
UPDATE tags SET needs_push = 1;
UPDATE item_tags SET needs_push = 1;
UPDATE time_entries SET needs_push = 1;
UPDATE saved_searches SET needs_push = 1;
```

### Sync Status Flow

```
Local Create/Update → needs_push = 1, modified_at = now()
                           ↓
              Push to CloudKit succeeds
                           ↓
         needs_push = 0, ck_change_tag updated

Local Delete → deleted_at = now(), needs_push = 1
                           ↓
              Push deletion to CloudKit succeeds
                           ↓
         needs_push = 0 (tombstone stays for 30 days, then purged)

Remote Change Pulled → Update local row, needs_push = 0
```

### Conflict Resolution (Last-Write-Wins)

All synced tables have `modified_at` timestamps. When pushing and CloudKit returns `CKError.serverRecordChanged`:
1. Fetch the server record's `modifiedAt` field
2. Compare with local `modified_at`
3. If local is newer: retry push using server's `ck_change_tag` as baseline
4. If server is newer: accept server version, update local, set `needs_push = 0`

### Soft-Delete Rules

Since CASCADE is removed, application code must enforce tombstone cascades:
1. Item delete: soft-delete the item + all descendants recursively, plus related `item_tags` and `time_entries`
2. Tag delete: soft-delete the tag and every `item_tags` row referencing it
3. Tombstone purge job: only purge rows where `deleted_at < (now - 30 days)` AND `needs_push = 0`
4. Before purging a parent item: verify all children and dependents are already purged

### New Files

| File | Purpose |
|------|---------|
| `CloudKitManager.swift` | Container setup, zone creation, account status |
| `SyncEngine.swift` | Orchestrates push/pull, dirty tracking, conflict resolution |
| `CKRecordConverters.swift` | Item/Tag/TimeEntry ↔ CKRecord mapping |
| `SyncMetadataStore.swift` | Persist/retrieve change tokens and sync timestamps |
| `SoftDeleteService.swift` | Cascade soft-deletes, tombstone purge job |
| `DirectGTD.entitlements` | iCloud capabilities |

### Implementation Phases

#### Phase 1: Foundation
- [ ] Add entitlements and CloudKit container in Xcode
- [ ] Schema migration v9 with all sync fields, timestamps, indexes, and CASCADE removal
- [ ] Update Models.swift with sync fields (ckRecordName, ckChangeTag, needsPush, deletedAt, modifiedAt)
- [ ] SoftDeleteService: cascade soft-deletes for items (children, item_tags, time_entries) and tags (item_tags)
- [ ] Update all repository methods to filter out deleted_at IS NOT NULL
- [ ] Ensure every write path (or DB trigger) updates `modified_at` and flips `needs_push` appropriately
- [ ] SyncMetadataStore: save/load change tokens and timestamps

#### Phase 2: Core Sync
- [ ] CloudKitManager: zone setup, ensure zone exists, check account status
- [ ] CKRecord converters for all 5 record types (with modifiedAt mapping)
- [ ] Push engine: query dirty records (needs_push = 1), batch upload, set needs_push = 0 on success
- [ ] Pull engine: fetch changes using stored zone change token, apply to local DB
- [ ] Conflict resolution with last-write-wins using modified_at
- [ ] Handle deletions: push CKRecord deletions for deleted_at rows, then set needs_push = 0

#### Phase 3: Real-time
- [ ] CloudKit subscriptions (CKDatabaseSubscription) for push notifications
- [ ] Handle remote notifications to trigger pull
- [ ] Sync status UI indicator in toolbar (syncing/synced/error)
- [ ] Automatic retry with exponential backoff on transient errors

#### Phase 4: Polish
- [ ] Initial sync progress UI for first-time sync
- [ ] Tombstone cleanup job (purge where deleted_at > 30 days AND needs_push = 0)
- [ ] Manual "Sync Now" menu item
- [ ] Sync settings in preferences (enable/disable, account info)
- [ ] Handle iCloud account changes (sign out, switch accounts)

---

# Other

## Bugs

- **Focus mode item creation issue**: When a folder is focused and you use a shortcut key (T, N, F, P, E) to create a new item, the newly created item is not visible in the focused view. The item is created with its name field in editing mode (blinking cursor), but it's outside the focused subtree. While in this state, keyboard shortcuts don't work and give error beeps (including arrow keys). The user must unfocus to see the created item and regain keyboard functionality.

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
