#!/data/data/com.termux/files/usr/bin/bash
# phone-sync.sh — Sync repos between phone and server
# Run manually or via cron (every 30 min recommended)
#
# What it does:
#   1. Pull latest from knowledge repos (ideas, people, orgs) — server is source of truth
#   2. Push any local data captures (SMS, contacts, calls) to server
#   3. Push any local writing changes
#
# Prerequisites:
#   - SSH access to server (key-based, over Tailscale)
#   - rsync installed on both phone and server
#
# Usage: phone-sync.sh

set -euo pipefail

ARCHIVE_DIR="$HOME/archive"
LOG_FILE="$ARCHIVE_DIR/data/sync.log"

# CONFIGURE THESE:
SERVER="YOUR_SERVER_TAILSCALE_IP"   # e.g., 100.x.y.z
SERVER_USER="YOUR_USERNAME"         # e.g., user
SERVER_ARCHIVE="/home/$SERVER_USER/archive"  # server archive path

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

# Check connectivity (try to reach server over Tailscale)
if ! ping -c 1 -W 3 "$SERVER" &>/dev/null; then
    log "OFFLINE — server unreachable, skipping sync"
    exit 0
fi

log "=== Sync started ==="

# --- Pull knowledge repos (server → phone) ---
pull_repo() {
    local dir=$1
    local name=$2
    if [ -d "$dir/.git" ]; then
        log "Pulling $name..."
        git -C "$dir" pull --rebase --quiet 2>&1 | while read -r line; do
            log "  $name: $line"
        done || log "  WARNING: pull failed for $name"
    fi
}

pull_repo "$ARCHIVE_DIR/private/idea-index" "idea-index"
pull_repo "$ARCHIVE_DIR/private/relationships" "relationships"
pull_repo "$ARCHIVE_DIR/private/organizations" "organizations"
pull_repo "$ARCHIVE_DIR/private/digital-life-archive" "digital-life-archive"

# Pull any writing projects that are cloned (add your project names here)
# for project in project-a project-b; do
#     pull_repo "$ARCHIVE_DIR/private/$project" "$project"
# done

# --- Push local data to server ---
push_data() {
    local dir=$1
    local name=$2
    if [ -d "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
        log "Syncing $name to server..."
        rsync -avz --quiet "$dir/" "${SERVER_USER}@${SERVER}:${SERVER_ARCHIVE}/private/${name}/" 2>&1 | \
            while read -r line; do
                log "  $name: $line"
            done || log "  WARNING: rsync failed for $name"
    fi
}

push_data "$ARCHIVE_DIR/data/sms" "sms"
push_data "$ARCHIVE_DIR/data/contacts" "phone-contacts"
push_data "$ARCHIVE_DIR/data/calls" "call-log"

# --- Push any local git changes (writing projects) ---
push_changes() {
    local dir=$1
    local name=$2
    if [ -d "$dir/.git" ]; then
        if git -C "$dir" status --porcelain | grep -q .; then
            log "Pushing local changes in $name..."
            git -C "$dir" add -A
            git -C "$dir" commit -m "Phone sync: $(date '+%Y-%m-%d %H:%M')" --quiet 2>/dev/null || true
            git -C "$dir" push --quiet 2>&1 | while read -r line; do
                log "  $name: $line"
            done || log "  WARNING: push failed for $name"
        fi
    fi
}

# Only push writing projects (knowledge repos are server-managed)
# for project in project-a project-b; do
#     push_changes "$ARCHIVE_DIR/private/$project" "$project"
# done

log "=== Sync complete ==="
