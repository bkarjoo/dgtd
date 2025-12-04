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

## Settings & Customization

Click the **gear icon (⚙️)** in the toolbar to access settings:

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
- **Time tracking** - Built-in timers for tracking work sessions on any item
- **SQL search** - Raw SQLite queries for power users who want ultimate control
- **Due dates & start times** - Track deadlines and defer work with visual badges
- **Tags** - Flexible, color-coded organization for GTD contexts
- **Search** - Instant filtering to find anything
- **Hierarchy** - Folders and projects with unlimited nesting
- **Keyboard-first** - Every core action has a shortcut (but drag-and-drop available too)
- **Local storage** - Your data stays yours

**What we deliberately don't have:**
- No right-click menus (keeps it simple)
- No cloud sync (no synchronization anxiety)
- No AI suggestions (you know your work best)
- No social features (this is your personal system)
- No recurring tasks (single-instance simplicity)

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

**Version 2.1** | Made for humans who type faster than they click (but can drag too)

### What's New in 2.1

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
