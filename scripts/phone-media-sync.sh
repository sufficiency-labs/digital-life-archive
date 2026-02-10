#!/data/data/com.termux/files/usr/bin/bash
# phone-media-sync.sh — Rsync phone media (photos, videos, etc.) to server
# Run manually or via cron (every 30 min recommended)
#
# What it does:
#   Rsyncs phone media directories to the server staging directory over
#   Tailscale SSH. Uses rsync --partial so interrupted transfers resume
#   where they left off. If the server is unreachable (offline), it
#   silently skips and tries again on the next cron run.
#
# Setup:
#   1. Run `termux-setup-storage` first (grants Android storage access)
#   2. Set SERVER and DEST below to match your server
#   3. Ensure SSH key auth works: `ssh YOUR_USER@YOUR_SERVER_IP hostname`
#   4. Create the staging dir on server: `mkdir -p ~/archive/private/photos-staging`
#   5. Add to crontab: */30 * * * * ~/archive/scripts/phone-media-sync.sh
#
# Customize:
#   Add or remove sync_dir lines below for the directories you want to sync.
#   Each sync_dir call takes: source_path, destination_subdirectory, label.
#
# Usage: phone-media-sync.sh

set -o pipefail

# === CONFIGURE THESE ===
STORAGE="/storage/emulated/0"
SERVER="YOUR_USER@YOUR_SERVER_TAILSCALE_IP"   # e.g., user@100.x.y.z
DEST="$HOME/archive/private/photos-staging"    # server-side path (adjust to your setup)
# === END CONFIG ===

ARCHIVE_DIR="$HOME/archive"
LOG_FILE="$ARCHIVE_DIR/data/media-sync.log"
RSYNC_OPTS="-az --partial --timeout=300 --info=progress2"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }

# Check connectivity (extract just the hostname/IP from SERVER)
SERVER_HOST="${SERVER#*@}"
if ! ping -c 1 -W 3 "$SERVER_HOST" &>/dev/null; then
    log "OFFLINE — server unreachable, skipping media sync"
    exit 0
fi

log "=== Media sync started ==="

sync_dir() {
    local src="$1"
    local dest_subdir="$2"
    local label="$3"
    if [ -d "$src" ]; then
        log "Syncing $label ($src → $dest_subdir)..."
        rsync $RSYNC_OPTS "$src/" "${SERVER}:${DEST}/${dest_subdir}/" >> "$LOG_FILE" 2>&1
        if [ $? -eq 0 ]; then
            log "  $label: done"
        else
            log "  $label: rsync exited with code $?"
        fi
    else
        log "  $label: directory not found, skipping"
    fi
}

# --- Add or remove directories here ---
sync_dir "$STORAGE/DCIM"             "DCIM"             "Camera + Screenshots"
sync_dir "$STORAGE/Pictures"         "Pictures"         "Pictures"
sync_dir "$STORAGE/Movies"           "Movies"           "Movies"
sync_dir "$STORAGE/Recordings"       "Recordings"       "Voice recordings"
sync_dir "$STORAGE/VisualVoiceMail"  "VisualVoiceMail"  "Voicemail"
sync_dir "$STORAGE/signal_backups"   "signal_backups"   "Signal backups"
sync_dir "$STORAGE/Download"         "Download"         "Downloads"
sync_dir "$STORAGE/Documents"        "Documents"        "Documents"

# Sync loose files in storage root (PDFs, docs, etc.)
log "Syncing loose files from storage root..."
rsync $RSYNC_OPTS --include='*.pdf' --include='*.PDF' --include='*.doc' --include='*.docx' \
    --exclude='*/' --exclude='*' \
    "$STORAGE/" "${SERVER}:${DEST}/root-files/" >> "$LOG_FILE" 2>&1

log "=== Media sync complete ==="
