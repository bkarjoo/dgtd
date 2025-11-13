#!/usr/bin/env python3
"""
Send a request from project planner to a team member.
Archives the request in the lifecycle folder.

Usage: python3 send_request.py <team_member> <lifecycle_folder>
Example: python3 send_request.py dev feature-dark-mode
"""

import sys
import os
import shutil
from datetime import datetime
from pathlib import Path

def send_request(recipient_team_member, lifecycle_folder):
    # Validate team member - must use standardized names
    valid_teams = ['dev', 'test', 'review', 'doc']
    if recipient_team_member not in valid_teams:
        print(f"Error: Invalid team member '{recipient_team_member}'")
        print(f"Must use standardized team member names: {', '.join(valid_teams)}")
        return False

    # Validate lifecycle folder name
    if not lifecycle_folder or '/' in lifecycle_folder or '\\' in lifecycle_folder:
        print(f"Error: Invalid lifecycle folder name '{lifecycle_folder}'")
        print("Lifecycle folder must be a simple name (e.g., 'feature-dark-mode' or 'issue-123')")
        return False

    # Get project root (parent of .plan)
    project_root = Path(__file__).parent.parent

    # Source: request.md in .plan/
    source_file = project_root / '.plan' / 'request.md'
    if not source_file.exists():
        print(f"Error: {source_file} does not exist")
        return False

    # Validation Check 1: Lifecycle folder must exist
    lifecycle_dir = project_root / '.lifecycle' / lifecycle_folder
    if not lifecycle_dir.exists():
        print(f"Error: Lifecycle folder '.lifecycle/{lifecycle_folder}' does not exist")
        print("Please create the lifecycle folder first")
        return False

    # Validation Check 2: requirements.md must exist in lifecycle folder
    requirements_file = lifecycle_dir / 'requirements.md'
    if not requirements_file.exists():
        print(f"Error: requirements.md not found in '.lifecycle/{lifecycle_folder}/'")
        print("Please create requirements.md with detailed specifications")
        return False

    # Validation Check 3: request.md must reference the requirements.md
    with open(source_file, 'r') as f:
        request_content = f.read()

    expected_reference = f".lifecycle/{lifecycle_folder}/requirements.md"
    if expected_reference not in request_content:
        print(f"Error: request.md does not reference '{expected_reference}'")
        print("Please update request.md to reference the requirements file")
        return False

    # Destination: request.md in team member's directory
    dest_dir = project_root / f'.{recipient_team_member}'
    dest_file = dest_dir / 'request.md'

    # Create destination directory if it doesn't exist
    dest_dir.mkdir(exist_ok=True)

    # Archive: timestamped copy in lifecycle folder

    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    archive_file = lifecycle_dir / f'{timestamp}_request_to_{recipient_team_member}.md'

    # Copy to destination
    shutil.copy2(source_file, dest_file)
    print(f"✓ Sent request to .{recipient_team_member}/request.md")

    # Archive to lifecycle
    shutil.copy2(source_file, archive_file)
    print(f"✓ Archived to {archive_file.relative_to(project_root)}")

    # Delete original from .plan/
    source_file.unlink()
    print(f"✓ Removed .plan/request.md")

    return True

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python3 send_request.py <team_member> <lifecycle_folder>")
        print("Example: python3 send_request.py dev feature-dark-mode")
        sys.exit(1)

    team_member = sys.argv[1]
    lifecycle_folder = sys.argv[2]

    success = send_request(team_member, lifecycle_folder)
    sys.exit(0 if success else 1)
