# DirectGTD Data Policy

## 1. Purpose
This document defines the shared data policy for every DirectGTD surface (macOS, iOS, MCP tooling, automation). All components **must** adhere to these rules when reading, writing, or syncing the project database to guarantee deterministic behavior, safe collaboration, and a single source of truth for CloudKit.

## 2. Source of Truth
| Layer | Responsibility |
| --- | --- |
| SQLite (`directgtd.sqlite`) | Canonical local store for each client. |
| CloudKit Zone (`iCloud.com.directgtd/DirectGTDZone`) | Cross-device replication layer. |
| App settings (`app_settings` table) | Device-scoped settings. Currently *not* synced. |

### Schema Versioning
* macOS owns the master schema (`database/schema.sql`) and migration sequence (`DirectGTD/Database.swift`).
* iOS maintains a parallel migrator that must mirror macOS. New tables/columns require migrations on **both** platforms **before** usage.
* MCP tooling must target the latest schema; if it writes to a newer version it must also bundle the matching migrations.

## 3. Tables & Policies
| Table | Key Columns | Policy Highlights |
| --- | --- | --- |
| `items` | `id`, hierarchy fields, timeline fields, CloudKit metadata | All CRUD operations must set `modified_at`, respect `needs_push`, and treat `deleted_at` as the soft-delete flag. |
| `tags` | `id`, `name`, metadata | Same soft-delete rules as `items`. |
| `item_tags` | Composite key, timestamps, CloudKit fields | Entries are immutable aside from timestamps; deletions use `deleted_at`. |
| `time_entries` | Timing data + CloudKit metadata | `modified_at` required for conflict resolution. |
| `saved_searches` | Definition fields + metadata | Mutations always bump `modified_at` and `needs_push`. |
| `sync_metadata` | Key/value | Stores change tokens, last sync times, device flags. Never synced to CloudKit. |
| `app_settings` | Key/value | Device-local preferences (e.g., `quick_capture_folder_id`). Not synced; each device may store different values. |

### CloudKit Metadata Columns
All syncable tables share:
* `ck_record_name`: globally unique record identifier (e.g., `Item_<uuid>`).
* `ck_change_tag`: last known change tag from CloudKit; updated after successful push/pull.
* `ck_system_fields`: archived record system fields; required to preserve change tags.
* `needs_push`: `1` when a record must be uploaded; `0` after success.
* `deleted_at`: soft-delete timestamp. A non-null value marks the record as deleted locally and for CloudKit.

## 4. CRUD Rules
1. **Create**
   * Generate a UUID for `id`.
   * Set `created_at = modified_at = now`.
   * Assign `ck_record_name` if absent (e.g., `Item_<id>`).
   * Set `needs_push = 1` and `deleted_at = NULL`.
2. **Update**
   * Any user-visible change **must** update `modified_at` and `needs_push = 1`.
   * Preserve `ck_record_name`, `ck_change_tag`, `ck_system_fields` unless a push conflict instructs otherwise.
3. **Delete**
   * Use soft deletes: set `deleted_at = now`, `needs_push = 1`.
   * Push logic MUST send the record ID in `recordIDsToDelete`. On success, keep the row (for audit) with `needs_push = 0`.
   * Cleanup jobs may purge rows where `deleted_at` is older than the retention window and `needs_push = 0`.

## 5. Sync Pipeline
### Push (macOS & iOS)
1. Fetch all rows with `needs_push = 1`.
2. Build `CKRecord`s for non-deleted rows and `CKRecord.ID`s for deleted rows.
3. Use `CKModifyRecordsOperation` (non-atomic) with chunk size ≤ 400.
4. After each batch:
   * Persist new `ck_change_tag` + `ck_system_fields`.
   * Set `needs_push = 0`.
   * For deletes, clear `ck_change_tag`/`ck_system_fields` locally (row stays tombstoned).
5. Conflict handling:
   * macOS: last-write-wins (local compare vs. server `modifiedAt`).
   * iOS (read-only by default): server wins; local row replaced with server version.
   * MCP tooling must follow macOS semantics.

### Pull
1. Use stored `CKServerChangeToken`; fall back to full fetch when nil/expired or zone missing.
2. Loop while `moreComing` is true:
   * Apply changed records.
   * Apply deletions: if CloudKit supplies `recordType`, soft-delete the matching table; otherwise, run the delete across **all** tables that contain `ck_record_name`.
   * Persist the new change token after each batch.
3. Change-token invalidation (`.changeTokenExpired`):
   * Clear stored token.
   * Download a full snapshot.
   * Wipe local syncable tables inside a transaction, then load the snapshot.
4. Zone recreation (`.zoneNotFound`):
   * Re-run CloudKit initialization to recreate the zone.
   * Perform a full fetch and replace local data.

### Ordering & Constraints
* Inserts must satisfy foreign keys:
  1. Tags
  2. Items (topologically sorted by `parentId`)
  3. ItemTags
  4. TimeEntries
  5. SavedSearches
* Deletions remove children last; if a CloudKit delete arrives for a parent with still-synced children, they must respect `ON DELETE NO ACTION` and stay orphaned until their own delete arrives.

## 6. Observability & Refresh
* All clients must watch `(COUNT(*), MAX(modified_at))` for relevant tables using `ValueObservation.tracking` (never `.trackingConstantRegion`) to guarantee refreshes after any write (including sync, MCP, or scripts).
* Observers must schedule UI updates on the main queue and cancel observers on teardown.

## 7. Platform-Specific Notes
### macOS
* Full read-write client.
* Maintains migrations `v1+`.
* Sync conflicts resolved locally via timestamp comparison.
* Offers UI to configure `quick_capture_folder_id` and other settings (stored in `app_settings`).

### iOS
* Local database mirrors macOS schema.
* Supports read-write for Quick Capture; any write must use the same CRUD rules.
* Sync triggers:
  * Launch, scene phase `active`, scene phase `background` (with `beginBackgroundTask`).
  * Explicit user actions (pull-to-refresh) call `syncAndReload()`.
* Observes the database to reload tree view automatically.
* Quick Capture folder:
  * Read `app_settings.quick_capture_folder_id`.
  * Fallback to folder named "Inbox".
  * Fallback to root when neither is available.

### MCP / Automation
* Must instantiate `ItemRepository` (or equivalent) and reuse its helper APIs.
* Forbidden to mutate tables directly without updating `modified_at`, `needs_push`, and CloudKit metadata.
* Must honor the same soft-delete and sync rules.

## 8. Testing & Verification
1. **Schema parity**: CI should verify that macOS and iOS migrations expose identical table definitions (e.g., `pragma table_info` diff).
2. **CRUD tests**: unit tests to ensure `needs_push`/`modified_at` update correctly on create/update/delete.
3. **Sync tests**:
   * Push of create/update/delete.
   * Pull applying changed/deleted records.
   * Token reset (expired token, zone recreation).
4. **Observer tests**: mutate the database via sync or repository call and assert UI refresh triggers.
5. **Data repair**: provide a script/tool to clear tokens, resync, and validate counts across devices.

## 9. Enforcement
* Any change touching schema, CRUD, or sync logic must reference this policy.
* Code reviews should reject updates that violate `needs_push`, `deleted_at`, or metadata requirements.
* Shared helpers (e.g., `ItemRepository`, `SyncEngine`, `CKRecordConverters`) are the authoritative implementation of these rules; platforms must not fork behavior without updating the policy & helpers simultaneously.
