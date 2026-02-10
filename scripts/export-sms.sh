#!/data/data/com.termux/files/usr/bin/bash
# export-sms.sh — Export SMS/MMS messages via Termux:API
# Requires: Termux:API app installed + SMS permission granted
#
# Usage: export-sms.sh [limit]
#   limit: number of messages to export (default: 5000)
#
# Output: ~/archive/data/sms/sms-YYYYMMDD.json
# Also maintains a cumulative file: ~/archive/data/sms/all-sms.json
#
# Troubleshooting: If this hangs, Termux:API is not working.
# See phone-setup.sh header for fix instructions.

set -euo pipefail

LIMIT="${1:-5000}"
DATA_DIR="$HOME/archive/data/sms"
DATE=$(date +%Y%m%d)
DAILY_FILE="$DATA_DIR/sms-${DATE}.json"
CUMULATIVE="$DATA_DIR/all-sms.json"

mkdir -p "$DATA_DIR"

echo "[$(date)] Exporting SMS messages (limit: $LIMIT)..."

# Export via Termux:API
RAW=$(termux-sms-list -l "$LIMIT" -t all 2>/dev/null) || {
    echo "[$(date)] ERROR: termux-sms-list failed. Is Termux:API installed with SMS permission?"
    exit 1
}

# Validate JSON
if ! echo "$RAW" | jq empty 2>/dev/null; then
    echo "[$(date)] ERROR: Invalid JSON from termux-sms-list"
    exit 1
fi

COUNT=$(echo "$RAW" | jq 'length')
echo "[$(date)] Exported $COUNT messages"

# Write daily snapshot
echo "$RAW" | jq '.' > "$DAILY_FILE"

# Update cumulative file (deduplicate by combining and deduping on date+number+body)
if [ -f "$CUMULATIVE" ]; then
    jq -s '
        [.[0][], .[1][]] |
        group_by(.number + .received + .body) |
        map(.[0])
    ' "$CUMULATIVE" "$DAILY_FILE" > "${CUMULATIVE}.tmp"
    mv "${CUMULATIVE}.tmp" "$CUMULATIVE"
    TOTAL=$(jq 'length' "$CUMULATIVE")
    echo "[$(date)] Cumulative total: $TOTAL messages"
else
    cp "$DAILY_FILE" "$CUMULATIVE"
    echo "[$(date)] Created cumulative file with $COUNT messages"
fi

echo "[$(date)] SMS export complete → $DAILY_FILE"
