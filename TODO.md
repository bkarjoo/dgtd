# TODO

## SmartFolders Requirements

- Scope: SmartFolders are items of type SmartFolder that display dynamic query results; target users are SQL-proficient, so UI is minimal.
- Storage
    - Add a smart_folder_query TEXT column (nullable) to items.
    - SmartFolder rows must have item_type = 'SmartFolder' and non‑NULL smart_folder_query.
    - Migration should leave existing data untouched; seeded SmartFolders will populate this column.
- Query Execution
    - Run the SQL exactly as stored, but enforce READ‑ONLY:
        - Use SQLite's authorizer (or simple parser) to reject any statement that isn't a single SELECT.
        - Disallow multiple statements, ATTACH, PRAGMA writes, etc.
        - Execute via a dedicated read-only connection/context with a short timeout (e.g., 250 ms) so expensive queries can't freeze the UI.
    - Parameters:
        - Provide ? bindings for dynamic values if needed (e.g., :now), or allow users to call strftime('%s','now') directly; document whichever
          approach is chosen.
    - Result set should be item IDs; if a query returns extra columns, ignore them.
- UI/UX
    - Tree view shows SmartFolders alongside other items (icon already defined).
    - Selecting a SmartFolder runs its query and displays the result list in the main pane; selection/edit commands operate on the result items.
    - SmartFolder editor:
        - Text field (multi-line, monospaced) for raw SQL.
        - "Test Query" button that runs the SQL and reports count + example item titles.
        - Error surface shows SQLite error message with line number if parse/run fails.
        - Collapsible "Schema Reference" panel listing tables/columns and common snippets (joins to item_tags, date helpers).
    - No GUI query builder—SQL is the only authoring method.
- Seeding
    - On first run (or via migration), insert a handful of SmartFolders with predefined SQL (Overdue, Due Today, Due This Week, Ready to Start,
      Completed) to serve as documentation/examples. Users can edit the SQL directly.
- Testing
    - Unit tests ensuring:
        - Non-SELECT queries (e.g., DELETE) are rejected.
        - Queries with syntax errors show the error and don't crash.
        - Sample queries return expected item IDs given synthetic data.
        - Performance: a pathological query times out and surfaces a friendly error.
    - Integration test verifying SmartFolder selection updates the visible list and honors tag/visibility rules if applicable.
- Docs
    - Update in-app help/README to explain SmartFolders, the schema snippet, and sample queries.
    - Call out that queries are raw SQLite and that only SELECT statements are allowed.

This keeps the feature power-user focused: raw SQL only, but safe, documented, and integrated with the existing item tree.
