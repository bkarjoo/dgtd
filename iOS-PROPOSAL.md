# DirectGTD iOS Version Proposal

## Overview

A native iPhone companion app for DirectGTD that syncs with the macOS app via CloudKit. The tree view is the core interface, with expand/collapse functionality matching iOS Reminders and Notes apps.

## Design Philosophy

- **Tree-first**: The hierarchical tree is the primary and default view
- **Expand/collapse**: Native disclosure triangles (like Reminders/Notes), not drill-down navigation
- **Focus mode**: Drill into a folder to see only its subtree, with breadcrumb navigation back
- **Deliberate actions**: No accidental swipes - hold-swipe reveals action buttons
- **Bare essentials**: Core functionality only, complexity stays on desktop

## Implementation Constraints

**DO NOT USE:**
- `NavigationStack` - breaks the custom header bar and focus mode behavior
- `.searchable` modifier - causes unwanted UI changes to the navigation bar

---

## Navigation Architecture

### Main View with Toolbar

```
┌─────────────────────────────────────────────────┐
│  DirectGTD                           🔍  ⚙️     │
├─────────────────────────────────────────────────┤
│                                                 │
│              [Tree Content Area]                │
│                                                 │
│                                                 │
│                                                 │
└─────────────────────────────────────────────────┘
```

### Navigation Elements

- **Tree** - Main view, full hierarchical tree with expand/collapse
- **Search (🔍)** - Top right toolbar icon, opens search sheet
- **Settings (⚙️)** - Top right toolbar icon, opens settings sheet

### Quick Capture Button

Floating "+" button in bottom-right corner:

```
┌─────────────────────────────────────────────────┐
│  DirectGTD                           🔍  ⚙️     │
├─────────────────────────────────────────────────┤
│                                                 │
│              [Tree Content]                     │
│                                                 │
│                                           [+]   │
└─────────────────────────────────────────────────┘
```

- Tap opens Quick Capture sheet
- Creates item in configured quick capture folder (synced from Mac settings)
- Title field auto-focused with keyboard ready
- Optional: type picker, due date quick-set
- "Save" dismisses and syncs immediately

---

## Tree View Design

### Row Layout

```
┌────────────────────────────────────────────────────────┐
│ ▶ Folder Name                                      [>] │
│   ● Task with due date                     Apr 15  [>] │
│   ○ Incomplete task                                [>] │
│   ✓ Completed task                                 [>] │
└────────────────────────────────────────────────────────┘
```

- **Left side**: Indent + expand/collapse triangle (for containers) or status icon
- **Center**: Title + optional metadata (due date, tags)
- **Right side**: Chevron for detail navigation (positioned for thumb reachability)

### Expand/Collapse Behavior

- Tap disclosure triangle to expand/collapse (same as Reminders/Notes apps)
- Folders and projects show triangle when they have children
- Expanded state persists across app launches
- Smooth animation for expand/collapse

### Focus Mode

- Long-press a folder → "Focus" option in context menu
- View shows only that folder's subtree
- Breadcrumb bar appears at top: `Root > Projects > Work`
- Tap any breadcrumb segment to navigate up
- Swipe right from left edge also navigates back
- "Unfocus" button in breadcrumb bar returns to full tree

### Item Actions (Hold-Swipe)

Hold-swipe left to reveal action buttons:

```
┌──────────────────────────────────┬──────────┬──────────┐
│ Task name                        │ Complete │  Delete  │
│                                  │    ✓     │    🗑    │
└──────────────────────────────────┴──────────┴──────────┘
```

- Buttons must be tapped - no swipe-through to complete/delete
- Prevents accidental actions
- Release swipe to hide buttons

### Context Menu (Long Press)

- Complete / Uncomplete
- Edit
- Add Child
- Move to...
- Focus (for folders)
- Delete

---

## Item Detail View

Accessed by tapping the chevron on any row:

```
┌─────────────────────────────────────────────────┐
│ < Back                              Edit        │
├─────────────────────────────────────────────────┤
│ Title: Project Review                           │
│ Type: Task                                      │
│ Due: April 15, 2025                             │
│ Tags: work, priority                            │
├─────────────────────────────────────────────────┤
│ Notes:                                          │
│ Review all active projects and update           │
│ status for weekly meeting.                      │
│                                                 │
└─────────────────────────────────────────────────┘
```

- Edit button enters edit mode for all fields
- Notes display with markdown rendering (view mode)
- Notes edit as plain text (edit mode)

---

## Search

### Search UX Flow

1. **Tap magnifying glass** → keyboard + search bar appear at bottom, header bar hides, tree remains visible (gains header space)
2. **User types something** → search results overlay appears above keyboard/search bar, covering the tree
3. **User clears text OR dismisses keyboard** → search results disappear, tree shows again
4. **Tap a result** → dismisses search, jumps to item in tree AND focuses on it
5. **Header bar** → hidden while in search mode, returns when exiting search

### Search Behavior

- Search results overlay only appears when: (a) keyboard is open AND (b) search text is non-empty
- Tree is always visible "behind" the overlay when no search text
- Searches title and notes (in-memory filtering of loaded items)
- Results appear as flat list with breadcrumb paths

---

## Saved Searches (SQL Power Queries) - Future

This is a separate feature from text search. On macOS, this is currently assigned to the magnifying glass toolbar button (SQL query builder). Not to be confused with Cmd+F style text search.

- List of saved SQL searches synced from Mac
- "Due Today", "Overdue", "This Week" can be saved searches
- Tap to run and see results
- Cannot edit SQL on iOS (view results only)
- **Not part of the current text search implementation**

---

## Settings Tab

### Sync Section

- iCloud sync status indicator
- Last sync timestamp
- "Sync Now" button
- Account name display

### Appearance Section

- Tree font size slider
- Note font size slider
- (Settings persist to device, not synced)

### Data Section

- "Manage Tags" → Tag list with colors
- Quick capture folder picker
- Archive folder picker

### About Section

- Version info
- Help/documentation link

---

## Shared Code Package Migration

Before starting iOS development, extract shared code into a Swift Package:

### Step 1: Create DirectGTDCore Package ✅ COMPLETED

```
DirectGTDCore/
├── Package.swift
├── Sources/
│   └── DirectGTDCore/
│       ├── DirectGTDCore.swift      (DatabaseProvider protocol)
│       ├── Models.swift             (Item, Tag, ItemTag, TimeEntry, SavedSearch, SyncMetadata)
│       ├── ItemRepository.swift     (All CRUD operations, RepositoryError)
│       └── SyncMetadataStore.swift  (Change token management)
└── Tests/
    └── DirectGTDCoreTests/
```

### Step 2: Migration Sequence ✅ COMPLETED

1. ✅ **Create package**: DirectGTDCore with GRDB dependency, added to macOS project
2. ✅ **Move Models.swift**: All models (Item, Tag, ItemTag, TimeEntry, SavedSearch, SyncMetadata)
3. ✅ **Move DatabaseProvider**: Protocol moved to package
4. ✅ **Move ItemRepository.swift**: Full repository with RepositoryError, Array.chunked extension
5. ✅ **Move SyncMetadataStore.swift**: Change token and sync metadata management
6. ✅ **SyncEngine stays in app**: By design - depends on CloudKit, CloudKitManager, platform-specific code

### Step 3: Platform-Specific Code

Code that stays in platform targets (not shared):
- All SwiftUI views
- Platform-specific settings (UserDefaults keys may differ)
- Notification handling (NSApplication vs UIApplication)
- Keyboard shortcuts (macOS only)

---

## Implementation Phases

### Phase 1: Foundation (MVP) ✅ COMPLETED

- [x] Create DirectGTDCore shared package (see migration plan above)
- [x] Migrate macOS app to use shared package
- [x] Create iOS project with shared package dependency
- [x] Main view with toolbar navigation (search + settings icons)
- [x] Tree view with expand/collapse
- [x] Focus mode (tap item to focus, back button to navigate up)
- [x] CloudKit sync (read-only pull from CloudKit)
- [x] Sync error handling (token expiry, zone reset recovery)
- [x] Loading/error UI indicators
- [x] Item detail view (read-only, via long-press → Details)
- [x] Context menu infrastructure (long-press)

### Phase 2: Write Support

Write support requires building iOS push sync infrastructure, then enabling edits.

#### 2a: Sync Infrastructure
- [ ] Add push capability to iOS SyncEngine (mirror macOS push logic)
- [ ] Track dirty items with `needsPush` flag
- [ ] Push on app background / periodic timer
- [ ] Handle push conflicts (server wins for now, same as macOS)

#### 2b: Quick Actions (Simple Writes)
- [ ] Toggle task completion (tap checkbox icon)
- [ ] Delete item (context menu + confirmation)
- [ ] Pull-to-refresh manual sync

#### 2c: Quick Capture
- [ ] Restore floating "+" button
- [ ] Quick capture sheet (title + type picker)
- [ ] Save to Inbox or configured quick capture folder
- [ ] Immediate sync after save

#### 2d: Item Editing
- [ ] Make detail view editable (title, notes, due date, earliest start)
- [ ] Item type picker
- [ ] Save changes on dismiss

### Phase 3: Focus & Search

- [x] Focus mode with back button navigation (completed in Phase 1)
- [ ] Swipe-right gesture to go back in focus mode
- [ ] Search view with text search
- [ ] Saved searches display (read-only, synced from Mac)
- [ ] Search results navigation

### Phase 4: Advanced Editing

- [ ] Add child item (context menu)
- [ ] Add sibling item (context menu)
- [ ] Move item to different parent
- [ ] Hold-swipe to reveal Complete/Delete buttons
- [ ] Reorder items (drag and drop)

### Phase 5: Polish

- [ ] Tag display in tree rows and detail view
- [ ] Tag picker for editing
- [ ] Font size settings
- [ ] Quick capture folder setting
- [ ] Archive folder setting
- [ ] Haptic feedback
- [ ] Accessibility (Dynamic Type, VoiceOver)

### Phase 6: Extras (Future)

- [ ] Home screen widgets (due today, overdue count)
- [ ] Siri shortcuts
- [ ] Background sync with push notifications
- [ ] Share extension (capture from other apps)

---

## Design Decisions

These were open questions, now resolved:

### 1. Markdown in Notes

**Decision**: Toggle edit/preview like Mac (Option B)

- View mode: Rendered markdown
- Edit mode: Plain text editor
- Toggle via Edit button in detail view
- Consistent with macOS behavior

### 2. SQL Saved Searches

**Decision**: Display results only, edit on Mac (Option A)

- iOS shows list of saved searches synced from Mac
- Tap to run and view results
- Cannot create or edit SQL on iOS
- Keeps iOS simple, SQL editing is a power-user desktop activity

### 3. Offline Behavior

**Decision**: Offline-first (same as Mac)

- Full local database on device
- All operations work without network
- Sync happens when connectivity available
- Conflict resolution same as Mac (last-write-wins with merge)

### 4. Quick Capture Folder

**Decision**: Use same folder setting as Mac (synced via CloudKit)

- `quick_capture_folder_id` setting syncs between devices
- Change on either device affects both
- Consistent behavior across platforms
- No confusion about where items go

---

## Success Metrics & Measurement

### Capture Latency: < 2 seconds
*From app open to item saved*

**Measurement**:
- Instrument `QuickCaptureView.saveItem()` with timestamps
- Log: app launch time → save button tap → sync complete
- Track in `os_signpost` for Instruments profiling
- Alert if p95 exceeds 3 seconds

### Sync Latency: < 5 seconds
*For changes to appear on other device*

**Measurement**:
- Add `syncStartTime` and `syncEndTime` to SyncEngine logs
- Log CloudKit operation durations separately (push vs pull)
- Track in Settings → Sync section: "Last sync took X.Xs"
- Monitor via CloudKit Dashboard for server-side metrics

### Task Completion: 2 taps
*Hold-swipe + tap Complete button*

**Measurement**:
- Manual QA validation during development
- Count gesture steps in test scripts
- No runtime instrumentation needed (UX metric)

### Browse Depth: ≤ 4 taps to any item

**Measurement**:
- Manual QA with sample data hierarchies
- Test cases: 1-level, 3-level, 5-level deep items
- Verify expand/collapse + detail access within budget

### App Size: < 20 MB download

**Measurement**:
- Check App Store Connect after archive upload
- Monitor per-phase: shared package, assets, dependencies
- Set CI alert if IPA exceeds 15 MB (buffer for growth)

---

## Summary

This iOS app focuses on being a great **companion** to the Mac app, not a replacement. It excels at:

- **Quick capture** when ideas strike (floating + button, < 2 sec to save)
- **Reviewing** what's due and overdue (via saved searches)
- **Completing tasks** throughout the day
- **Staying in sync** with the desktop

Complex operations like bulk reorganization, template creation, and SQL query writing remain desktop activities. The phone is for capturing, checking, and completing.
