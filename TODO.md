- Add item_type column to database schema with default Unknown
- Create migration
- Add ItemType enum and itemType property to Item model
- Later add UI to display and change types

- Multiple window support

- When collapsing an item, if a child inside it is selected, change selection to the collapsed parent item

- Add cache invalidation mechanism for ItemStore: Currently ItemStore fetches data on demand via loadItems()/loadTags() with no observers for external DB changes. If edits arrive from another client, background actor, or database migrations, we need to add invalidation (polling, database triggers + notifications, or NotificationCenter signals) so the store knows when to refresh the itemTags cache and items array.

- Optimize tag filtering performance: matchesTagFilter/hasDescendantWithTag recursively walk store.items for every node, resulting in O(n²) complexity on deep or wide trees. Consider adding caching or indexing for large item counts.

- Add UI/integration tests for tag filtering: Current test coverage only validates store layer logic (ItemStore predicates). Add tests for the view wiring between ItemStore ↔ TreeView ↔ TagFilterPickerView to catch regressions in UI code.
