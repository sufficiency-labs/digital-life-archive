#!/data/data/com.termux/files/usr/bin/bash
# export-contacts.sh — Export phone contacts via Termux:API
# Requires: Termux:API app installed + Contacts permission granted
#
# Usage: export-contacts.sh
#
# Output: ~/archive/data/contacts/contacts-YYYYMMDD.json
# Also diffs against previous export to show changes.
#
# Troubleshooting: If this hangs, Termux:API is not working.
# See phone-setup.sh header for fix instructions.

set -euo pipefail

DATA_DIR="$HOME/archive/data/contacts"
DATE=$(date +%Y%m%d)
EXPORT_FILE="$DATA_DIR/contacts-${DATE}.json"

mkdir -p "$DATA_DIR"

echo "[$(date)] Exporting contacts..."

# Export via Termux:API
RAW=$(termux-contact-list 2>/dev/null) || {
    echo "[$(date)] ERROR: termux-contact-list failed. Is Termux:API installed with Contacts permission?"
    exit 1
}

# Validate JSON
if ! echo "$RAW" | jq empty 2>/dev/null; then
    echo "[$(date)] ERROR: Invalid JSON from termux-contact-list"
    exit 1
fi

COUNT=$(echo "$RAW" | jq 'length')
echo "[$(date)] Exported $COUNT contacts"

# Write export
echo "$RAW" | jq '.' > "$EXPORT_FILE"

# Diff against most recent previous export
PREV=$(ls -1t "$DATA_DIR"/contacts-*.json 2>/dev/null | grep -v "$EXPORT_FILE" | head -1)
if [ -n "$PREV" ] && [ -f "$PREV" ]; then
    PREV_COUNT=$(jq 'length' "$PREV")

    NEW_NAMES=$(jq -r '.[].name' "$EXPORT_FILE" | sort > /tmp/contacts_new.txt && \
                jq -r '.[].name' "$PREV" | sort > /tmp/contacts_old.txt && \
                comm -23 /tmp/contacts_new.txt /tmp/contacts_old.txt)

    REMOVED_NAMES=$(comm -13 /tmp/contacts_new.txt /tmp/contacts_old.txt)

    if [ -n "$NEW_NAMES" ]; then
        echo "[$(date)] New contacts since last export:"
        echo "$NEW_NAMES" | while read -r name; do
            echo "  + $name"
        done
    fi

    if [ -n "$REMOVED_NAMES" ]; then
        echo "[$(date)] Removed contacts since last export:"
        echo "$REMOVED_NAMES" | while read -r name; do
            echo "  - $name"
        done
    fi

    if [ -z "$NEW_NAMES" ] && [ -z "$REMOVED_NAMES" ]; then
        echo "[$(date)] No changes since last export ($PREV_COUNT contacts)"
    fi

    rm -f /tmp/contacts_new.txt /tmp/contacts_old.txt
else
    echo "[$(date)] First export — no previous data to compare"
fi

echo "[$(date)] Contacts export complete → $EXPORT_FILE"
