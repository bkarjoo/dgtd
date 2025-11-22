- Add item_type column to database schema with default Unknown
- Create migration
- Add ItemType enum and itemType property to Item model
- Later add UI to display and change types

- Multiple window support

- When collapsing an item, if a child inside it is selected, change selection to the collapsed parent item

- Add cache invalidation mechanism for ItemStore: Currently ItemStore fetches data on demand via loadItems()/loadTags() with no observers for external DB changes. If edits arrive from another client, background actor, or database migrations, we need to add invalidation (polling, database triggers + notifications, or NotificationCenter signals) so the store knows when to refresh the itemTags cache and items array.

- Optimize tag filtering performance: matchesTagFilter/hasDescendantWithTag recursively walk store.items for every node, resulting in O(n²) complexity on deep or wide trees. Consider adding caching or indexing for large item counts.

- Add UI/integration tests for tag filtering: Current test coverage only validates store layer logic (ItemStore predicates). Add tests for the view wiring between ItemStore ↔ TreeView ↔ TagFilterPickerView to catch regressions in UI code.

---

# Tag System Implementation Plan

## User's Choices:

- UI: Hybrid approach (badges in tree + full editor in detail)
- Style: Simple tags (no GTD prefixes)
- Colors: User-defined with color picker
- Features: Full MVP (add/remove, manager, filter, autocomplete)

---

## Phase 1: Data Model & Store Layer

### First: Make Tag Identifiable (Models.swift)

Add Identifiable conformance to Tag:

```swift
extension Tag: Identifiable {
    // Tag already has 'id' property, just need to declare conformance
}
```

This is required for SwiftUI ForEach iteration in DetailView.

---

### ItemStore.swift Changes

#### Add Published Properties:

```swift
@Published private(set) var tags: [Tag] = []
@Published private(set) var itemTags: [String: [Tag]] = [:] // Cache: itemId -> tags
@Published var filteredByTag: Tag? = nil
```

#### Data Loading & Cache Population:

Modify existing `loadItems()` to also load tags:

```swift
func loadItems() {
    do {
        items = try repository.getAllItems()
        loadTags()  // ← Add this call
    } catch {
        print("Error loading items: \(error)")
    }
}
```

Add new `loadTags()` method:

```swift
func loadTags() {
    do {
        // Load all tags
        tags = try repository.getAllTags()

        // Populate itemTags cache using existing repository method
        let itemIds = items.map { $0.id }
        let allItemTags = try repository.getItemTagsForItems(itemIds: itemIds)

        // Build cache: itemId -> [Tag]
        var cache: [String: [Tag]] = [:]
        for itemTag in allItemTags {
            if let tag = tags.first(where: { $0.id == itemTag.tagId }) {
                cache[itemTag.itemId, default: []].append(tag)
            }
        }
        itemTags = cache
    } catch {
        print("Error loading tags: \(error)")
    }
}
```

**CRITICAL**: Without calling `repository.getItemTagsForItems()` to populate the cache, `itemTags` stays empty and all tag UI will fail.

#### Add Methods:

1. loadTags() - Load all tags and populate itemTags cache (see above)
2. getTagsForItem(itemId: String) -> [Tag] - Get item's tags from cache
3. addTagToItem(itemId: String, tag: Tag) - Associate tag with item, update cache, call loadTags()
4. removeTagFromItem(itemId: String, tagId: String) - Remove association, update cache, call loadTags()
5. createTag(name: String, color: String) -> Tag - Create new tag, call loadTags()
6. updateTag(tag: Tag) - Update tag name/color, call loadTags()
7. deleteTag(tagId: String) - Delete tag, call loadTags()
8. filterByTag(_ tag: Tag?) - Filter tree by tag
9. Register undo for all tag operations

---

## Phase 2: UI Components (New Files)

### Create FlowLayout.swift:

- Custom layout that arranges views horizontally, wrapping to next line when needed
- Similar to CSS flexbox with flex-wrap
- Used in DetailView to display tag chips that wrap naturally
- ~40-60 lines (simple HStack/VStack wrapper with GeometryReader)

**Note**: FlowLayout is required before DetailView integration. Without it, tag chips won't wrap properly.

### Create TagChip.swift:

- Display single tag as colored rounded rectangle
- Show tag name with user-defined background color
- Optional [×] button to remove
- Click to filter (when in tree view)

### Create TagPickerView.swift:

- List of all existing tags with checkboxes
- Search/filter tags by name (autocomplete)
- Click checkbox to add/remove tag from item
- [+ Create New Tag] button at bottom

### Create TagEditorView.swift:

- Text field for tag name
- Color picker for tag color
- Preview of tag chip
- Save/Cancel buttons
- Used for both create and edit

### Create TagManagerView.swift:

- List all tags with usage counts
- Edit button → TagEditorView
- Delete button (with confirmation if used)
- [+ New Tag] button
- Goes in Settings as new section

---

## Phase 3: DetailView Integration

### Add Tag Section to DetailView:

```swift
Section("Tags") {
    // Display TagChips for item's tags
    FlowLayout {
        ForEach(tagsForItem) { tag in
            TagChip(tag: tag, showRemove: true) {
                store.removeTagFromItem(itemId: selectedId, tagId: tag.id)
            }
        }

        // [+ Add Tag] button
        Button(action: { showingTagPicker = true }) {
            Label("Add Tag", systemImage: "plus")
        }
    }
}
.sheet(isPresented: $showingTagPicker) {
    TagPickerView(itemId: selectedId, store: store)
}
```

---

## Phase 4: TreeView Integration

### Modify ItemRow to Show Badge:

- If item has tags, show [N] badge after title (like folder counts)
- Badge color: subtle gray/blue
- Badge only shows count, not tag names
- Position: right-aligned after title text

---

## Phase 5: Settings Integration

### Add Tag Manager Section:

```swift
Section("Tags") {
    NavigationLink("Manage Tags") {
        TagManagerView(store: store)
    }
}
```

---

## Phase 6: Filtering Implementation

### Add Filter UI to ContentView Toolbar:

- Add filter button next to eye icon
- Shows current filter if active
- Click to open tag filter picker
- Clear filter button when active

### Update TreeView to Respect Filter:

- Modify visibleItems computed property
- If store.filteredByTag != nil, only show items with that tag
- Maintain hierarchy (show parent if any child matches)

---

## Phase 7: Autocomplete Implementation

### Add to TagPickerView:

- TextField with .onChange to filter tags
- Show filtered tag list as you type
- Highlight matching text
- Press Enter to select first match

---

## Technical Details:

### Files to Create:

1. DirectGTD/FlowLayout.swift (40-60 lines)
2. DirectGTD/TagChip.swift (20-30 lines)
3. DirectGTD/TagPickerView.swift (80-100 lines)
4. DirectGTD/TagEditorView.swift (60-80 lines)
5. DirectGTD/TagManagerView.swift (80-100 lines)

### Files to Modify:

1. DirectGTD/Models.swift - Add ~5 lines (Identifiable conformance for Tag)
2. DirectGTD/ItemStore.swift - Add ~180 lines (tag methods + cache population)
3. DirectGTD/DetailView.swift - Add ~40 lines (tag section)
4. DirectGTD/TreeView.swift - Add ~20 lines (badge display)
5. DirectGTD/ItemRow.swift - Add ~15 lines (badge in row)
6. DirectGTD/ContentView.swift - Add ~30 lines (filter UI)
7. DirectGTD/SettingsView.swift - Add ~10 lines (tag manager link)

### Test Files to Create:

1. DirectGTDTests/ItemStoreTagTests.swift - Test store methods
2. DirectGTDTests/TagUITests.swift - Test UI components (optional)

**Estimated Lines of Code: ~800-900 total**

---

## Implementation Order:

1. Tag Identifiable conformance (Models.swift - prerequisite)
2. ItemStore tag methods + cache population (foundation)
3. FlowLayout component (prerequisite for DetailView)
4. TagChip component (used everywhere)
5. DetailView tag section (core functionality)
6. TagEditorView (create/edit tags)
7. TagPickerView (select tags for item)
8. TreeView badges (visibility)
9. TagManagerView (Settings integration)
10. Filter implementation (toolbar + tree logic)
11. Autocomplete (polish)
12. Tests (validation)

---

## Expected User Flow:

### Create First Tag:

1. Select item in tree
2. DetailView shows empty "Tags" section
3. Click [+ Add Tag]
4. No tags exist → TagPickerView shows [+ Create New Tag]
5. Click → TagEditorView opens
6. Enter name "urgent", pick red color
7. Save → Tag created and added to item
8. DetailView shows red "urgent" chip

### Add Existing Tag:

1. Select different item
2. Click [+ Add Tag]
3. TagPickerView shows list with "urgent" ☐
4. Check "urgent" checkbox
5. Tag added immediately, picker closes
6. DetailView shows red "urgent" chip

### Filter by Tag:

1. See item with "urgent" tag in tree (shows [1] badge)
2. Click filter button in toolbar
3. Select "urgent" tag
4. Tree shows only items with "urgent" tag
5. Click clear filter to show all

### Manage Tags:

1. Click Settings (gear icon)
2. Click "Manage Tags"
3. See all tags with usage counts
4. Edit "urgent" → change to orange
5. All "urgent" chips update color everywhere
6. Delete unused tags

---

**This plan implements all 4 requested MVP features with the hybrid badge approach and user-defined colors.**
