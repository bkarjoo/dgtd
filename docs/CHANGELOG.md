# Changelog

All notable changes to DirectGTD will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added - 2025-11-11
- Initial database schema design with unified item model
- Support for GTD workflow: inbox, projects, reference, trash folders
- Item statuses: next_action, waiting, someday, completed
- Hierarchical project/task structure with parent_id relationships
- Notes table for detailed item documentation
- Tag system with many-to-many relationships
- Context support (@home, @work, etc.)
- Temporal fields: due dates, earliest start times, completion tracking
- Energy levels and time estimates for better task planning

### Added - 2025-11-12
- Created multiplatform Xcode project for iOS and macOS
- Integrated GRDB.swift for SQLite database management
- Implemented Database.swift singleton for database initialization and access
- Database automatically loads and executes schema.sql on first launch

### Design Decisions - 2025-11-11
- **Unified Item Model**: Single `items` table handles inbox items, tasks, projects, and reference materials to avoid conversion friction as items evolve through GTD workflow
- **Folder vs Status Separation**: `folder` field represents location (inbox, projects, reference, trash), while `status` field represents workflow state (next_action, waiting, someday, completed)
- **Normalized Tags**: Many-to-many relationship for flexible tagging instead of JSON arrays
- **Separate Notes Table**: Notes are their own entities that belong to exactly one item, keeping the items table clean

### Design Decisions - 2025-11-12
- **GRDB over Core Data**: Chose GRDB.swift for direct SQLite access and better control over schema, with plans for custom server sync implementation
- **Schema as SQL File**: Storing schema in database/schema.sql for version control and easy migration management
- **Singleton Database Manager**: Using Database.shared pattern for centralized database access across the app
### Added - 2025-11-12
- App initializes database singleton on launch in DirectGTDApp.swift
- Database.swift checks for existing tables before schema creation to avoid duplicate setup
- Successfully built project for macOS target with GRDB integration

### Added - 2025-11-12
- Created Models.swift with Swift structs for all database entities (Item, Note, Tag, ItemTag)
- Models conform to GRDB's Codable, FetchableRecord, and PersistableRecord protocols
- Implemented snake_case to camelCase mapping between database columns and Swift properties
- Added convenience initializers with sensible defaults (UUID generation, timestamps, default status/folder values)

### Added - 2025-11-12
- Created ItemRepository.swift service layer with comprehensive database operations
- Implemented CRUD methods for Items, Notes, Tags, and ItemTag associations
- Added GTD-specific operations: addToInbox(), getNextActions(), getProjects(), completeItem()
- Implemented folder and status management functions
- Added parent-child relationship handling for projects and sub-items
- Created custom DatabaseError enum for error handling
- Successfully built project with all components integrated

