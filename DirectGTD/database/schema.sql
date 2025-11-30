-- DirectGTD Database Schema
-- Unified item model for GTD workflow

CREATE TABLE items (
    id TEXT PRIMARY KEY,
    title TEXT,
    item_type TEXT DEFAULT 'Unknown',
    notes TEXT,

    -- Hierarchy
    parent_id TEXT,
    sort_order INTEGER DEFAULT 0,

    -- Temporal
    created_at INTEGER NOT NULL,
    modified_at INTEGER NOT NULL,
    completed_at INTEGER,
    due_date INTEGER,
    earliest_start_time INTEGER,

    FOREIGN KEY (parent_id) REFERENCES items(id) ON DELETE CASCADE
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

CREATE TABLE app_settings (
    key TEXT PRIMARY KEY,
    value TEXT
);

CREATE TABLE saved_searches (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    sql TEXT NOT NULL,
    sort_order INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL,
    modified_at INTEGER NOT NULL,
    show_ancestors INTEGER NOT NULL DEFAULT 1
);

-- Indexes for performance
CREATE INDEX idx_parent_id ON items(parent_id);
CREATE INDEX idx_item_tags_item ON item_tags(item_id);
CREATE INDEX idx_item_tags_tag ON item_tags(tag_id);
