#!/usr/bin/env bash
set -o pipefail
# Note: not using -e so we can capture failures per-source

# Automated sync script for digital life archive.
# Runs unattended via cron. Syncs cloud data, email, and commits changes.
#
# Writes status to sync-status.json after each run.
# Check health anytime with: ./status.sh
#
# Cron example (daily at 3am):
#   0 3 * * * /home/YOU/archive/sync-all.sh >> /var/log/archive-sync.log 2>&1

export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
ARCHIVE_DIR="${ARCHIVE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
STATUS_FILE="${ARCHIVE_DIR}/sync-status.json"
TIMESTAMP=$(date +%Y-%m-%d)
ISO_NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# Initialize status as an associative array of JSON fragments
declare -A SOURCE_STATUS

record_status() {
  local source="$1" status="$2" message="$3"
  SOURCE_STATUS[$source]="{\"status\":\"${status}\",\"message\":\"${message}\",\"timestamp\":\"${ISO_NOW}\"}"
}

# --- Google Drive ---
if rclone listremotes 2>/dev/null | grep -q "^gdrive:$"; then
  log "Syncing Google Drive..."
  if rclone sync gdrive: "${ARCHIVE_DIR}/cloud/google-drive/" \
    --exclude '.git/**' --exclude '.gitattributes' --log-level NOTICE 2>&1; then
    record_status "google-drive" "ok" "Sync completed"
    log "  Google Drive sync OK"
  else
    record_status "google-drive" "error" "rclone sync failed (exit $?)"
    log "  ERROR: Google Drive sync failed"
  fi
else
  record_status "google-drive" "skipped" "No gdrive remote configured"
  log "Skipping Google Drive (no remote)"
fi

# --- Dropbox ---
if rclone listremotes 2>/dev/null | grep -q "^dropbox:$"; then
  log "Syncing Dropbox..."
  if rclone sync dropbox: "${ARCHIVE_DIR}/cloud/dropbox/" \
    --exclude '.git/**' --exclude '.gitattributes' --log-level NOTICE 2>&1; then
    record_status "dropbox" "ok" "Sync completed"
    log "  Dropbox sync OK"
  else
    record_status "dropbox" "error" "rclone sync failed (exit $?)"
    log "  ERROR: Dropbox sync failed"
  fi
else
  record_status "dropbox" "skipped" "No dropbox remote configured"
  log "Skipping Dropbox (no remote)"
fi

# --- Gmail via mbsync ---
if [ -f ~/.mbsyncrc ]; then
  log "Syncing Gmail via mbsync..."
  if mbsync gmail 2>&1; then
    record_status "gmail" "ok" "Sync completed"
    log "  Gmail sync OK"
    if command -v notmuch &>/dev/null; then
      log "  Indexing new mail with notmuch..."
      notmuch new 2>&1 | tail -3
    fi
  else
    record_status "gmail" "error" "mbsync failed (likely rate-limited)"
    log "  ERROR: Gmail sync failed (likely rate-limited, will retry next run)"
  fi
else
  record_status "gmail" "skipped" "No ~/.mbsyncrc configured"
  log "Skipping Gmail (no config)"
fi

# --- Git commit + push any changes ---
for repo in cloud/google-drive cloud/dropbox; do
  if [ -d "${ARCHIVE_DIR}/${repo}/.git" ]; then
    log "Committing changes in ${repo}..."
    cd "${ARCHIVE_DIR}/${repo}"
    git checkout main 2>/dev/null || true
    git add -A
    if ! git diff --cached --quiet; then
      git commit -m "Sync ${TIMESTAMP}"
      if git push 2>&1; then
        log "  Pushed new changes for ${repo}"
      else
        log "  ERROR: Push failed for ${repo}"
      fi
    else
      log "  No changes in ${repo}"
    fi
  fi
done

# --- Update parent repo submodule pointers ---
log "Updating parent repo submodule pointers..."
cd "${ARCHIVE_DIR}"
git add cloud/google-drive cloud/dropbox 2>/dev/null || true
if ! git diff --cached --quiet; then
  git commit -m "Update cloud submodule pointers ${TIMESTAMP}"
  git push 2>&1 || log "  ERROR: Parent repo push failed"
  log "Pushed updated submodule pointers"
else
  log "No submodule pointer changes"
fi

# --- Write status file ---
log "Writing sync status..."
{
  echo "{"
  echo "  \"last_run\": \"${ISO_NOW}\","
  echo "  \"sources\": {"
  first=true
  for source in google-drive dropbox gmail; do
    if [ "$first" = true ]; then first=false; else echo ","; fi
    echo -n "    \"${source}\": ${SOURCE_STATUS[$source]:-"{\"status\":\"unknown\",\"message\":\"not attempted\",\"timestamp\":\"${ISO_NOW}\"}"}"
  done
  echo ""
  echo "  }"
  echo "}"
} > "${STATUS_FILE}"

log "Sync complete. Status written to ${STATUS_FILE}"
