# DirectGTD User Manual
## For People Who Hate Reading Manuals

You're busy. We get it. Here's everything you need in 3 minutes.

---

## What Is This Thing?

DirectGTD is a **keyboard-first, hierarchical task manager** with item types, checkboxes, and zero friction. Think outliners meet GTD meets productivity zen. Mouse optional. Keyboard preferred.

*[Screenshot: Main app window with tree view showing different item types]*

---

## The 60-Second Quick Start

1. Launch the app
2. Hit **T** to create your first task
3. Type something
4. Hit **Return** to save
5. Click the checkbox to mark it done
6. Congratulations, you're a power user now

*[Screenshot: Empty app → task created → checkbox checked]*

---

## Essential Shortcuts

### Basic Navigation
| Key | What It Does |
|-----|--------------|
| **↑ ↓** | Navigate up/down |
| **← →** | Collapse/expand parent items |
| **Space** | Edit the selected item |
| **.**  (period) | Toggle task completion (tasks only) |
| **Esc** | Cancel editing |
| **Delete** | Delete selected item (no confirmation, we trust you) |

### Creating Items (Auto-saves and starts editing)
| Key | What It Does |
|-----|--------------|
| **Return** | Create item below (type unknown) |
| **I** | Quick Capture - Create task in designated folder |
| **T** | Create Task (with checkbox) |
| **N** | Create Note |
| **F** | Create Folder |
| **P** | Create Project |
| **E** | Create Event |

### Organizing
| Key | What It Does |
|-----|--------------|
| **Tab** | Indent (make it a child of item above) |
| **Shift+Tab** | Outdent (promote it up one level) |
| **Cmd+↑** | Move item up (within same level) |
| **Cmd+↓** | Move item down (within same level) |
| **Cmd+C** | Duplicate item (shallow - item + children) |
| **Cmd+Shift+C** | Duplicate item (deep - entire subtree) |

### View Controls
| Key | What It Does |
|-----|--------------|
| **Cmd F** | Toggle search mode |
| **Cmd +** | Increase font size |
| **Cmd -** | Decrease font size |
| **Cmd 0** | Reset font size to default |

### Undo/Redo
| Key | What It Does |
|-----|--------------|
| **Cmd Z** | Undo last action |
| **Cmd Shift Z** | Redo last undone action |

*[Screenshot: Keyboard shortcuts reference card]*

---

## Item Types & Icons

DirectGTD has **12 item types**, each with its own icon:

| Type | Shortcut | Icon | Use For |
|------|----------|------|---------|
| **Task** | T | ☐ / ☑ | Things to do (has checkbox) |
| **Note** | N | 📄 | Information, ideas, references |
| **Folder** | F | 📁 | Organizing/grouping items |
| **Project** | P | 📋 | Multi-step endeavors |
| **Event** | E | 📅 | Time-based activities |
| **Template** | - | 📋 | Reusable item templates |
| **SmartFolder** | - | 🔍 | Dynamic filtered views |
| **Alias** | - | 🔗 | References to other items |
| **Heading** | - | 📌 | Section dividers |
| **Link** | - | 🌐 | Web URLs |
| **Attachment** | - | 📎 | Files and attachments |
| **Unknown** | Return | ❓ | Uncategorized items |

**5 types have keyboard shortcuts** (T, N, F, P, E) for quick creation. Others can be set via the DetailView.

**Pro tip:** Tasks get checkboxes. Folders show child counts. Everything else gets a symbolic icon.

*[Screenshot: Different item types with their icons in the tree]*

---

## Quick Capture

**The fastest way to add a task.**

Hit **I** from anywhere in the app:
- Opens quick capture window
- Type your task
- Hit **Return** to save
- Task appears in your designated quick capture folder

**Set your quick capture folder:**
1. Click the gear icon (⚙️) in toolbar
2. Pick any Folder-type item
3. All quick-captured tasks go there

*[Screenshot: Quick capture window]*

---

## Split Pane Layout

The app has **two panes**:

**Left Pane (TreeView):**
- Hierarchical list of all items
- Navigate with keyboard
- Create/delete/organize items

**Right Pane (DetailView):**
- Shows details of selected item
- Change item type
- Track time with start/stop timers
- Set due dates and earliest start times
- Toggle task completion
- Add/edit notes
- Manage tags

**Resizable divider** - Drag to adjust pane sizes.

*[Screenshot: Split pane layout with both sides visible]*

---

## Task Completion

Tasks (and only tasks) have checkboxes.

**Three ways to complete a task:**
1. **Press period (.)** - Keyboard shortcut (tasks only)
2. **Click the checkbox** in the tree (☐ → ☑)
3. **Use the toggle** in DetailView (right pane)

All methods toggle between complete/incomplete.

**Show/Hide Completed Tasks:**
- Click the **eye icon** (👁️) in toolbar
- Hides completed tasks from view
- Click again (eye with slash) to show all tasks
- Setting persists between sessions

*[Screenshot: Task being checked and eye icon toggled]*

---

## How Hierarchy Works

Items can have sub-items. Sub-items can have sub-sub-items. It's turtles all the way down.

**Keyboard (fast & precise):**
- **Tab** - Make selected item a child of item above
- **Shift+Tab** - Promote item back up one level
- **→** - Expand parent item
- **←** - Collapse parent item

**Drag-and-Drop (visual & intuitive):**

**Three ways to drop:**
- **Drop on TOP quarter** - Insert ABOVE target (as sibling before)
- **Drop in MIDDLE half** - Insert INTO target (as child)
- **Drop on BOTTOM quarter** - Insert BELOW target (as sibling after)

**Visual feedback shows where item will land:**
- **Blue line above** - Will insert as sibling before target
- **Highlighted background** - Will become child of target (drop INTO)
- **Blue line below** - Will insert as sibling after target

**Smart features:**
- **Prevents invalid drops** - Can't drop item onto itself or create circular hierarchies
- **Auto-expand** - Dropping INTO collapsed item expands it
- **Preserves hierarchy** - Reordering siblings keeps same parent
- **Full undo/redo** - Cmd+Z undoes any drag-and-drop operation

**Pro tip:** Keyboard is faster for single moves (Cmd+Up/Down, Tab/Shift+Tab). Drag-and-drop shines for major reorganizations where you want to visualize the new structure.

*[Screenshot: Hierarchical item list with indentation and chevrons]*

*[Screenshot: Drag-and-drop in action with visual feedback]*

---

## Editing Items

Two ways:
1. **Space** - Edit selected item
2. **Click** - Select, then Space

When editing:
- **Return** saves
- **Esc** cancels
- Empty items get auto-deleted when you cancel (we're tidy like that)

*[Screenshot: Item in edit mode]*

---

## Notes

**Add detailed notes to any item.**

Every item can have notes - perfect for task descriptions, project details, reference information, or any text you need alongside the item title.

**How to use:**
1. Select an item in the tree (left pane)
2. Look for the **Notes section** in DetailView (right pane)
3. Click in the text editor and start typing
4. **Auto-saves** as you type (no save button needed)
5. Empty notes are automatically cleared

**Features:**
- **Multiline editor** - Expands as you type (min 100px, max 300px)
- **Plain text** - Simple and fast (markdown/rich text may come later)
- **Undo/redo support** - Cmd+Z works on note edits
- **Works on all item types** - Tasks, notes, folders, projects, everything

**Perfect for:**
- Task descriptions and acceptance criteria
- Project details and objectives
- Meeting notes and event details
- Reference information on Note items
- Context and background for any item

*[Screenshot: DetailView showing notes editor with content]*

---

## Time Tracking

**Track how much time you spend on tasks and projects.**

DirectGTD includes built-in time tracking for any item. Start a timer, work on your task, stop the timer - all your time is automatically logged.

**Starting a Timer:**
1. Select an item in the tree
2. In DetailView → **Time Tracking section**
3. Click the **play button** (▶️)
4. Timer starts running immediately

**While Timer Runs:**
- **Live elapsed time** updates every second
- **Green monospaced text** shows current duration
- **Stop button** (🔴) appears to end the session
- Timer keeps running even if you switch to other items

**Stopping a Timer:**
- Click the **stop button** (🔴) next to the running timer
- Time entry is saved to database with start/end times
- Total time for item updates automatically

**Viewing Total Time:**
- **Total Time** row shows cumulative tracked time for the item
- Includes all past time entries plus any active timer
- Updates live as timers run
- Persists across app sessions

**Multiple Concurrent Timers:**
- You can run **multiple timers simultaneously**
- Track time on different tasks at once
- Perfect for multitasking or parallel work streams
- Each item shows its own timer state independently

**Smart Timer Management:**
- Timer only ticks when DetailView is visible
- Automatically cleans up when you close the view
- No performance impact when not actively viewing timers
- Database observes time_entries for auto-refresh

**Data Storage:**
- All time entries stored in local database
- Each entry: id, itemId, startedAt, endedAt, duration
- Cascade delete - deleting an item removes its time entries
- Time totals cached for fast display

**Use Cases:**
- **Client billing** - Track billable hours per project
- **Time audits** - See where your time actually goes
- **Task estimation** - Compare estimated vs actual time
- **Focus sessions** - Time-box your work (Pomodoro style)
- **Project metrics** - Understand project time investment

**Pro tip:** Start a timer at the beginning of your work session and forget about it. DirectGTD will track your time automatically while you focus on getting things done.

*[Screenshot: DetailView Time Tracking section with running timer]*

*[Screenshot: DetailView Time Tracking section showing total time]*

---

## Due Dates & Start Times

**Track deadlines and defer work until it's ready.**

Set due dates to track when things need to be done. Set earliest start times to hide work until the right moment.

**Setting Due Dates:**
1. Select an item in the tree
2. In DetailView → **Dates section** → **Due Date**
3. Click **"Set"** button (defaults to tomorrow at 5pm)
4. Adjust date and time with inline picker
5. Click **X** to clear the due date

**Setting Earliest Start Times:**
1. Select an item in the tree
2. In DetailView → **Dates section** → **Earliest Start**
3. Click **"Set"** button (defaults to today at 9am)
4. Adjust date and time with inline picker
5. Click **X** to clear the start time

**Visual Badges in Tree View:**

Items with dates show **color-coded badges** for instant status recognition:

- **Red badge** - Overdue (past due date)
- **Orange badge** - Due today
- **Blue badge** - Deferred (hasn't started yet, future start time)
- **Text shows**: "Today", "Tomorrow", or short date (e.g., "11/26")

**How Earliest Start Works:**

Items with future start times show a **blue badge** in the tree. This lets you defer work until the right moment without cluttering your current view. Perfect for:
- Tasks that can't start until a specific date ("Call client after product ships")
- Seasonal work ("Review Q4 goals in October")
- Time-sensitive opportunities ("Buy tickets when sales open")

**Features:**
- **Both date and time** - Precise scheduling for both fields
- **Smart defaults** - Due dates default to tomorrow 5pm, start times to today 9am
- **Minimal UI** - Compact inline pickers, no calendar popups
- **Visual feedback** - Color-coded badges show status at a glance
- **Undo/redo support** - Cmd+Z works on all date changes
- **Works on all item types** - Not just tasks

**GTD Workflow:**

DirectGTD's date fields map to GTD principles:
- **Due Date** = Hard deadline (when it MUST be done)
- **Earliest Start** = Defer until viable (tickler file concept)
- Use **tags** for contexts (home, work, computer)
- Use **folders** for projects and areas of responsibility

*[Screenshot: DetailView showing Dates section with both fields set]*

*[Screenshot: TreeView showing red, orange, and blue date badges]*

---

## Reordering Items

Move items up/down within their current level:

- **Cmd+↑** - Move item up (swaps with item above)
- **Cmd+↓** - Move item down (swaps with item below)

Only works among siblings (same parent, same level). Want to move to a different level? Use Tab/Shift+Tab.

*[Screenshot: Item being reordered with Cmd+arrows]*

---

## Duplicating Items

**Copy items with keyboard shortcuts.**

DirectGTD offers two duplication modes depending on how much you want to copy.

**Shallow Copy (Cmd+C):**
- Duplicates selected item + its immediate children
- **One level deep** - Grandchildren and deeper descendants are NOT copied
- Duplicate appears as sibling immediately after the original
- Perfect for copying a task with a few subtasks

**Deep Copy (Cmd+Shift+C):**
- Duplicates selected item + **entire subtree recursively**
- **All descendants copied** - Children, grandchildren, and all levels
- Full hierarchy preserved in the copy
- Expansion state preserved (collapsed items stay collapsed)
- Perfect for copying project templates or complex folder structures

**What Gets Copied:**

Both modes copy:
- ✓ Item title, type, and notes
- ✓ Due dates and earliest start times
- ✓ All tags (tag relationships preserved)
- ✓ Hierarchy structure (parent-child relationships)

Both modes reset:
- ✗ Completion status - Tasks start incomplete (checkbox unchecked)
- ✗ IDs and timestamps - Fresh IDs and creation times assigned

**Auto-Expand:**
- If the duplicated item has children, it's automatically expanded
- You see what you just duplicated immediately

**Undo Support:**
- **Cmd+Z** deletes the entire duplicated subtree
- Works for both shallow and deep copies
- Atomic operation - all or nothing

**Use Cases:**

**Shallow Copy:**
- Duplicate a task with a few action items
- Copy a project outline without all the details
- Template a folder structure without deep nesting

**Deep Copy:**
- Clone entire project hierarchies
- Duplicate complex GTD structures
- Copy template folders with all contents
- Replicate recurring workflows (weekly review, monthly reports)

**Pro tip:** Use deep copy for project templates. Create your ideal project structure once (folders, milestones, tasks with tags), then Cmd+Shift+C to duplicate it for new projects.

*[Screenshot: Shallow copy - item with children duplicated]*

*[Screenshot: Deep copy - entire project hierarchy duplicated]*

---

## Folder Counts

Folders automatically show **how many direct children** they contain (Apple Notes style).

- Count appears on the right side of folder rows
- Updates in real-time as you add/remove items
- Only shows if folder has children
- Great for seeing project sizes at a glance

*[Screenshot: Folders with counts displayed]*

---

## Tags

**Organize items with flexible, color-coded tags.**

Tags let you categorize items across the hierarchy - perfect for GTD contexts (home, work, computer), priorities, or any classification you need.

**Creating Tags:**
1. Select an item in DetailView
2. Click "Add Tag" in Tags section
3. Click "Create New Tag" button
4. Enter name and pick a color
5. Preview shows how it will look
6. New tag automatically added to current item

**Assigning Tags to Items:**
- **DetailView Tags section** shows all tags on selected item
- **Add Tag button** opens tag picker
- **Toggle checkboxes** to add/remove tags
- **Search tags** by name for quick access
- **Multiple tags** per item (unlimited)

**Tag Filtering:**

**Filter your tree view by tag to focus on specific contexts.**

- **Tag filter button** in toolbar (tag icon)
- Click to open tag filter picker
- **Select a tag** to show only items with that tag
- **Smart filtering** - Also shows parent items (preserves hierarchy)
- **Clear button** appears when filter is active
- **Visual indicator** - Tag icon becomes filled/accented when filtering

**Perfect for GTD contexts**: Filter by "home" to see only home tasks, "work" for work items, etc.

**Tag Manager (Centralized Management):**

Access via **Settings (⚙️) → Manage Tags**

- **View all tags** - Alphabetically sorted list
- **Usage count** - See how many items use each tag
- **Edit tags** - Click pencil icon to change name/color
- **Delete tags** - Click trash icon (warns if tag is in use)
- **Create tags** - "New Tag" button at bottom
- **Undo/Redo** - Cmd+Z/Cmd+Shift+Z work in Tag Manager

**Individual Tag Management:**
- Tags are **reusable** - create once, use everywhere
- **Color-coded** for visual scanning
- **Remove from item** - Click X on tag chip in DetailView
- **Undo support** - All tag operations are undoable

**Visual Design:**
- **Colored chips** with custom colors
- **Flow layout** - Wraps to multiple lines
- **Compact** - Doesn't clutter the interface

**Common Tag Uses:**
- **GTD Contexts**: home, work, computer, phone, errands (or use @home, @work if you prefer)
- **Priorities**: high-priority, low-priority, urgent
- **People**: boss, john, waiting-for
- **Energy**: high-energy, low-energy, quick-win
- **Projects**: q4-goals, personal, work

**Note:** The @ symbol is just a naming convention - tag names are freeform text.

*[Screenshot: DetailView with multiple colored tags]*

*[Screenshot: Tag picker with search and checkboxes]*

*[Screenshot: Tag Manager showing list with usage counts and edit/delete buttons]*

*[Screenshot: Tag filter active - toolbar icon highlighted and filtered tree view]*

---

## Search

**Find anything instantly.**

Hit **Cmd+F** to search your entire item list.

**How it works:**
- **Cmd+F** - Opens search mode (replaces tree view)
- **Type to search** - Live filtering as you type
- **Case-insensitive** - Finds "Project" when you type "project"
- **Click result** - Selects item and exits search
- **Esc** - Closes search and returns to tree view

**Search results show:**
- **Item icon** - Visual item type indicator
- **Item title** - Matching items highlighted
- **Breadcrumb path** - Shows where item lives (e.g., "Work > Projects > Q4")

**Pro tip:** Search is blazing fast even with hundreds of items. Type a few letters and jump straight to what you need.

*[Screenshot: Search results with breadcrumbs]*

---

## SQL Search (Power Users)

**Query your data with raw SQL for ultimate flexibility.**

SQL Search lets you create custom filters using SQLite queries. Perfect for power users who want complete control over what they see.

**Opening SQL Search:**
- Click the **magnifying glass icon** in toolbar
- SQL search dialog opens with editor and saved searches

**Creating a Query:**
1. Type SQL query in the editor (monospaced, no smart quotes)
2. Click **Run** (or Cmd+Return) to execute
3. Results appear in tree view
4. Click **Clear** to exit SQL search mode

**Saving Searches:**
1. Write your query
2. Click **Save Search...**
3. Give it a name (e.g., "Overdue Tasks")
4. Access saved searches from the list in the dialog

**Show Ancestors Toggle:**
- **Enabled** (default): Shows matching items plus all their ancestors for context
- **Disabled**: Shows only exact matches (flat list)

**Visual Indicator:**
- Magnifying glass icon becomes **filled** when SQL search is active
- Shows which filter is currently applied

**Example Queries:**

**Overdue Tasks:**
```sql
SELECT id FROM items
WHERE item_type = 'Task'
  AND completed_at IS NULL
  AND due_date < strftime('%s', 'now')
ORDER BY due_date ASC
```

**Due Today:**
```sql
SELECT id FROM items
WHERE item_type = 'Task'
  AND completed_at IS NULL
  AND date(due_date, 'unixepoch') = date('now')
ORDER BY due_date ASC
```

**Ready to Start:**
```sql
SELECT id FROM items
WHERE item_type = 'Task'
  AND completed_at IS NULL
  AND (earliest_start_time IS NULL
       OR earliest_start_time <= strftime('%s', 'now'))
ORDER BY due_date ASC
```

**Items with Specific Tag:**
```sql
SELECT i.id FROM items i
JOIN item_tags it ON i.id = it.item_id
JOIN tags t ON it.tag_id = t.id
WHERE t.name = 'Important'
ORDER BY i.modified_at DESC
```

**Available Tables:**

- **items** - id, title, item_type, notes, parent_id, sort_order, created_at, modified_at, completed_at, due_date, earliest_start_time
- **tags** - id, name, color
- **item_tags** - item_id, tag_id

**Date/Time Helpers:**
- Current time: `strftime('%s', 'now')`
- Today: `date(due_date, 'unixepoch') = date('now')`
- Next 7 days: `strftime('%s', 'now', '+7 days')`

**Security:**
- **SELECT only** - No DELETE, UPDATE, INSERT, or DROP allowed
- **250ms timeout** - Queries are killed if they take too long
- **Read-only** - Cannot modify your data via SQL

**Pro tip:** Start with the example queries and modify them. SQL search excels at complex filters like "untagged tasks without notes created this week."

*[Screenshot: SQL search dialog with query and saved searches]*

*[Screenshot: SQL search results in tree view]*

---

## Undo/Redo

**Never fear making mistakes.**

DirectGTD supports comprehensive undo/redo for all major operations.

**Access Undo/Redo:**
1. **Keyboard**: Cmd+Z (undo), Cmd+Shift+Z (redo)
2. **Toolbar**: Arrow buttons (← ↻ ↺ →) with disabled states

**What You Can Undo:**
- **Create Item** - Undo the first edit of a new item deletes it entirely
- **Edit Title** - Revert title changes
- **Mark Complete/Incomplete** - Toggle task completion state
- **Delete Item** - Restore deleted items with full subtree and tags

**Smart Features:**
- **Subtree restoration** - Deleting a parent with children? Undo restores the entire hierarchy
- **Tag preservation** - All tag relationships are restored when undoing deletions
- **Action names** - Hover over undo/redo buttons to see what will be undone/redone
- **Standard macOS behavior** - Works exactly like you expect

*[Screenshot: Undo/redo buttons in toolbar]*

---

## iCloud Sync

**Sync your data across all your Macs automatically.**

DirectGTD uses iCloud to keep your tasks, projects, and notes in sync across all your devices. Works automatically in the background - no manual sync needed.

**How It Works:**
- **CloudKit Private Database** - Your data stays private in your iCloud account
- **Automatic sync** - Changes sync immediately when you edit
- **Conflict resolution** - Last write wins (based on modification time)
- **Efficient** - Only syncs what changed (dirty tracking)
- **Reliable** - Automatic retry with exponential backoff if network fails

**Initial Setup:**
1. Make sure you're signed in to iCloud (System Settings → Apple ID)
2. First launch syncs all existing data to iCloud
3. **Progress overlay** shows sync status during first sync
4. Subsequent syncs happen automatically in background

**Sync Status (Toolbar):**
- ☁️✓ **Green checkmark** - Everything synced, up to date
- ⚙️ **Spinner** - Sync in progress
- ☁️⚠️ **Red exclamation** - Sync error (check iCloud account)
- ☁️/ **Slash icon** - Sync disabled

**Settings (Settings → iCloud Sync):**
- **Enable iCloud Sync** toggle - Turn sync on/off
- **Sync Now** button - Force immediate sync
- **Account name** - Shows which iCloud account is active
- **Last sync** - Shows when last sync completed
- **Reset Sync State** - Clear metadata and re-sync (debugging only)

**Manual Sync:**
- Click sync menu button in toolbar
- Select **"Sync Now"**
- Useful after being offline for a while

**Sync States:**

**Disabled:**
- User toggled sync off in Settings, OR
- No iCloud account signed in
- Data stays local only

**Idle:**
- Everything synced successfully
- Watching for local changes
- Watching for remote changes (via CloudKit push notifications)

**Syncing:**
- Uploading local changes to iCloud
- Downloading remote changes from other devices
- Usually completes in seconds

**Initial Sync:**
- First-time setup sync
- Shows progress overlay (0-100%)
- Uploads all existing data
- Can take several minutes for large databases

**Error:**
- Network issue, iCloud quota full, or account problem
- Shows error message in sync menu
- Automatically retries with exponential backoff

**Conflict Resolution:**

DirectGTD uses **last-write-wins** conflict resolution:
- If same item edited on two devices simultaneously
- Most recent modification (based on `modifiedAt` timestamp) wins
- Simple, predictable, no merge conflicts
- Works well for single-user workflows

**What Gets Synced:**
- ✓ All items (tasks, notes, folders, projects)
- ✓ Tags and tag assignments
- ✓ Time entries (tracked time)
- ✓ Due dates and start times
- ✓ Completion status
- ✓ Notes/descriptions
- ✓ Hierarchy (parent-child relationships)
- ✓ Sort order
- ✗ Settings (font size, margins) - These stay per-device
- ✗ UI state (selection, expansion) - These stay per-device

**Deleted Items (Tombstones):**
- Deletions sync across devices
- Tombstone records kept for 30 days
- After 30 days, tombstones cleaned up automatically
- Prevents deleted items from reappearing on old devices

**Periodic Sync (Fallback):**
- Automatic sync every 5 minutes
- Backup mechanism when push notifications don't work
- Ensures sync happens even without network push

**Troubleshooting:**

**"iCloud not available":**
- Sign in to iCloud in System Settings
- Make sure iCloud Drive is enabled
- Check internet connection

**Sync stuck:**
- Force quit and relaunch DirectGTD
- Use "Sync Now" button in settings
- Check iCloud system status at apple.com/support/systemstatus

**Data not syncing:**
- Check iCloud storage (Settings → Apple ID)
- Make sure both devices have sync enabled
- Wait a few minutes (changes may be queued)

**Reset sync state:**
- Settings → iCloud Sync → Reset Sync State
- Clears all sync metadata
- Re-syncs everything from scratch
- Use only if sync is broken

**Pro tip:** Leave sync enabled and forget about it. DirectGTD handles everything automatically. You'll only notice sync when you open DirectGTD on a different Mac and see your latest changes already there.

*[Screenshot: Sync status in toolbar showing synced state]*

*[Screenshot: Settings → iCloud Sync section]*

*[Screenshot: Initial sync progress overlay]*

---

## Automatic Backups

**Your data is automatically backed up.**

DirectGTD creates automatic backups of your database to protect against data loss. No configuration needed - it just works.

**Two-Tier Backup System:**

**Hourly Backups:**
- Created every hour when app is running
- Kept for 2 days, then auto-deleted
- Perfect for recovering from recent mistakes
- Location: `~/Library/Application Support/DirectGTD/backups/hourly/`

**Daily Backups:**
- Created every 24 hours
- Kept indefinitely (prompt when count exceeds 30)
- Perfect for long-term recovery
- Location: `~/Library/Application Support/DirectGTD/backups/daily/`

**Backup Manager:**

Access via **Settings → Manage Backups**

**Features:**
- **List all backups** - Shows timestamp and type (Hourly/Daily)
- **Backup count** - Shows total number of backups
- **Restore** - Select backup and restore (requires restart)
- **Delete** - Remove old backups to save space
- **Type badges** - Blue = Daily, Gray = Hourly

**Restoring from Backup:**
1. Open Settings → Manage Backups
2. Select backup to restore
3. Click **Restore**
4. Confirm restoration
5. **Quit and relaunch** DirectGTD
6. Database restored from selected backup

**How Restore Works:**
- Schedules file swap for next launch (avoids locked database issues)
- Creates backup of current database before restoring
- Requires app relaunch to complete restoration
- Safe - always creates backup before replacing

**Backup Cleanup:**
- Hourly backups auto-delete after 2 days
- Daily backups kept until count exceeds 30
- When >30 daily backups, app prompts for cleanup
- You can manually delete backups anytime

**Backup File Format:**
- Timestamped: `yyyy-MM-dd_HHmmss.sqlite`
- Example: `2025-12-10_143022.sqlite`
- Allows multiple backups per day
- Easy to identify by date/time

**Pro tip:** Backups happen automatically. You only need Backup Manager when restoring from a specific point in time or cleaning up old backups.

*[Screenshot: Backup Manager showing list of daily and hourly backups]*

---

## Settings & Customization

Click the **gear icon (⚙️)** in the toolbar to access settings:

**iCloud Sync:**
- **Enable iCloud Sync** - Toggle sync on/off
- **Sync Now** - Force immediate sync
- **Account name** - Shows active iCloud account
- **Last sync** - Time since last successful sync
- **Reset Sync State** - Debug option to clear and re-sync

**Backups:**
- **Manage Backups** - List, restore, and delete backups
- Shows backup count next to button
- Automatic hourly and daily backups

**Visual Settings:**
- **Font Size** - Adjust text size (also: Cmd+/Cmd-/Cmd0)
- **Line Spacing** - Adjust vertical space between items
- **Horizontal Margin** - Adjust left/right padding
- **Vertical Margin** - Adjust top/bottom padding

**Behavior Settings:**
- **Quick Capture Folder** - Choose where "I" sends tasks
- **Manage Tags** - Opens Tag Manager for centralized tag management

**Tag Management:**
- View all tags with usage counts
- Edit/delete tags
- Create new tags

All settings **persist across sessions**.

*[Screenshot: Settings window with all options]*

---

## Navigation Like a Boss

- **↑↓** moves selection up/down (through visible items only)
- **←→** collapses/expands parent items
- Works across all levels
- Auto-scrolls to keep selection visible
- Blue border means the view is focused (it should always be)

*[Screenshot: Selection moving through items]*

---

## Pro Tips

**Quick Workflows:**
- Use **I** for rapid task capture without leaving context
- Use **Cmd+F** to find anything instantly (scales to 1000+ items)
- **SQL search** - Create saved searches for "Overdue", "Due Today", "Ready to Start" - one click filtering
- **Start timers** at the beginning of work sessions - track time automatically while you focus
- **Filter by tag** - Click tag icon to see only items in a specific context (home, work, etc.)
- **Tags for contexts** - Tag tasks with contexts (home, work, computer) for GTD workflow
- **Date badges** - Scan for red (overdue), orange (due today), blue (deferred) at a glance
- **Quick capture folder** keeps your inbox organized
- Hide completed tasks (eye icon) for focused work sessions
- Use DetailView to batch-edit item properties and manage tags

**Creating Items:**
- Use type-specific shortcuts (T/N/F/P/E) to create items with the right icon
- New items appear right below the selected one
- They inherit the same hierarchy level
- Auto-enters edit mode immediately (start typing)
- Unknown items (Return) can be typed later in DetailView

**Organizing:**
- **Folders** for hierarchy, **tags** for cross-cutting concerns
- Tab/Shift+Tab works on any selected item
- Parent items auto-expand when you indent under them
- Use Cmd+↑/↓ to fine-tune order at the same level
- Delete removes the whole subtree (but Cmd+Z restores it!)
- **Duplicate with Cmd+C/Cmd+Shift+C** - Create project templates once, copy them forever
- Watch folder counts to gauge project sizes
- **Color-code tags** by category (blue=work, green=home, red=urgent)

**View Customization:**
- Zoom in/out with Cmd +/- if you have eagle/weak eyes
- Adjust line spacing for density vs. readability
- Tweak margins to match your screen size
- All settings persist between sessions
- Split pane divider is resizable (drag it)

**Focus:**
- Click anywhere in the tree area if shortcuts stop working
- The blue border means you're in business
- DetailView updates automatically when you select items

*[Screenshot: Pro user workflow with quick capture and settings]*

---

## The Philosophy

DirectGTD follows one principle: **Get out of your way.**

**What we have:**
- **iCloud sync** - Automatic background sync across all your Macs
- **Time tracking** - Built-in timers for tracking work sessions on any item
- **SQL search** - Raw SQLite queries for power users who want ultimate control
- **Due dates & start times** - Track deadlines and defer work with visual badges
- **Tags** - Flexible, color-coded organization for GTD contexts
- **Search** - Instant filtering to find anything
- **Hierarchy** - Folders and projects with unlimited nesting
- **Keyboard-first** - Every core action has a shortcut (but drag-and-drop available too)
- **Local storage** - Your data stays yours (synced via your private iCloud)

**What we deliberately don't have:**
- No right-click menus (keeps it simple)
- No AI suggestions (you know your work best)
- No social features (this is your personal system)
- No recurring tasks (single-instance simplicity)
- No third-party cloud sync (iCloud only - keeps it simple)

Fast, focused, friction-free. If you need calendars, reminders, team collaboration, or AI assistance... you probably need a different app.

---

## Common Questions

**Q: Can I use the mouse?**
A: Yes. Checkboxes and chevrons require it. Everything else is keyboard-first.

**Q: Where's my data stored?**
A: Local SQLite database. Your stuff stays your stuff.

**Q: What if I delete something by accident?**
A: Hit Cmd+Z! Undo fully restores deleted items with their entire subtree and tag relationships.

**Q: Can I collapse/expand items with keyboard?**
A: YES! Left/right arrows. We finally did it.

**Q: What's the difference between folders and tags?**
A: Folders are hierarchical (one parent). Tags are flexible (unlimited, cross-cutting). Use folders for structure, tags for contexts/categories.

**Q: What's the difference between a Folder and a Project?**
A: Semantics. Use whatever mental model works for you. They behave identically.

**Q: How do I find an item quickly?**
A: Cmd+F opens search. Type a few letters and click the result. Works with hundreds of items.

**Q: How do I filter by tag?**
A: Click the tag icon in the toolbar, select a tag, and the tree view shows only items with that tag (plus their parents to preserve hierarchy). Click "Clear" to remove the filter.

**Q: What's the difference between due date and earliest start time?**
A: Due date = when it MUST be done (hard deadline). Earliest start = when you CAN start (defer until ready). GTD calls this the "tickler file" concept.

**Q: Do items with future start times disappear from the tree?**
A: No! They stay visible with a blue badge. The badge reminds you they're deferred but keeps them in context with your hierarchy.

**Q: What's the difference between text search (Cmd+F) and SQL search?**
A: Text search finds items by title (simple, fast). SQL search filters by any criteria - dates, tags, completion status, item type, etc. (powerful, flexible).

**Q: Do I need to know SQL to use SQL search?**
A: No! Use the example queries provided and modify them. Copy "Overdue Tasks" and change the date to create "Due This Week." Most queries follow the same pattern.

**Q: Can SQL search break my database?**
A: No. SQL search only allows SELECT queries (read-only). You can't DELETE, UPDATE, or modify data. Queries also timeout after 250ms to prevent performance issues.

**Q: What's the difference between Cmd+C and Cmd+Shift+C for duplicating?**
A: Cmd+C copies the item and its immediate children (shallow, one level). Cmd+Shift+C copies the entire subtree recursively (deep, all levels). Use shallow for simple tasks, deep for project templates.

**Q: When I duplicate a completed task, is the copy also completed?**
A: No! Duplicated tasks always start incomplete (unchecked). This lets you reuse task templates without manually unchecking everything.

**Q: Do duplicated items keep the same tags?**
A: Yes! All tag relationships are preserved in both shallow and deep copies. This makes it easy to duplicate tagged project templates.

**Q: Can I run multiple timers at the same time?**
A: Yes! DirectGTD supports multiple concurrent timers. Track time on different tasks simultaneously - perfect for multitasking or parallel work streams.

**Q: What happens to time entries when I delete an item?**
A: Time entries are automatically deleted (cascade delete). If you undo the deletion (Cmd+Z), the item comes back but time entries are lost - they're not restored by undo.

**Q: Does the timer keep running if I switch to a different item?**
A: Yes! Timers keep running even when you select a different item or close DetailView. You can have multiple timers running across different items.

**Q: How does iCloud sync work? Do I need to do anything?**
A: No! Just sign in to iCloud and sync happens automatically. First launch syncs all data with progress overlay. After that, changes sync immediately in the background.

**Q: Can I use DirectGTD without iCloud sync?**
A: Yes! Toggle "Enable iCloud Sync" off in Settings → iCloud Sync. Your data stays completely local. You can enable sync later without losing data.

**Q: What happens if I edit the same item on two devices at once?**
A: Last-write-wins. The most recent edit (based on modification timestamp) wins. Simple, predictable conflict resolution that works well for single-user workflows.

**Q: Does sync work on iOS/iPad?**
A: Not yet. DirectGTD is Mac-only currently, but syncs across multiple Macs. iOS/iPad versions may come later.

**Q: How do I check off tasks with keyboard?**
A: Press period (.) when a task is selected. No mouse needed!

**Q: Can I change an item's type after creating it?**
A: Yes! Select the item and use the type picker in DetailView (right pane).

**Q: Where do quick-captured tasks go?**
A: To your designated quick capture folder. Set it in Settings (⚙️).

**Q: Can I have multiple quick capture folders?**
A: Not yet. Pick your inbox folder wisely.

**Q: What's the difference between Template and SmartFolder?**
A: Templates are reusable blueprints (future feature). SmartFolders are dynamic filters (future feature).

**Q: Why 12 item types?**
A: To match different GTD workflows. Use what makes sense, ignore the rest.

**Q: Why can't I [insert feature]?**
A: Because ruthless focus on core features keeps this app fast and simple.

---

## Troubleshooting

**Keyboard shortcuts not working?**
- Click anywhere in the item list
- Look for the blue border (that means focus)

**Item disappeared when I hit Esc?**
- Empty items auto-delete on cancel
- It's a feature, not a bug

**Can't Tab/Shift+Tab?**
- You can't outdent root-level items (nowhere to go)
- You can't indent the first item (nothing above it)

**Cmd+↑/↓ not working?**
- Only works among siblings (same parent, same level)
- Can't move root items past each other? Check that they're actually siblings

**Font too small/large?**
- Cmd+0 resets to default (13pt)
- Cmd+/- adjusts in 2pt increments
- Or use Settings (⚙️) for precise control

**Quick capture not working?**
- Make sure you've set a quick capture folder in Settings
- Only Folder-type items can be quick capture destinations
- The "I" key only works when tree view is focused

**Can't see completed tasks?**
- Click the eye icon in toolbar (it might be showing eye-with-slash)
- This hides/shows completed tasks

**DetailView is blank?**
- Make sure an item is selected in the tree (left pane)
- Click any item to see its details

---

## That's All Folks

You're now a DirectGTD expert. Go forth and organize things.

Questions? Found a bug? Want to contribute?
*[GitHub link goes here]*

---

## DirectGTD for iOS

**Your tasks in your pocket.**

DirectGTD for iPhone is a companion app to the Mac version. It syncs automatically via iCloud and excels at quick capture, reviewing what's due, and completing tasks throughout the day.

### What's Different from Mac

**iOS is optimized for:**
- ✓ Quick capture when ideas strike (< 2 seconds)
- ✓ Reviewing what's due and overdue
- ✓ Completing tasks on the go
- ✓ Staying in sync with desktop

**Complex operations stay on Mac:**
- Bulk reorganization
- Template creation and deep copying
- SQL query writing and editing
- Extensive keyboard shortcuts

The phone is for **capturing, checking, and completing**. The Mac is for **organizing, planning, and power features**.

---

### Getting Started (iOS)

**1. Install DirectGTD on iPhone**
- Download from App Store
- Sign in with same Apple ID as your Mac

**2. First Launch**
- Make sure you're signed in to iCloud
- Initial sync downloads all data from iCloud
- Progress overlay shows 0-100% during first sync
- Takes 1-5 minutes depending on data size

**3. Start Using**
- Tree view appears with all your items
- Tap **+** button for quick capture
- Swipe to expand/collapse folders
- Long-press for context menu
- Everything syncs automatically

---

### iOS Interface Overview

**Main Screen:**
```
┌─────────────────────────────────────────┐
│  DirectGTD                   🔍  ⚙️     │ ← Toolbar
├─────────────────────────────────────────┤
│  ▶ Work Projects                        │
│    ● Client Review           Apr 15  › │ ← Tree rows
│    ○ Write proposal                  › │
│  ▼ Personal                             │
│    ○ Buy groceries                   › │
│                                         │
│                                   [+]   │ ← Quick capture
└─────────────────────────────────────────┘
```

**Navigation:**
- **Tree View** - Main screen, shows full hierarchy
- **Search (🔍)** - Top right, opens search sheet
- **Settings (⚙️)** - Top right, opens settings sheet
- **Quick Capture (+)** - Bottom right floating button

---

### Tree View (iOS)

**Expand/Collapse:**
- Tap **disclosure triangle (▶)** to expand/collapse folders
- Just like iOS Reminders and Notes apps
- Expanded state persists across app launches
- Smooth animations

**Row Layout:**
- **Left**: Indent + triangle (folders) or status icon (tasks)
- **Center**: Title + metadata (due date, tags)
- **Right**: Chevron (›) for detail view

**Status Icons:**
- ● **Filled circle** - Task with due date or incomplete
- ○ **Empty circle** - Incomplete task
- ✓ **Checkmark** - Completed task
- ▶ **Triangle** - Folder/project (collapsed)
- ▼ **Down triangle** - Folder/project (expanded)

**Item Types:**
All 12 item types from Mac appear with their icons (📋 Task, 📝 Note, 📁 Folder, etc.)

---

### Focus Mode (iOS)

**Drill into any folder to see only its subtree.**

**How to Focus:**
1. Long-press any folder
2. Select **"Focus"** from context menu
3. View shows only that folder's children
4. **Breadcrumb bar** appears at top: `Root > Projects > Work`

**Navigating in Focus Mode:**
- Tap any **breadcrumb segment** to navigate up
- Tap **back button** to go up one level
- Swipe **right from left edge** to go back (standard iOS gesture)
- Tap **"Unfocus"** button to return to full tree

**Why Focus?**
- Reduces clutter when working on specific project
- Faster scrolling through large hierarchies
- Maintains context with breadcrumb trail

---

### Quick Capture (iOS)

**Capture tasks in under 2 seconds.**

**How to Use:**
1. Tap floating **+ button** (bottom right)
2. **Title field** auto-focuses with keyboard ready
3. Type task title
4. (Optional) Set type or due date
5. Tap **Save** or hit **Return**
6. Syncs immediately to iCloud

**Where Items Go:**
- Quick captured items go to **Inbox** or configured **Quick Capture Folder**
- Setting syncs between Mac and iPhone
- Change on either device affects both

**Pro tip:** Add DirectGTD to iPhone home screen. Tap, type, done. Everything syncs automatically.

---

### Item Details (iOS)

**View and edit any item.**

**Accessing Details:**
- Tap **chevron (›)** on any tree row
- Opens full detail view

**Detail View Shows:**
- **Title** - Editable text field
- **Type** - Picker for all 12 item types
- **Due Date** - Date + time picker
- **Earliest Start** - Date + time picker
- **Tags** - Color-coded tag chips
- **Notes** - Markdown preview (view mode) or plain text editor (edit mode)
- **Time Tracking** - Total tracked time (read-only on iOS)

**Editing:**
- Tap **Edit** button (top right)
- All fields become editable
- Tap **Done** to save changes
- Changes sync immediately

**Phase 1 (Current):**
- Detail view is read-only (view only)
- Edit support coming in Phase 2

**Phase 2 (In Development):**
- Full editing of all fields
- Type picker, date pickers
- Tag management
- Notes editing with markdown preview toggle

---

### Context Menu (iOS)

**Long-press any item for quick actions.**

**Available Actions:**
- **Details** - Open detail view (read-only in Phase 1)
- **Focus** - Drill into folder (folders only)
- **Complete / Uncomplete** - Toggle task completion (Phase 2)
- **Add Child** - Create child item (Phase 2)
- **Delete** - Delete item with confirmation (Phase 2)
- **Move to...** - Move to different parent (Phase 4)

*Note: Write actions (Complete, Delete, Add, Move) are coming in Phase 2-4.*

---

### Search (iOS)

**Find anything fast.**

**Text Search:**
- Tap **🔍 icon** in toolbar
- Type in search bar
- Searches titles and notes
- Results appear as flat list
- Tap result to view details

**Saved Searches:**
- List of SQL searches synced from Mac
- "Overdue", "Due Today", "This Week", etc.
- Tap to run and view results
- **Cannot edit SQL on iOS** - View results only
- Edit queries on Mac, use on iOS

**Pro tip:** Create useful saved searches on Mac ("Due This Week", "High Priority"), then use them on iPhone for quick reviews.

---

### Settings (iOS)

**Configure sync and appearance.**

**iCloud Sync:**
- **Sync status** - Synced/Syncing/Error indicator
- **Last sync** - Timestamp
- **Sync Now** - Manual sync button
- **Account name** - Shows active iCloud account

**Appearance:**
- **Tree Font Size** - Slider for tree text size
- **Note Font Size** - Slider for note text size
- (Settings stay per-device, not synced)

**Data:**
- **Manage Tags** - View tags with colors (Phase 5)
- **Quick Capture Folder** - Where + button sends items (Phase 2)
- **Archive Folder** - Where archive feature sends items (Future)

**About:**
- Version information
- Help documentation link

---

### Sync Behavior (iOS)

**Same CloudKit sync as Mac - completely automatic.**

**How It Works:**
- All data syncs via CloudKit private database
- Changes on iPhone sync to iCloud immediately
- Changes from Mac appear on iPhone automatically
- Both devices watch for changes (push notifications)
- Periodic sync every 5 min as fallback

**Sync States:**
- ☁️✓ **Green checkmark** - Everything synced
- ⚙️ **Spinner** - Sync in progress
- ☁️⚠️ **Red exclamation** - Sync error
- ☁️/ **Slash icon** - Sync disabled or no iCloud account

**Conflict Resolution:**
- Same as Mac: **Last-write-wins**
- Most recent edit (by `modifiedAt` timestamp) wins
- Simple, predictable, works well for personal use

**What Syncs:**
- ✓ All items, tags, time entries, dates, notes, hierarchy
- ✗ Settings (font sizes) - Stay per-device
- ✗ UI state (expanded folders, selection) - Stay per-device

---

### Offline Mode (iOS)

**Everything works without network.**

DirectGTD for iOS is **offline-first:**
- Full local database on device
- All read operations work instantly (no network needed)
- View tree, expand/collapse, search, view details
- Changes queue for sync when connectivity returns
- No "offline mode" - it just works

**When Network Returns:**
- Queued changes sync automatically
- Remote changes download automatically
- Conflict resolution handles simultaneous edits
- No user action needed

---

### Limitations (iOS)

**What's Mac-only (for now):**

**Not on iOS:**
- SQL query editing (can view saved search results)
- Extensive keyboard shortcuts (phone has touch)
- Drag-and-drop reordering (Phase 4)
- Time tracking start/stop (can view totals)
- Deep copy (Cmd+Shift+C) - Mac feature
- Undo/redo (system undo may come later)
- Tag Manager with creation/deletion (Phase 5)

**Coming in Future Phases:**
- Task completion toggle (Phase 2)
- Quick capture (Phase 2)
- Item editing (Phase 2)
- Delete items (Phase 2)
- Add child items (Phase 4)
- Move items (Phase 4)
- Hold-swipe actions (Phase 4)
- Tag display and editing (Phase 5)

**Mac remains primary:**
- iOS is a **companion app**, not a replacement
- Complex workflows stay on desktop
- Phone excels at capture, review, and completion

---

### iOS Gestures

**Touch interactions optimized for one-handed use.**

**Tap:**
- Tap **disclosure triangle** - Expand/collapse folder
- Tap **chevron (›)** - Open detail view
- Tap **tree row** - Select item (future: quick actions)
- Tap **+ button** - Open quick capture

**Long-Press:**
- Long-press **item** - Show context menu
- Long-press **folder** - Focus option appears

**Swipe:**
- Swipe **right from left edge** - Navigate back (focus mode)
- Hold-swipe **left** - Reveal action buttons (Phase 4)

**Pull:**
- Pull down **at top of tree** - Manual sync (Phase 2)

---

### iOS Tips

**Get the most out of DirectGTD on iPhone:**

1. **Add to Home Screen** - Fastest access for quick capture

2. **Use Quick Capture Liberally** - Capture everything, organize on Mac later

3. **Create Saved Searches on Mac** - "Due Today", "Overdue", "This Week"
   - Use them on iPhone for daily reviews

4. **Focus Mode for Projects** - Drill into active projects to reduce clutter

5. **Trust Sync** - Everything syncs automatically, just keep working

6. **Offline-First** - Don't worry about connectivity, changes queue and sync later

7. **Mac for Organization** - Use iPhone for capture/completion, Mac for planning/reorganization

---

**Version 2.1** | Made for humans who type faster than they click (but can drag too)

### What's New in 2.1

**🎉 Automatic Backups** - Two-tier backup system protects your data!
- **Hourly backups** - Created every hour, auto-deleted after 2 days
- **Daily backups** - Created every 24 hours, kept indefinitely (prompt at 30+)
- **Backup Manager** - List, restore, and delete backups from Settings
- **Safe restore** - Creates backup before restoring, requires app relaunch
- **Type badges** - Blue for daily, gray for hourly backups
- **No configuration** - Works automatically in background
- **Timestamped files** - Easy to identify by date and time

**🎉 iCloud Sync** - Automatic sync across all your Macs!
- **CloudKit private database** - Your data stays private in your iCloud account
- **Automatic background sync** - Changes sync immediately when you edit
- **Initial sync with progress** - First-time setup shows 0-100% progress overlay
- **Conflict resolution** - Last-write-wins based on modification time
- **Sync status indicator** - Toolbar shows sync state (synced/syncing/error/disabled)
- **Manual sync** - Force sync with "Sync Now" button
- **Efficient** - Only syncs what changed (dirty tracking + change tokens)
- **Reliable** - Auto-retry with exponential backoff, periodic fallback sync every 5 min
- **Tombstone cleanup** - Deleted items sync across devices, cleaned after 30 days
- **Toggle on/off** - Disable sync in Settings if you prefer local-only

**🎉 Time Tracking** - Built-in time tracking for any item!
- **Start/stop timers** with play/stop buttons in DetailView
- **Live elapsed time** updates every second while running
- **Total tracked time** shows cumulative hours across all sessions
- **Multiple concurrent timers** - Track time on different tasks simultaneously
- **Smart performance** - Timer only runs when needed, cleans up automatically
- **Database storage** - All time entries persisted with cascade delete
- **Use cases**: Client billing, time audits, task estimation, focus sessions

**🎉 Duplicate Items** - Copy hierarchies with keyboard shortcuts!
- **Shallow copy (Cmd+C)** - Duplicate item + immediate children only
- **Deep copy (Cmd+Shift+C)** - Duplicate entire subtree recursively
- **Smart copying** - Tags preserved, tasks reset to incomplete, fresh IDs
- **Auto-expand** - Duplicated items with children expand automatically
- **Undo support** - Cmd+Z deletes entire duplicated subtree
- **Atomic operations** - All or nothing, no partial copies
- **Use cases**: Project templates, recurring workflows, folder structures

**🎉 SQL Search** - Ultimate power-user filtering!
- **Raw SQLite queries** for maximum flexibility
- **Saved searches** stored in database
- **Example queries** for common patterns (overdue, due today, ready to start)
- **Show ancestors toggle** - Context vs flat list
- **SELECT-only** with 250ms timeout for security
- **Schema reference** - Tables: items, tags, item_tags
- **Monospaced editor** with disabled smart quotes
- **Visual indicator** - Filled magnifying glass when active
- **4 example queries** included (overdue, due today, ready, tagged items)

**🎉 Due Dates & Start Times** - Track deadlines and defer work!
- **Due dates** with date + time for hard deadlines
- **Earliest start times** to defer work until the right moment
- **Color-coded badges** in tree view (red = overdue, orange = due today, blue = deferred)
- **Smart date formatting** - "Today", "Tomorrow", or short date
- **Minimal UI** - Compact inline pickers, no calendar popups
- **Smart defaults** - Due dates → tomorrow 5pm, start times → today 9am
- **Undo/redo support** - Cmd+Z works on all date changes
- **GTD-ready** - Maps to GTD principles (hard deadlines + tickler file)

**🎉 Notes/Descriptions** - Rich context for every item!
- **Multiline text editor** in DetailView for detailed notes
- **Auto-saves** as you type (no save button)
- **Works on all item types** - Tasks, folders, projects, everything
- **Undo/redo support** - Cmd+Z works on note edits
- **Perfect for**: Task descriptions, project details, meeting notes, reference info
- **Plain text** (markdown/rich text may come later)

**🎉 Drag-and-Drop** - Visual reorganization made easy!
- **Three-zone drop detection** - Top = above, Middle = into, Bottom = below
- **Sibling reordering** - Drag to reorder items within same parent
- **Reparenting** - Drag into items to change hierarchy
- **Visual feedback** - Blue lines show exactly where item will land
- **Smart validation** - Prevents self-drop and circular hierarchies
- **Auto-expand** - Dropping into collapsed items expands them
- **Full undo/redo** - Cmd+Z works perfectly
- **Complements keyboard** - Use what feels natural for each task

**🎉 Tags** - Flexible, color-coded organization!
- **Create custom tags** with name and color picker
- **Unlimited tags per item** - Assign multiple tags
- **Tag picker** with search and checkboxes
- **Tag filtering** - Click toolbar icon to filter by tag
- **Smart filtering** - Shows items with tag plus their parents
- **Visual indicator** - Filled tag icon when filter is active
- **Tag Manager** - Centralized tag management in Settings
- **Colored tag chips** in DetailView
- **Reusable tags** - Create once, use everywhere
- **GTD-ready** - Perfect for contexts (home, work, computer)
- **Undo support** - All tag operations are undoable
- **Visual flow layout** - Tags wrap elegantly

**🎉 Search** - Find anything instantly!
- **Cmd+F** to open search mode
- **Live filtering** as you type (case-insensitive)
- **Breadcrumb paths** show where items live
- **Click to jump** - Select result and return to tree
- Scales effortlessly to 1000+ items

**🎉 Undo/Redo** - Never fear mistakes!
- **Comprehensive undo/redo** for all major operations (Cmd+Z / Cmd+Shift+Z)
- **Undo/redo buttons** in toolbar with disabled states
- **Smart undo** - First edit deletion, subtree restoration, tag preservation
- **Action names** - See what you're undoing/redoing

**🎉 Keyboard Task Completion**
- **Period (.) key** - Toggle task completion without touching the mouse

### What's New in 2.0

**Major Features:**
- **Quick Capture** - "I" key for instant task creation
- **12 Item Types** - Unknown, Task, Project, Note, Folder, Template, SmartFolder, Alias, Heading, Link, Attachment, Event
- **Split Pane Layout** - TreeView (left) + DetailView (right)
- **Task Completion** - Checkboxes with show/hide completed toggle
- **Settings UI** - Comprehensive customization (font, margins, spacing, quick capture)

**Keyboard Shortcuts:**
- **Cmd+F** - Search
- **.**  (period) - Toggle task completion
- **I** - Quick capture
- **T/N/F/P/E** - Create typed items
- **Tab/Shift+Tab** - Indent/outdent
- **Cmd+↑/↓** - Reorder items
- **←/→** - Expand/collapse
- **Cmd+/-/0** - Font size
- **Cmd+Z / Cmd+Shift+Z** - Undo/redo

**UI Improvements:**
- Folder counts (Apple Notes style)
- Custom chevron controls
- Resizable split pane divider
- Enhanced icons for all item types
- Eye icon toolbar button for showing/hiding completed tasks
- Undo/redo toolbar buttons

**Database:**
- Migration system v3 with app_settings table
- Item type column
- Quick capture folder persistence
- Tag preservation for undo operations
