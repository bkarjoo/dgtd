# Remove Folders Functionality

Remove all folder-related functionality from the application. The app should work without folders - items exist independently without folder organization.

## Scope

**Remove:**
- Folder model and database table
- Folder references from Item model (folderId field)
- FolderTreeView.swift
- Folder seeding from DatabaseSeeder
- Folder-related tests (FolderCircularReferenceTests)
- Any UI components that display or interact with folders

**Update:**
- Database schema/migrations to remove folders table and folder_id from items
- Item model to remove folderId field
- DatabaseSeeder to not create folders
- SeedData.json to remove folder references
- Main app UI to work without folder hierarchy

## Constraints

- Must maintain all existing item functionality (tags, status, GTD workflow)
- Must not break existing tests for items, tags, database migrations
- Must provide clean migration path (existing databases should handle missing folders gracefully)
