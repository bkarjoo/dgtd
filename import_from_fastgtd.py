#!/usr/bin/env python3
"""
FastGTD → DirectGTD Import Script

This script imports data from FastGTD (PostgreSQL) to DirectGTD (SQLite).

What gets imported:
- Nodes (tasks, notes, folders, templates) → items
- Tags → tags
- Node-tag associations → item_tags

What gets skipped:
- Smart folders (DirectGTD uses saved searches instead)
- Artifacts/attachments (not yet supported)
- Rules (not yet supported)
- Template-specific fields (imported as basic items)
- Legacy task/note/list tables (only imports from unified nodes table)

Requirements:
    pip install psycopg2-binary

Before running:
1. Fill in FASTGTD_* connection details below
2. Fill in FASTGTD_OWNER_ID (the user whose data you want to import)
3. Make sure DirectGTD app is closed
"""

import sqlite3
import psycopg2
from datetime import datetime
from typing import Dict, List, Optional, Any
import os
import shutil

# ============================================================================
# CONFIGURATION - FILL THESE IN!
# ============================================================================

# FastGTD PostgreSQL Connection
FASTGTD_HOST = "localhost"
FASTGTD_PORT = 5432
FASTGTD_DATABASE = "fastgtd"
FASTGTD_USER = "behroozkarjoo"  # PostgreSQL username
FASTGTD_PASSWORD = ""  # Empty password (no password set)

# Which FastGTD user to import
# Option 1: Specify email (script will look up UUID automatically)
FASTGTD_USER_EMAIL = "bkarjoo@gmail.com"
# Option 2: Or specify UUID directly (leave email as None to use this)
FASTGTD_OWNER_ID = None  # Will be looked up automatically by email

# DirectGTD SQLite Database Path (sandboxed app location)
DIRECTGTD_DB_PATH = os.path.expanduser("~/Library/Containers/com.zendegi.DirectGTD/Data/Library/Application Support/DirectGTD/directgtd.sqlite")

# Backup path (created automatically before import)
BACKUP_DIR = os.path.expanduser("~/Library/Containers/com.zendegi.DirectGTD/Data/Library/Application Support/DirectGTD/backups")

# ============================================================================
# DATA TRANSFORMATIONS
# ============================================================================

# Map FastGTD node_type to DirectGTD itemType
NODE_TYPE_MAPPING = {
    "task": "Task",
    "note": "Note",
    "folder": "Folder",
    "template": "Template",
    "project": "Project",  # FastGTD projects
    "heading": "Heading",  # If FastGTD has headings
    "link": "Link",        # If FastGTD has links
    # "smart_folder": skipped entirely (will be handled as saved searches)
}

def datetime_to_unix(dt: Optional[datetime]) -> Optional[int]:
    """Convert PostgreSQL datetime to Unix timestamp"""
    if dt is None:
        return None
    return int(dt.timestamp())

def uuid_to_string(uuid_val) -> str:
    """Convert UUID to string"""
    return str(uuid_val)

# ============================================================================
# DATABASE CONNECTIONS
# ============================================================================

def connect_fastgtd():
    """Connect to FastGTD PostgreSQL database"""
    try:
        conn = psycopg2.connect(
            host=FASTGTD_HOST,
            port=FASTGTD_PORT,
            database=FASTGTD_DATABASE,
            user=FASTGTD_USER,
            password=FASTGTD_PASSWORD
        )
        print(f"✓ Connected to FastGTD database")
        return conn
    except Exception as e:
        print(f"✗ Failed to connect to FastGTD: {e}")
        raise

def get_user_id_by_email(pg_conn, email: str) -> Optional[str]:
    """Look up user UUID by email address"""
    cursor = pg_conn.cursor()
    cursor.execute("SELECT id, email, full_name FROM users WHERE email = %s", (email,))
    row = cursor.fetchone()

    if row:
        user_id = uuid_to_string(row[0])
        user_email = row[1]
        user_name = row[2] or "Unknown"
        print(f"✓ Found user: {user_name} ({user_email})")
        print(f"  User ID: {user_id}")
        return user_id
    else:
        print(f"✗ No user found with email: {email}")
        return None

def connect_directgtd():
    """Connect to DirectGTD SQLite database"""
    if not os.path.exists(DIRECTGTD_DB_PATH):
        print(f"✗ DirectGTD database not found at: {DIRECTGTD_DB_PATH}")
        print(f"  Please run DirectGTD app at least once to create the database.")
        raise FileNotFoundError(DIRECTGTD_DB_PATH)

    conn = sqlite3.connect(DIRECTGTD_DB_PATH)
    print(f"✓ Connected to DirectGTD database")
    return conn

def create_backup():
    """Create a backup of the DirectGTD database before import"""
    if not os.path.exists(DIRECTGTD_DB_PATH):
        print("✗ No database to backup")
        return None

    # Create backup directory if it doesn't exist
    os.makedirs(BACKUP_DIR, exist_ok=True)

    # Generate timestamped backup filename
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_filename = f"directgtd_backup_{timestamp}.sqlite"
    backup_path = os.path.join(BACKUP_DIR, backup_filename)

    # Copy database file
    shutil.copy2(DIRECTGTD_DB_PATH, backup_path)
    print(f"✓ Created backup: {backup_path}")
    return backup_path

# ============================================================================
# DATA EXTRACTION FROM FASTGTD
# ============================================================================

def extract_nodes(pg_conn, owner_id: str) -> List[Dict[str, Any]]:
    """Extract nodes with their specialized data from FastGTD"""
    cursor = pg_conn.cursor()

    query = """
    SELECT
        n.id,
        n.parent_id,
        n.node_type,
        n.title,
        n.sort_order,
        n.created_at,
        n.updated_at,
        -- Task fields
        t.description as task_description,
        t.status,
        t.priority,
        t.due_at,
        t.earliest_start_at,
        t.completed_at,
        t.archived,
        t.recurrence_rule,
        t.recurrence_anchor,
        -- Note fields
        nt.body as note_body,
        -- Folder fields
        f.description as folder_description,
        -- Template fields (import as basic items, skip special fields)
        tmpl.description as template_description
    FROM nodes n
    LEFT JOIN node_tasks t ON n.id = t.id
    LEFT JOIN node_notes nt ON n.id = nt.id
    LEFT JOIN node_folders f ON n.id = f.id
    LEFT JOIN node_templates tmpl ON n.id = tmpl.id
    WHERE n.owner_id = %s
      AND n.node_type != 'smart_folder'  -- Skip smart folders
    ORDER BY n.created_at ASC
    """

    cursor.execute(query, (owner_id,))
    rows = cursor.fetchall()

    nodes = []
    for row in rows:
        node_type = row[2]

        # Determine what goes in the notes field based on node type
        notes = None
        if node_type == 'task' and row[7]:  # task_description
            notes = row[7]
        elif node_type == 'note' and row[16]:  # note_body
            notes = row[16]
        elif node_type == 'folder' and row[17]:  # folder_description
            notes = row[17]
        elif node_type == 'template' and row[18]:  # template_description
            notes = row[18]

        # Determine completedAt (only for tasks with status='done')
        completed_at = None
        if node_type == 'task':
            if row[12]:  # completed_at from database
                completed_at = row[12]
            elif row[8] == 'done':  # status is done but no completed_at
                completed_at = row[6]  # use updated_at as fallback

        node = {
            'id': uuid_to_string(row[0]),
            'parent_id': uuid_to_string(row[1]) if row[1] else None,
            'node_type': row[2],
            'title': row[3],
            'sort_order': row[4],
            'created_at': row[5],
            'updated_at': row[6],
            'notes': notes,
            # Task-specific
            'due_at': row[10],
            'earliest_start_at': row[11],
            'completed_at': completed_at,
        }
        nodes.append(node)

    print(f"✓ Extracted {len(nodes)} nodes from FastGTD")
    return nodes

def extract_tags(pg_conn, owner_id: str) -> List[Dict[str, Any]]:
    """Extract tags from FastGTD"""
    cursor = pg_conn.cursor()

    query = """
    SELECT id, name, color, description, created_at, updated_at
    FROM tags
    WHERE owner_id = %s
    ORDER BY name ASC
    """

    cursor.execute(query, (owner_id,))
    rows = cursor.fetchall()

    tags = []
    for row in rows:
        tag = {
            'id': uuid_to_string(row[0]),
            'name': row[1],
            'color': row[2],
            'description': row[3],
            'created_at': row[4],
            'updated_at': row[5],
        }
        tags.append(tag)

    print(f"✓ Extracted {len(tags)} tags from FastGTD")
    return tags

def extract_node_tags(pg_conn, owner_id: str) -> List[Dict[str, str]]:
    """Extract node-tag associations from FastGTD"""
    cursor = pg_conn.cursor()

    # Only get associations for nodes belonging to the target owner
    query = """
    SELECT nt.node_id, nt.tag_id
    FROM node_tags nt
    INNER JOIN nodes n ON nt.node_id = n.id
    WHERE n.owner_id = %s
      AND n.node_type != 'smart_folder'
    """

    cursor.execute(query, (owner_id,))
    rows = cursor.fetchall()

    associations = []
    for row in rows:
        assoc = {
            'node_id': uuid_to_string(row[0]),
            'tag_id': uuid_to_string(row[1]),
        }
        associations.append(assoc)

    print(f"✓ Extracted {len(associations)} node-tag associations from FastGTD")
    return associations

# ============================================================================
# DATA IMPORT TO DIRECTGTD
# ============================================================================

def import_items(sqlite_conn, nodes: List[Dict[str, Any]]):
    """Import nodes as items into DirectGTD"""
    cursor = sqlite_conn.cursor()

    imported = 0
    skipped = 0
    orphaned = 0

    # Track successfully imported item IDs to handle orphaned children
    imported_ids = set()

    # First pass: Import all items, tracking which ones succeed
    for node in nodes:
        node_type = node['node_type']

        # Map node_type to DirectGTD itemType
        if node_type not in NODE_TYPE_MAPPING:
            print(f"  ⊘ Skipping unsupported node type: {node_type} (id: {node['id'][:8]}...)")
            skipped += 1
            continue

        item_type = NODE_TYPE_MAPPING[node_type]

        # Check if parent was imported (or is None/null)
        parent_id = node['parent_id']
        if parent_id is not None and parent_id not in imported_ids:
            # Parent hasn't been imported yet - will be handled in second pass
            parent_id = None
            orphaned += 1

        try:
            cursor.execute("""
                INSERT INTO items (
                    id, title, item_type, notes,
                    parent_id, sort_order,
                    created_at, modified_at,
                    completed_at, due_date, earliest_start_time
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                node['id'],
                node['title'],
                item_type,
                node['notes'],
                parent_id,  # Use potentially-remapped parent_id
                node['sort_order'],
                datetime_to_unix(node['created_at']),
                datetime_to_unix(node['updated_at']),
                datetime_to_unix(node['completed_at']),
                datetime_to_unix(node['due_at']),
                datetime_to_unix(node['earliest_start_at']),
            ))
            imported_ids.add(node['id'])
            imported += 1
        except sqlite3.IntegrityError as e:
            print(f"  ✗ Failed to import item {node['id'][:8]}...: {e}")
            skipped += 1

    # Second pass: Restore parent relationships for items whose parents were imported
    restored = 0
    for node in nodes:
        if node['id'] not in imported_ids:
            continue  # This item wasn't imported, skip

        original_parent_id = node['parent_id']
        if original_parent_id and original_parent_id in imported_ids:
            # Parent exists in imported set, restore the relationship
            try:
                cursor.execute("""
                    UPDATE items SET parent_id = ? WHERE id = ?
                """, (original_parent_id, node['id']))
                restored += 1
            except sqlite3.IntegrityError:
                pass  # Shouldn't happen, but fail silently

    sqlite_conn.commit()
    print(f"✓ Imported {imported} items ({skipped} skipped, {orphaned} orphaned → root, {restored} parent links restored)")

def import_tags(sqlite_conn, tags: List[Dict[str, Any]]):
    """Import tags into DirectGTD"""
    cursor = sqlite_conn.cursor()

    imported = 0
    skipped = 0

    for tag in tags:
        try:
            # DirectGTD currently only supports: id, name, color
            # We're dropping description and timestamps for now
            cursor.execute("""
                INSERT INTO tags (id, name, color)
                VALUES (?, ?, ?)
            """, (
                tag['id'],
                tag['name'],
                tag['color'],
            ))
            imported += 1
        except sqlite3.IntegrityError as e:
            print(f"  ✗ Failed to import tag '{tag['name']}': {e}")
            skipped += 1

    sqlite_conn.commit()
    print(f"✓ Imported {imported} tags ({skipped} skipped)")

def import_item_tags(sqlite_conn, associations: List[Dict[str, str]]):
    """Import item-tag associations into DirectGTD"""
    cursor = sqlite_conn.cursor()

    imported = 0
    skipped = 0

    for assoc in associations:
        try:
            cursor.execute("""
                INSERT INTO item_tags (item_id, tag_id)
                VALUES (?, ?)
            """, (
                assoc['node_id'],
                assoc['tag_id'],
            ))
            imported += 1
        except sqlite3.IntegrityError as e:
            # Silently skip duplicates or missing references
            skipped += 1

    sqlite_conn.commit()
    print(f"✓ Imported {imported} item-tag associations ({skipped} skipped)")

# ============================================================================
# VALIDATION
# ============================================================================

def validate_config():
    """Validate configuration before running"""
    errors = []

    # Check if either email or owner_id is provided
    if not FASTGTD_USER_EMAIL and not FASTGTD_OWNER_ID:
        errors.append("Must specify either FASTGTD_USER_EMAIL or FASTGTD_OWNER_ID")

    if errors:
        print("✗ Configuration errors:")
        for error in errors:
            print(f"  - {error}")
        print("\nPlease edit the script and fill in the configuration values at the top.")
        return False

    return True

# ============================================================================
# MAIN
# ============================================================================

def main():
    print("=" * 70)
    print("FastGTD → DirectGTD Import Script")
    print("=" * 70)
    print()

    # Validate configuration
    if not validate_config():
        return

    print(f"Configuration:")
    print(f"  FastGTD: {FASTGTD_USER}@{FASTGTD_HOST}:{FASTGTD_PORT}/{FASTGTD_DATABASE}")
    if FASTGTD_USER_EMAIL:
        print(f"  User Email: {FASTGTD_USER_EMAIL}")
    else:
        print(f"  Owner ID: {FASTGTD_OWNER_ID}")
    print(f"  DirectGTD: {DIRECTGTD_DB_PATH}")
    print()

    print("-" * 70)
    print("Step 1: Connecting to FastGTD and looking up user")
    print("-" * 70)

    pg_conn = connect_fastgtd()

    # Look up owner ID by email if needed
    owner_id = FASTGTD_OWNER_ID
    if FASTGTD_USER_EMAIL and not owner_id:
        owner_id = get_user_id_by_email(pg_conn, FASTGTD_USER_EMAIL)
        if not owner_id:
            print("✗ Could not find user. Import cancelled.")
            pg_conn.close()
            return

    print()
    print("-" * 70)
    print("Data to Import")
    print("-" * 70)
    print(f"  User: {FASTGTD_USER_EMAIL or 'Unknown'}")
    print(f"  User ID: {owner_id}")
    print()

    # Confirm before proceeding
    response = input("Proceed with import? This will add data to DirectGTD. (yes/no): ")
    if response.lower() != 'yes':
        print("Import cancelled.")
        pg_conn.close()
        return

    print()
    print("-" * 70)
    print("Step 2: Creating backup")
    print("-" * 70)

    backup_path = create_backup()

    print()
    print("-" * 70)
    print("Step 3: Connecting to DirectGTD")
    print("-" * 70)

    sqlite_conn = connect_directgtd()

    print()
    print("-" * 70)
    print("Step 4: Extracting data from FastGTD")
    print("-" * 70)

    nodes = extract_nodes(pg_conn, owner_id)
    tags = extract_tags(pg_conn, owner_id)
    node_tags = extract_node_tags(pg_conn, owner_id)

    print()
    print("-" * 70)
    print("Step 5: Importing data into DirectGTD")
    print("-" * 70)

    import_items(sqlite_conn, nodes)
    import_tags(sqlite_conn, tags)
    import_item_tags(sqlite_conn, node_tags)

    print()
    print("-" * 70)
    print("Step 6: Cleanup")
    print("-" * 70)

    pg_conn.close()
    sqlite_conn.close()
    print("✓ Closed database connections")

    print()
    print("=" * 70)
    print("Import Complete!")
    print("=" * 70)
    print()
    print("Summary:")
    print(f"  • {len(nodes)} nodes → items")
    print(f"  • {len(tags)} tags")
    print(f"  • {len(node_tags)} item-tag associations")
    print()
    if backup_path:
        print("Backup created at:")
        print(f"  {backup_path}")
        print()
        print("To UNDO this import (restore from backup):")
        print("  1. Close DirectGTD app")
        print(f"  2. cp \"{backup_path}\" \"{DIRECTGTD_DB_PATH}\"")
        print()
    print("You can now open DirectGTD to see your imported data.")
    print()

if __name__ == "__main__":
    main()
