**Important: Read `README.md` first to understand your role and workflow before starting this assignment.**

**Lifecycle Folder:** remove-folders

**Requirements:** See `.lifecycle/remove-folders/requirements.md` for detailed specifications

## Assignment

Analyze the codebase to create a comprehensive refactoring plan for removing all folder functionality. This is a significant architectural change that needs careful planning.

**Objective:**
Remove all folder-related code from the application. Items should exist independently without folder organization.

**Your Task:**

1. **Identify all folder dependencies:**
   - Search for all references to "Folder" across the codebase
   - Identify all files that use or depend on folders
   - Map out the complete dependency graph

2. **Create comprehensive refactoring plan covering:**
   - Models: Which models need changes? (Folder removal, Item.folderId removal)
   - Database: Schema changes, migration strategy for existing databases
   - UI: Which views need removal/modification? (FolderTreeView, ContentView, etc.)
   - Tests: Which tests need removal/modification?
   - Seeding: DatabaseSeeder and SeedData.json changes
   - Any other impacted areas

3. **Identify risks and edge cases:**
   - Data migration concerns (existing databases with folder data)
   - Breaking changes to app functionality
   - Orphaned data handling
   - State space implications

4. **Recommend implementation sequence:**
   - What order should changes be made?
   - Are there dependencies between changes?
   - Any steps that could be risky?

**Deliverables:**

Your response should include:
- Complete list of files to modify or delete
- Detailed refactoring steps in recommended order
- Database migration strategy
- Risk assessment and mitigation strategies
- Edge cases that must be handled

**When completing this work, include a reminder in your response.md for the recipient to read their README.md as crucial process requirements are documented there.**
