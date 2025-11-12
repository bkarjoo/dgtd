-- DirectGTD Database Schema
-- Unified item model for GTD workflow

CREATE TABLE items (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT, -- brief "what is it" clarifier

    -- Hierarchy
    parent_id TEXT,
    sort_order INTEGER DEFAULT 0,

    -- GTD workflow
    status TEXT DEFAULT 'next_action', -- next_action, waiting, someday, completed
    folder TEXT DEFAULT 'inbox', -- inbox, projects, reference, trash, archive
    context TEXT, -- @home, @work, @computer, etc.

    -- Temporal
    created_at INTEGER NOT NULL,
    modified_at INTEGER NOT NULL,
    completed_at INTEGER,
    due_date INTEGER,
    earliest_start_time INTEGER,

    -- Metadata
    is_project BOOLEAN DEFAULT 0,
    energy_level TEXT, -- high, medium, low
    time_estimate INTEGER, -- minutes

    FOREIGN KEY (parent_id) REFERENCES items(id) ON DELETE CASCADE
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
CREATE INDEX idx_parent_id ON items(parent_id);
CREATE INDEX idx_status ON items(status);
CREATE INDEX idx_folder ON items(folder);
CREATE INDEX idx_context ON items(context);
CREATE INDEX idx_notes_item ON notes(item_id);
CREATE INDEX idx_item_tags_item ON item_tags(item_id);
CREATE INDEX idx_item_tags_tag ON item_tags(tag_id);
