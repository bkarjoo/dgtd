# DirectGTD API Server - Feature Request

**Date:** December 16, 2025
**Author:** MCP Integration Team
**Priority:** High

## Overview

The MCP server (`dmcp`) has been migrated to use the HTTP API instead of direct SQLite database access. This ensures proper soft-delete handling and data consistency. However, several MCP functions still require direct database queries because the API lacks certain endpoints.

This document outlines the missing API endpoints needed to complete the migration.

---

## Current API Coverage

The API server (`APIServer.swift`) currently supports:
- Item CRUD operations
- Tag CRUD operations
- Item-tag associations
- Timer start/stop/toggle
- Basic search
- SQL search
- Saved searches
- Sync/reload triggers

---

## Missing Endpoints

### 1. Archive Operations

**`POST /items/:id/archive`**
- Move an item to the configured archive folder
- Used by: `directgtd_archive_item`

---

### 2. Due Date Queries

**`GET /items/overdue`**
- Return items where `due_date < now` and not completed
- Query params: `include_completed`, `include_archive`
- Used by: `directgtd_get_overdue_items`

**`GET /items/due-today`**
- Return items due within today
- Query params: `include_completed`, `include_archive`
- Used by: `directgtd_get_due_today`

**`GET /items/due-tomorrow`**
- Return items due within tomorrow
- Query params: `include_completed`, `include_archive`
- Used by: `directgtd_get_due_tomorrow`

**`GET /items/due-this-week`**
- Return items due within current week (Sunday-Saturday)
- Query params: `include_completed`, `include_archive`
- Used by: `directgtd_get_due_this_week`

---

### 3. Task Status Queries

**`GET /tasks/available`**
- Return tasks ready to work on (not completed, not deferred)
- Query params: `parent_id`, `include_deferred`, `include_archive`
- Used by: `directgtd_get_available_tasks`

**`GET /tasks/deferred`**
- Return tasks with future `earliest_start_time`
- Query params: `parent_id`, `include_archive`
- Used by: `directgtd_get_deferred_tasks`

**`GET /tasks/completed`**
- Return completed tasks
- Query params: `parent_id`, `since` (ISO date), `limit`, `include_archive`
- Used by: `directgtd_get_completed_tasks`

**`GET /tasks/oldest`**
- Return oldest incomplete tasks (for finding neglected items)
- Query params: `limit`, `root_id`
- Excludes: Templates, Reference, Archive, Trash folders
- Used by: `directgtd_get_oldest_tasks`

---

### 4. GTD-Specific Endpoints

**`GET /dashboard`**
- Combined view of actionable items:
  - Items tagged "Next"
  - Items tagged "urgent"
  - Overdue items
- Used by: `directgtd_get_dashboard`

**`GET /projects/stuck`**
- Find projects without Next-tagged items (up to 2 levels deep)
- Query params: `root_id` (optional, filter by area like Home/Work)
- Excludes projects tagged "on-hold"
- Used by: `directgtd_get_stuck_projects`

---

### 5. Hierarchy & Organization

**`GET /node-tree`**
- Return hierarchical tree structure
- Query params: `root_id`, `max_depth`
- Returns: id, title, parent_id for each node
- Used by: `directgtd_get_node_tree`

**`POST /root-items`**
- Create a root-level item (no parent)
- Body: `{ title, itemType, dueDate, earliestStartTime }`
- Used by: `directgtd_create_root_item`

---

### 6. Sorting Operations

**`POST /items/swap`**
- Swap sort_order between two sibling items
- Body: `{ itemId1, itemId2 }`
- Used by: `directgtd_swap_items`

**`POST /items/:id/move-to-position`**
- Move item to specific position among siblings
- Body: `{ position }` (0-based index)
- Used by: `directgtd_move_to_position`

**`POST /items/:id/reorder-children`**
- Set custom order for all children
- Body: `{ itemIds: [...] }` (array in desired order)
- Used by: `directgtd_reorder_children`

---

### 7. Tag Queries

**`GET /items/by-tags`**
- Find items with ALL specified tags (AND logic)
- Query params: `tags` (comma-separated names or IDs), `include_completed`, `include_archive`
- Used by: `directgtd_get_items_by_tag_names`, `directgtd_get_items_by_tag_ids`

---

### 8. Time Tracking Enhancements

**`GET /timers/active`**
- Return all currently running timers
- Used by: `directgtd_get_active_timers`

**`GET /items/:id/total-time`**
- Return total time spent on an item (sum of all entries)
- Used by: `directgtd_get_total_time`

**`PUT /time-entries/:id`**
- Update time entry start/end times
- Body: `{ startedAt, endedAt }` (Unix timestamps)
- Used by: `directgtd_update_start_time`, `directgtd_update_end_time`

---

### 9. Trash Operations

**`POST /trash/empty`**
- Permanently delete items in trash
- Query params: `keep_items_since` (ISO date, optional)
- Used by: `directgtd_empty_trash`

---

### 10. Template Operations

**`POST /templates/:id/instantiate`**
- Create new instance from template with all children
- Body: `{ name, parentId, asType }`
- Copies tags on items
- Used by: `directgtd_instantiate_template`

---

## Implementation Priority

### High Priority (Core GTD Workflows)
1. Due date queries (overdue, today, tomorrow, this week)
2. Task status queries (available, deferred, completed)
3. Dashboard endpoint
4. Stuck projects endpoint

### Medium Priority (Organization)
5. Archive operation
6. Node tree endpoint
7. Items by tags query
8. Sorting operations

### Lower Priority (Specialized)
9. Time tracking enhancements
10. Trash operations
11. Template instantiation
12. Create root item

---

## Notes

- All endpoints should respect soft-delete (exclude `deleted_at IS NOT NULL`)
- Archive/Trash/Reference/Templates folders should be excludable via query params
- Timestamps should be Unix epoch (seconds) for consistency
- The MCP server is currently using direct SQLite for these operations, bypassing the soft-delete cascade logic in `SoftDeleteService.swift`

---

## Benefits of Completing API Coverage

1. **Data Integrity**: All writes go through proper soft-delete handling
2. **Sync Safety**: Changes properly marked with `needs_push` for CloudKit
3. **Single Source of Truth**: ItemStore remains the authoritative data layer
4. **Maintainability**: MCP server becomes a pure API client
