#!/usr/bin/env bash
set -o pipefail

# Encrypted backup to Backblaze B2.
# All data is encrypted client-side via rclone crypt before upload.
# Backblaze only ever sees ciphertext.
#
# Prerequisites:
#   - rclone configured with 'b2' and 'b2-crypt' remotes (see README.md Step 10)
#   - Encryption passphrase saved in password manager (unrecoverable without it)
#
# Restore: rclone sync b2-crypt:path/ /local/path/
#
# Cron example (daily at 4am, after sync-all.sh at 3am):
#   0 4 * * * /home/YOU/archive/backup.sh >> /var/log/archive-backup.log 2>&1

export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
ARCHIVE_DIR="${ARCHIVE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
ERRORS=0

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

if ! rclone listremotes 2>/dev/null | grep -q "^b2-crypt:$"; then
  log "ERROR: b2-crypt remote not configured. See README.md Step 10."
  exit 1
fi

log "Starting encrypted backup to B2..."

# Back up cloud data
for dir in cloud/google-drive cloud/dropbox; do
  if [ -d "${ARCHIVE_DIR}/${dir}" ]; then
    log "Backing up ${dir}..."
    rclone sync "${ARCHIVE_DIR}/${dir}/" "b2-crypt:${dir}/" \
      --exclude '.git/**' \
      --log-level NOTICE 2>&1 || { log "  ERROR: ${dir} failed"; ERRORS=$((ERRORS + 1)); }
    log "  ${dir} done"
  fi
done

# Back up email (adjust path to your Mail directory)
MAIL_DIR="${HOME}/Mail/gmail"
if [ -d "${MAIL_DIR}" ]; then
  log "Backing up email..."
  rclone sync "${MAIL_DIR}/" b2-crypt:mail/gmail/ \
    --log-level NOTICE 2>&1 || { log "  ERROR: email failed"; ERRORS=$((ERRORS + 1)); }
  log "  email done"
fi

# Back up conversations
for dir in conversations/openai conversations/claude conversations/slack conversations/discord conversations/linkedin; do
  if [ -d "${ARCHIVE_DIR}/${dir}" ]; then
    log "Backing up ${dir}..."
    rclone sync "${ARCHIVE_DIR}/${dir}/" "b2-crypt:${dir}/" \
      --exclude '.git/**' \
      --log-level NOTICE 2>&1 || { log "  ERROR: ${dir} failed"; ERRORS=$((ERRORS + 1)); }
    log "  ${dir} done"
  fi
done

# Back up config
if [ -d "${ARCHIVE_DIR}/config" ]; then
  log "Backing up config..."
  rclone sync "${ARCHIVE_DIR}/config/" b2-crypt:config/ \
    --exclude '.git/**' \
    --log-level NOTICE 2>&1 || { log "  ERROR: config failed"; ERRORS=$((ERRORS + 1)); }
  log "  config done"
fi

# Back up ALL private repos (auto-discovered)
for dir in "${ARCHIVE_DIR}"/private/*/; do
  [ -d "$dir" ] || continue
  reldir="private/$(basename "$dir")"
  log "Backing up ${reldir}..."
  rclone sync "${dir}" "b2-crypt:${reldir}/" \
    --exclude '.git/**' \
    --log-level NOTICE 2>&1 || { log "  ERROR: ${reldir} failed"; ERRORS=$((ERRORS + 1)); }
  log "  ${reldir} done"
done

# Back up coordination and docs
for dir in coordination docs; do
  if [ -d "${ARCHIVE_DIR}/${dir}" ]; then
    log "Backing up ${dir}..."
    rclone sync "${ARCHIVE_DIR}/${dir}/" "b2-crypt:${dir}/" \
      --exclude '.git/**' \
      --log-level NOTICE 2>&1 || { log "  ERROR: ${dir} failed"; ERRORS=$((ERRORS + 1)); }
    log "  ${dir} done"
  fi
done

if [ "$ERRORS" -gt 0 ]; then
  log "Backup completed with ${ERRORS} errors!"
  exit 1
fi

log "Backup complete."
