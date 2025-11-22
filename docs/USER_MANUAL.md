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
- Toggle task completion
- (More features coming)

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

**To make something a child item:**
1. Select the item
2. Hit **Tab**

**To promote it back:**
1. Hit **Shift+Tab**

**To expand/collapse:**
- **→** expands the selected parent item
- **←** collapses the selected parent item
- Or click the chevron (► or ▼)

Parent items automatically get a chevron. Everything's keyboard accessible now.

*[Screenshot: Hierarchical item list with indentation and chevrons]*

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

## Reordering Items

Move items up/down within their current level:

- **Cmd+↑** - Move item up (swaps with item above)
- **Cmd+↓** - Move item down (swaps with item below)

Only works among siblings (same parent, same level). Want to move to a different level? Use Tab/Shift+Tab.

*[Screenshot: Item being reordered with Cmd+arrows]*

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
- **Filter by tag** - Click tag icon to see only items in a specific context (home, work, etc.)
- **Tags for contexts** - Tag tasks with contexts (home, work, computer) for GTD workflow
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
- **Tags** - Flexible, color-coded organization for GTD contexts
- **Search** - Instant filtering to find anything
- **Hierarchy** - Folders and projects with unlimited nesting
- **Keyboard-first** - Every core action has a shortcut
- **Local storage** - Your data stays yours

**What we deliberately don't have:**
- No due dates (yet)
- No drag-and-drop (keyboard is faster)
- No right-click menus (keeps it simple)
- No cloud sync (no synchronization anxiety)
- No AI suggestions (you know your work best)
- No social features (this is your personal system)

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

**Version 2.1** | Made for humans who type faster than they click

### What's New in 2.1

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
