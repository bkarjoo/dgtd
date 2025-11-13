-- DirectGTD Database Schema
-- Unified item model for GTD workflow

CREATE TABLE folders (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    parent_id TEXT,
    icon TEXT,
    color TEXT,
    sort_order INTEGER DEFAULT 0,
    is_expanded BOOLEAN DEFAULT 1,
    created_at INTEGER NOT NULL,
    modified_at INTEGER NOT NULL,

    FOREIGN KEY (parent_id) REFERENCES folders(id) ON DELETE CASCADE
);

-- Trigger to prevent circular references in folder hierarchy
CREATE TRIGGER prevent_folder_circular_reference
BEFORE UPDATE OF parent_id ON folders
FOR EACH ROW
WHEN NEW.parent_id IS NOT NULL
BEGIN
    SELECT RAISE(ABORT, 'Circular reference detected in folder hierarchy')
    WHERE EXISTS (
        WITH RECURSIVE ancestors(id) AS (
            SELECT NEW.parent_id
            UNION ALL
            SELECT parent_id FROM folders, ancestors WHERE folders.id = ancestors.id
        )
        SELECT 1 FROM ancestors WHERE id = NEW.id
    );
END;

CREATE TABLE items (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT, -- brief "what is it" clarifier

    -- Hierarchy
    parent_id TEXT,
    sort_order INTEGER DEFAULT 0,

    -- GTD workflow
    status TEXT DEFAULT 'next_action' CHECK(status IN ('next_action', 'waiting', 'someday', 'completed')),
    folder_id TEXT, -- reference to folders table
    context TEXT, -- @home, @work, @computer, etc.

    -- Temporal
    created_at INTEGER NOT NULL,
    modified_at INTEGER NOT NULL,
    completed_at INTEGER,
    due_date INTEGER,
    earliest_start_time INTEGER,

    -- Metadata
    is_project BOOLEAN DEFAULT 0,
    energy_level TEXT CHECK(energy_level IN ('high', 'medium', 'low') OR energy_level IS NULL),
    time_estimate INTEGER, -- minutes

    FOREIGN KEY (parent_id) REFERENCES items(id) ON DELETE CASCADE,
    FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE SET NULL
);

CREATE TABLE notes (
    id TEXT PRIMARY KEY,
    item_id TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    modified_at INTEGER NOT NULL,

    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
);

CREATE TABLE tags (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    color TEXT
);

CREATE TABLE item_tags (
    item_id TEXT NOT NULL,
    tag_id TEXT NOT NULL,
    PRIMARY KEY (item_id, tag_id),
    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

-- Indexes for performance
CREATE INDEX idx_folders_parent_id ON folders(parent_id);
CREATE INDEX idx_folders_sort_order ON folders(sort_order);
CREATE INDEX idx_parent_id ON items(parent_id);
CREATE INDEX idx_status ON items(status);
CREATE INDEX idx_folder_id ON items(folder_id);
CREATE INDEX idx_context ON items(context);
CREATE INDEX idx_notes_item ON notes(item_id);
CREATE INDEX idx_item_tags_item ON item_tags(item_id);
CREATE INDEX idx_item_tags_tag ON item_tags(tag_id);
