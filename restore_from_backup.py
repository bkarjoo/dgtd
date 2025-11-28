#!/usr/bin/env python3
"""
DirectGTD Backup Restoration Script

This script helps you restore DirectGTD from a backup.
Use this to undo an import or recover from data issues.

Usage:
    python3 restore_from_backup.py
"""

import os
import shutil
from datetime import datetime

# Paths
DIRECTGTD_DB_PATH = os.path.expanduser("~/Library/Application Support/DirectGTD/directgtd.sqlite")
BACKUP_DIR = os.path.expanduser("~/Library/Application Support/DirectGTD/backups")

def list_backups():
    """List all available backups"""
    if not os.path.exists(BACKUP_DIR):
        print("No backups found.")
        return []

    backups = []
    for filename in sorted(os.listdir(BACKUP_DIR), reverse=True):
        if filename.endswith('.sqlite'):
            filepath = os.path.join(BACKUP_DIR, filename)
            stat = os.stat(filepath)
            size_mb = stat.st_size / (1024 * 1024)
            mtime = datetime.fromtimestamp(stat.st_mtime)
            backups.append({
                'filename': filename,
                'filepath': filepath,
                'size_mb': size_mb,
                'modified': mtime
            })

    return backups

def restore_backup(backup_path):
    """Restore database from backup"""
    if not os.path.exists(backup_path):
        print(f"✗ Backup not found: {backup_path}")
        return False

    # Create a backup of current state before restoring
    if os.path.exists(DIRECTGTD_DB_PATH):
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        pre_restore_backup = os.path.join(BACKUP_DIR, f"directgtd_pre_restore_{timestamp}.sqlite")
        shutil.copy2(DIRECTGTD_DB_PATH, pre_restore_backup)
        print(f"✓ Created pre-restore backup: {pre_restore_backup}")

    # Restore from backup
    shutil.copy2(backup_path, DIRECTGTD_DB_PATH)
    print(f"✓ Restored from backup")
    return True

def main():
    print("=" * 70)
    print("DirectGTD Backup Restoration")
    print("=" * 70)
    print()

    # List available backups
    backups = list_backups()

    if not backups:
        print("No backups available.")
        return

    print("Available backups:")
    print()
    for i, backup in enumerate(backups, 1):
        print(f"{i}. {backup['filename']}")
        print(f"   Modified: {backup['modified'].strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"   Size: {backup['size_mb']:.2f} MB")
        print()

    # Get user selection
    while True:
        try:
            choice = input("Select backup to restore (number) or 'q' to quit: ").strip()
            if choice.lower() == 'q':
                print("Cancelled.")
                return

            idx = int(choice) - 1
            if 0 <= idx < len(backups):
                selected_backup = backups[idx]
                break
            else:
                print(f"Please enter a number between 1 and {len(backups)}")
        except ValueError:
            print("Invalid input. Please enter a number.")

    # Confirm restoration
    print()
    print(f"You are about to restore from:")
    print(f"  {selected_backup['filename']}")
    print(f"  Modified: {selected_backup['modified'].strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    print("⚠️  WARNING: This will replace your current DirectGTD database!")
    print("   Make sure DirectGTD app is closed before proceeding.")
    print()

    confirm = input("Type 'YES' to confirm restoration: ").strip()
    if confirm != 'YES':
        print("Cancelled.")
        return

    # Perform restoration
    print()
    print("-" * 70)
    if restore_backup(selected_backup['filepath']):
        print()
        print("=" * 70)
        print("Restoration Complete!")
        print("=" * 70)
        print()
        print("You can now open DirectGTD with the restored data.")
    else:
        print()
        print("✗ Restoration failed.")

if __name__ == "__main__":
    main()
