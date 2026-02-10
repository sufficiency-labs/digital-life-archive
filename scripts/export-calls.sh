#!/data/data/com.termux/files/usr/bin/bash
# export-calls.sh — Export call log via Termux:API
# Requires: Termux:API app installed + Phone/Call Log permission granted
#
# Usage: export-calls.sh [limit]
#   limit: number of call records to export (default: 500)
#
# Output: ~/archive/data/calls/calls-YYYYMMDD.json
#
# Troubleshooting: If this hangs, Termux:API is not working.
# See phone-setup.sh header for fix instructions.

set -euo pipefail

LIMIT="${1:-500}"
DATA_DIR="$HOME/archive/data/calls"
DATE=$(date +%Y%m%d)
EXPORT_FILE="$DATA_DIR/calls-${DATE}.json"
CUMULATIVE="$DATA_DIR/all-calls.json"

mkdir -p "$DATA_DIR"

echo "[$(date)] Exporting call log (limit: $LIMIT)..."

# Export via Termux:API
RAW=$(termux-call-log -l "$LIMIT" 2>/dev/null) || {
    echo "[$(date)] ERROR: termux-call-log failed. Is Termux:API installed with Phone permission?"
    exit 1
}

# Validate JSON
if ! echo "$RAW" | jq empty 2>/dev/null; then
    echo "[$(date)] ERROR: Invalid JSON from termux-call-log"
    exit 1
fi

COUNT=$(echo "$RAW" | jq 'length')
echo "[$(date)] Exported $COUNT call records"

# Write daily snapshot
echo "$RAW" | jq '.' > "$EXPORT_FILE"

# Update cumulative file (deduplicate by date+number+duration)
if [ -f "$CUMULATIVE" ]; then
    jq -s '
        [.[0][], .[1][]] |
        group_by(.phone_number + .date + (.duration | tostring)) |
        map(.[0]) |
        sort_by(.date) |
        reverse
    ' "$CUMULATIVE" "$EXPORT_FILE" > "${CUMULATIVE}.tmp"
    mv "${CUMULATIVE}.tmp" "$CUMULATIVE"
    TOTAL=$(jq 'length' "$CUMULATIVE")
    echo "[$(date)] Cumulative total: $TOTAL call records"
else
    cp "$EXPORT_FILE" "$CUMULATIVE"
    echo "[$(date)] Created cumulative file with $COUNT records"
fi

echo "[$(date)] Call log export complete → $EXPORT_FILE"
