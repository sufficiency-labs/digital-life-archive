#!/usr/bin/env bash
set -euo pipefail

# Automated sync script for digital life archive.
# Runs unattended via cron.
#
# Automated sources: Google Drive, Dropbox, Gmail
# Manual sources (no API — re-export periodically by hand):
#   - OpenAI: ChatGPT Settings > Data Controls > Export
#   - Claude: Claude Settings > Privacy > Export Data
#   - Discord: Re-run DiscordChatExporter with --after flag
#
# Cron example (daily at 3am):
#   0 3 * * * /path/to/digital-life-archive/sync.sh >> /var/log/archive-sync.log 2>&1

ARCHIVE_DIR="${ARCHIVE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
TIMESTAMP=$(date +%Y-%m-%d)

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# --- Google Drive ---
if rclone listremotes | grep -q "^gdrive:$"; then
  log "Syncing Google Drive..."
  rclone sync gdrive: "${ARCHIVE_DIR}/cloud/google-drive/" \
    --exclude '.git/**' \
    --exclude '.gitattributes' \
    --log-level NOTICE
else
  log "Skipping Google Drive (no 'gdrive' remote configured)"
fi

# --- Dropbox ---
if rclone listremotes | grep -q "^dropbox:$"; then
  log "Syncing Dropbox..."
  rclone sync dropbox: "${ARCHIVE_DIR}/cloud/dropbox/" \
    --exclude '.git/**' \
    --exclude '.gitattributes' \
    --log-level NOTICE
else
  log "Skipping Dropbox (no 'dropbox' remote configured)"
fi

# --- Gmail via mbsync ---
if [ -f ~/.mbsyncrc ]; then
  log "Syncing Gmail via mbsync..."
  mbsync gmail || log "WARNING: mbsync failed (possibly rate-limited, will retry next run)"
  if command -v notmuch &>/dev/null; then
    log "Indexing new mail with notmuch..."
    notmuch new
  fi
else
  log "Skipping Gmail (no ~/.mbsyncrc configured)"
fi

# --- Git commit + push any changes ---
for repo in cloud/google-drive cloud/dropbox; do
  if [ -d "${ARCHIVE_DIR}/${repo}/.git" ]; then
    log "Committing changes in ${repo}..."
    cd "${ARCHIVE_DIR}/${repo}"

    # Make sure we're on main, not detached HEAD
    git checkout main 2>/dev/null || true

    git add -A
    if ! git diff --cached --quiet; then
      git commit -m "Sync ${TIMESTAMP}"
      git push
      log "  Pushed new changes for ${repo}"
    else
      log "  No changes in ${repo}"
    fi
  fi
done

# --- Update parent repo submodule pointers (if this is a submodule) ---
if [ -f "${ARCHIVE_DIR}/../.gitmodules" ]; then
  log "Updating parent repo submodule pointers..."
  cd "${ARCHIVE_DIR}/.."
  git add cloud/google-drive cloud/dropbox 2>/dev/null || true
  if ! git diff --cached --quiet; then
    git commit -m "Update cloud submodule pointers ${TIMESTAMP}"
    git push
    log "Pushed updated submodule pointers"
  else
    log "No submodule pointer changes"
  fi
fi

log "Sync complete."
