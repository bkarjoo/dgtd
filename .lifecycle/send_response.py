#!/usr/bin/env python3
"""
Send a response from a team member back to the project planner.
Archives the response in the lifecycle folder.

Usage: python3 send_response.py <team_member> <lifecycle_folder>
Example: python3 send_response.py dev feature-dark-mode
"""

import sys
import os
import shutil
from datetime import datetime
from pathlib import Path

def send_response(submitting_team_member, lifecycle_folder):
    # Validate team member - must use standardized names
    valid_teams = ['dev', 'test', 'review', 'doc']
    if submitting_team_member not in valid_teams:
        print(f"Error: Invalid team member '{submitting_team_member}'")
        print(f"Must use standardized team member names: {', '.join(valid_teams)}")
        return False

    # Validate lifecycle folder name
    if not lifecycle_folder or '/' in lifecycle_folder or '\\' in lifecycle_folder:
        print(f"Error: Invalid lifecycle folder name '{lifecycle_folder}'")
        print("Lifecycle folder must be a simple name (e.g., 'feature-dark-mode' or 'issue-123')")
        return False

    # Get project root (parent of .lifecycle)
    project_root = Path(__file__).parent.parent

    # Source: response.md in team member's directory
    source_dir = project_root / f'.{submitting_team_member}'
    source_file = source_dir / 'response.md'

    if not source_file.exists():
        print(f"Error: {source_file} does not exist")
        return False

    # Destination: response.md in .plan/
    dest_dir = project_root / '.plan'
    dest_file = dest_dir / 'response.md'

    # Archive: timestamped copy in lifecycle folder
    lifecycle_dir = project_root / '.lifecycle' / lifecycle_folder

    # Lifecycle folder must exist (created by planner when sending request)
    if not lifecycle_dir.exists():
        print(f"Error: Lifecycle folder does not exist: {lifecycle_dir.relative_to(project_root)}")
        print("The project planner should have created this folder when sending the request.")
        return False

    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    archive_file = lifecycle_dir / f'{timestamp}_response_from_{submitting_team_member}.md'

    # Copy to .plan/
    shutil.copy2(source_file, dest_file)
    print(f"✓ Sent response to .plan/response.md")

    # Archive to lifecycle
    shutil.copy2(source_file, archive_file)
    print(f"✓ Archived to {archive_file.relative_to(project_root)}")

    # Delete original response from team member's directory
    source_file.unlink()
    print(f"✓ Removed .{submitting_team_member}/response.md")

    # Delete request.md from team member's directory (work is complete)
    request_file = source_dir / 'request.md'
    if request_file.exists():
        request_file.unlink()
        print(f"✓ Removed .{submitting_team_member}/request.md")

    return True

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python3 send_response.py <team_member> <lifecycle_folder>")
        print("Example: python3 send_response.py dev feature-dark-mode")
        sys.exit(1)

    team_member = sys.argv[1]
    lifecycle_folder = sys.argv[2]

    success = send_response(team_member, lifecycle_folder)
    sys.exit(0 if success else 1)
