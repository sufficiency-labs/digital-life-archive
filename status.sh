#!/usr/bin/env bash
# Quick health check for archive sync status.
# Run anytime: ./status.sh
# Used by cron health check to detect failures and send email alerts.

ARCHIVE_DIR="${ARCHIVE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
STATUS_FILE="${ARCHIVE_DIR}/sync-status.json"
WARN_HOURS=48  # alert if last sync > this many hours ago

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Archive Sync Status ==="
echo ""

# --- Check sync-status.json ---
if [ -f "$STATUS_FILE" ]; then
  last_run=$(python3 -c "import json; print(json.load(open('${STATUS_FILE}'))['last_run'])" 2>/dev/null)
  if [ -n "$last_run" ]; then
    last_epoch=$(date -d "$last_run" +%s 2>/dev/null || echo 0)
    now_epoch=$(date +%s)
    hours_ago=$(( (now_epoch - last_epoch) / 3600 ))

    if [ "$hours_ago" -gt "$WARN_HOURS" ]; then
      echo -e "Last sync: ${RED}${last_run} (${hours_ago}h ago — STALE)${NC}"
      echo "ERROR: Sync is stale"
    else
      echo -e "Last sync: ${GREEN}${last_run} (${hours_ago}h ago)${NC}"
    fi
    echo ""

    # Per-source status
    for source in google-drive dropbox gmail; do
      status=$(python3 -c "import json; d=json.load(open('${STATUS_FILE}')); print(d['sources']['${source}']['status'])" 2>/dev/null)
      message=$(python3 -c "import json; d=json.load(open('${STATUS_FILE}')); print(d['sources']['${source}']['message'])" 2>/dev/null)

      case "$status" in
        ok)      echo -e "  ${GREEN}[OK]${NC}      ${source}: ${message}" ;;
        error)   echo -e "  ${RED}[ERROR]${NC}   ${source}: ${message}"
                 echo "ERROR: ${source} failed" ;;
        skipped) echo -e "  ${YELLOW}[SKIP]${NC}    ${source}: ${message}" ;;
        *)       echo -e "  ${YELLOW}[???]${NC}     ${source}: unknown" ;;
      esac
    done
  fi
else
  echo -e "${YELLOW}No sync-status.json found. Run sync-all.sh first.${NC}"
fi

echo ""

# --- Disk usage ---
echo "=== Disk Usage ==="
df -h / 2>/dev/null | awk 'NR==1 || /\/$/'
# Also check mounted volumes (adjust path for your setup)
df -h 2>/dev/null | awk '/archive|data/ {print}'
echo ""

# --- Data sizes ---
echo "=== Data Sizes ==="
for dir in cloud/google-drive cloud/dropbox; do
  if [ -d "${ARCHIVE_DIR}/${dir}" ]; then
    size=$(du -sh "${ARCHIVE_DIR}/${dir}" 2>/dev/null | cut -f1)
    count=$(find "${ARCHIVE_DIR}/${dir}" -type f 2>/dev/null | wc -l)
    echo "  ${dir}: ${size} (${count} files)"
  fi
done
MAIL_DIR="${HOME}/Mail/gmail"
if [ -d "${MAIL_DIR}" ]; then
  size=$(du -sh "${MAIL_DIR}" 2>/dev/null | cut -f1)
  count=$(find "${MAIL_DIR}" -type f 2>/dev/null | wc -l)
  echo "  gmail: ${size} (${count} messages)"
fi
echo ""

# --- Active sync processes ---
rclone_procs=$(pgrep -c rclone 2>/dev/null) || rclone_procs=0
mbsync_procs=$(pgrep -c mbsync 2>/dev/null) || mbsync_procs=0
if [ "$rclone_procs" -gt 0 ] || [ "$mbsync_procs" -gt 0 ]; then
  echo "=== Active Syncs ==="
  [ "$rclone_procs" -gt 0 ] && echo -e "  ${GREEN}rclone: ${rclone_procs} process(es) running${NC}"
  [ "$mbsync_procs" -gt 0 ] && echo -e "  ${GREEN}mbsync: ${mbsync_procs} process(es) running${NC}"
  echo ""
fi

# --- rclone token health ---
echo "=== Token Health ==="
for remote in gdrive dropbox; do
  if rclone listremotes 2>/dev/null | grep -q "^${remote}:$"; then
    if rclone about "${remote}:" --json 2>/dev/null | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
      echo -e "  ${GREEN}[OK]${NC}    ${remote}: token valid"
    else
      echo -e "  ${RED}[ERROR]${NC} ${remote}: token may be expired — run 'rclone config reconnect ${remote}:'"
      echo "ERROR: ${remote} token expired"
    fi
  else
    echo -e "  ${YELLOW}[SKIP]${NC}  ${remote}: not configured"
  fi
done
echo ""
