#!/bin/bash

# DirectGTD Uninstaller
# Removes all traces of DirectGTD from your system

set -e

echo "DirectGTD Uninstaller"
echo "===================="
echo ""
echo "This will remove:"
echo "  - Application bundle"
echo "  - Database and application support files"
echo "  - Preferences"
echo "  - Caches"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

echo ""
echo "Removing DirectGTD..."

# Remove application bundle
if [ -d "/Applications/DirectGTD.app" ]; then
    echo "  Removing application..."
    rm -rf "/Applications/DirectGTD.app"
fi

# Remove Application Support (database and backups)
if [ -d "$HOME/Library/Application Support/DirectGTD" ]; then
    echo "  Removing database and application support..."
    rm -rf "$HOME/Library/Application Support/DirectGTD"
fi

# Remove Preferences
if [ -f "$HOME/Library/Preferences/com.zendegi.DirectGTD.plist" ]; then
    echo "  Removing preferences..."
    rm -f "$HOME/Library/Preferences/com.zendegi.DirectGTD.plist"
fi

# Remove Caches
if [ -d "$HOME/Library/Caches/com.zendegi.DirectGTD" ]; then
    echo "  Removing caches..."
    rm -rf "$HOME/Library/Caches/com.zendegi.DirectGTD"
fi

# Kill preferences cache
defaults read com.zendegi.DirectGTD &>/dev/null && defaults delete com.zendegi.DirectGTD

echo ""
echo "DirectGTD has been completely removed from your system."
echo "Thank you for using DirectGTD!"
