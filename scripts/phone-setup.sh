#!/data/data/com.termux/files/usr/bin/bash
# phone-setup.sh — Set up Termux on Android phone as offline archive node
# Run this ONCE after installing Termux from F-Droid.
#
# Prerequisites:
#   1. Termux installed from F-Droid (NOT Play Store — Play Store version is outdated)
#   2. Termux:API installed from F-Droid (same source as Termux)
#   3. Termux:Boot installed from F-Droid (same source as Termux)
#   4. Developer Options → Disable child process restrictions
#   5. Battery optimization disabled for BOTH Termux AND Termux:API
#      - Settings → Apps → Termux → Battery → Unrestricted
#      - Settings → Apps → Termux:API → Battery → Unrestricted
#   6. Samsung phones: Settings → Battery → Background usage limits →
#      Remove Termux and Termux:API from sleeping/deep sleeping apps
#   7. Android 13+: Settings → Apps → Termux:API → ⋮ → "Allow restricted settings"
#   8. Open Termux:API app at least once before running this script
#
# Usage: bash phone-setup.sh

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }

# --- Step 1: Update packages ---
log "Updating Termux packages..."
pkg update -y && pkg upgrade -y

# --- Step 2: Install core tools ---
log "Installing core tools..."
pkg install -y \
    git \
    python \
    openssh \
    rsync \
    cronie \
    termux-api \
    syncthing \
    jq \
    curl \
    wget \
    vim \
    autossh

# --- Step 3: Install Python packages ---
log "Installing Python packages..."
pip install --upgrade pip
pip install fastapi uvicorn python-multipart requests

# --- Step 4: Install ollama (optional) ---
log "Installing ollama..."
if command -v ollama &>/dev/null; then
    warn "ollama already installed, skipping"
else
    pkg install -y ollama 2>/dev/null || {
        warn "ollama not in Termux repos — installing from official script"
        curl -fsSL https://ollama.ai/install.sh | bash || {
            warn "ollama install failed — try manually: https://ollama.com/download"
            warn "Continuing without ollama (local LLM will not be available)"
        }
    }
fi

# --- Step 5: Set up storage access ---
log "Setting up storage access..."
if [ ! -d "$HOME/storage" ]; then
    termux-setup-storage
    log "Grant storage access in the Android dialog, then press Enter..."
    read -r
else
    warn "Storage already set up"
fi

# --- Step 6: Test Termux:API ---
log "Testing Termux:API..."
BATTERY=$(timeout 10 termux-battery-status 2>&1) || true
if echo "$BATTERY" | jq empty 2>/dev/null; then
    log "Termux:API working! Battery: $(echo "$BATTERY" | jq -r '.percentage')%"
else
    err "Termux:API is NOT working (calls hang or fail)"
    err "Common fixes:"
    err "  1. Open the Termux:API Android app at least once"
    err "  2. Settings → Apps → Termux:API → Battery → Unrestricted"
    err "  3. Settings → Apps → Termux → Battery → Unrestricted"
    err "  4. Samsung: Settings → Battery → Background usage limits"
    err "     → Remove Termux and Termux:API from sleeping/deep sleeping apps"
    err "  5. Android 13+: Settings → Apps → Termux:API → ⋮ → Allow restricted settings"
    err ""
    err "Fix the above, then re-run this script or test manually:"
    err "  termux-battery-status"
    err ""
    warn "Continuing setup — data export scripts won't work until API is fixed"
fi

# --- Step 7: Set up SSH ---
log "Setting up SSH..."

if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -C "termux@$(hostname)"
    log "SSH key generated. Add this public key to GitHub and your server:"
    echo ""
    cat "$HOME/.ssh/id_ed25519.pub"
    echo ""
    log "Press Enter when you've added the key..."
    read -r
else
    warn "SSH key already exists"
fi

sshd 2>/dev/null || warn "sshd already running"
log "SSH server running on port 8022"

# --- Step 8: Set up git config ---
log "Configuring git..."
if [ -z "$(git config --global user.name 2>/dev/null)" ]; then
    read -rp "  Git user name: " GIT_NAME
    git config --global user.name "$GIT_NAME"
fi
if [ -z "$(git config --global user.email 2>/dev/null)" ]; then
    read -rp "  Git email: " GIT_EMAIL
    git config --global user.email "$GIT_EMAIL"
fi
git config --global init.defaultBranch main
git config --global pull.rebase true

# --- Step 9: Create archive directory structure ---
ARCHIVE_DIR="$HOME/archive"
log "Creating archive directory structure at $ARCHIVE_DIR..."
mkdir -p "$ARCHIVE_DIR/private"
mkdir -p "$ARCHIVE_DIR/data/sms"
mkdir -p "$ARCHIVE_DIR/data/contacts"
mkdir -p "$ARCHIVE_DIR/data/calls"
mkdir -p "$ARCHIVE_DIR/data/photos"

# --- Step 10: Clone repos ---
log "Cloning knowledge repos..."

read -rp "  GitHub username: " GITHUB_USER
GITHUB="git@github.com:$GITHUB_USER"

clone_if_missing() {
    local repo=$1
    local target=$2
    if [ -d "$target/.git" ]; then
        warn "$target already cloned, pulling latest..."
        git -C "$target" pull --rebase || warn "Pull failed for $target"
    else
        log "Cloning $repo → $target"
        git clone "$GITHUB/$repo.git" "$target" || {
            err "Failed to clone $repo — is your SSH key added to GitHub?"
            return 1
        }
    fi
}

# Knowledge repos (always clone these — they're small)
clone_if_missing "idea-index" "$ARCHIVE_DIR/private/idea-index"
clone_if_missing "relationships" "$ARCHIVE_DIR/private/relationships"
clone_if_missing "organizations" "$ARCHIVE_DIR/private/organizations"
clone_if_missing "digital-life-archive" "$ARCHIVE_DIR/private/digital-life-archive"

# Writing projects (optional)
log "Clone writing projects? These are optional."
read -rp "  List writing project repo names (space-separated, or Enter to skip): " WRITING_PROJECTS
for project in $WRITING_PROJECTS; do
    clone_if_missing "$project" "$ARCHIVE_DIR/private/$project"
done

# --- Step 11: Set up cron ---
log "Setting up cron jobs..."

crond 2>/dev/null || warn "crond already running or not available"

cat << CRON | crontab -
# Digital Life Archive — phone data exports and sync
# Export SMS, contacts, call log daily at 2am
0 2 * * * $ARCHIVE_DIR/scripts/export-sms.sh >> $ARCHIVE_DIR/data/export.log 2>&1
15 2 * * * $ARCHIVE_DIR/scripts/export-contacts.sh >> $ARCHIVE_DIR/data/export.log 2>&1
30 2 * * * $ARCHIVE_DIR/scripts/export-calls.sh >> $ARCHIVE_DIR/data/export.log 2>&1

# Sync to server every 30 minutes
*/30 * * * * $ARCHIVE_DIR/scripts/phone-sync.sh >> $ARCHIVE_DIR/data/sync.log 2>&1
CRON

log "Cron jobs installed"

# --- Step 12: Set up Termux:Boot ---
log "Setting up Termux:Boot auto-start..."
BOOT_DIR="$HOME/.termux/boot"
mkdir -p "$BOOT_DIR"

BOOT_SCRIPT="$ARCHIVE_DIR/scripts/phone-boot.sh"
if [ -f "$BOOT_SCRIPT" ]; then
    cp "$BOOT_SCRIPT" "$BOOT_DIR/start-services.sh"
    chmod +x "$BOOT_DIR/start-services.sh"
    log "Boot script installed"
else
    warn "Boot script not found at $BOOT_SCRIPT — copy it after setting up scripts"
fi

# --- Step 13: Set up Syncthing ---
log "Configuring Syncthing..."
warn "Syncthing needs manual pairing with the server."
warn "1. Run 'syncthing' on this phone"
warn "2. Open http://localhost:8384 in phone browser"
warn "3. Add the server as a remote device (use Tailscale IP)"
warn "4. Share DCIM/Camera folder as send-only"
warn "5. On server: accept and set receive folder"

# --- Step 14: Pull local LLM model (optional) ---
if command -v ollama &>/dev/null; then
    log "Pulling local LLM model (phi3:mini — ~2GB)..."
    ollama serve &>/dev/null &
    sleep 3
    ollama pull phi3:mini || warn "Model pull failed — try again when connected"
else
    warn "ollama not installed — skipping model pull"
fi

# --- Done ---
echo ""
log "========================================="
log "Phone archive node setup complete!"
log "========================================="
echo ""
log "What's running:"
log "  • SSH server on port 8022"
log "  • Cron: SMS/contacts/calls export daily at 2am"
log "  • Cron: repo sync every 30 minutes"
echo ""
log "Next steps:"
log "  1. Fix Termux:API if the test failed (see instructions above)"
log "  2. Add SSH public key to GitHub: https://github.com/settings/keys"
log "  3. Install Tailscale on the phone for mesh VPN access"
log "  4. Start the dashboard tunnel: ~/archive/scripts/phone-tunnel.sh"
log "  5. Set up Syncthing for photo sync (see instructions above)"
log "  6. Test: termux-battery-status (should return JSON)"
log "  7. Test: ~/archive/scripts/export-sms.sh (should export SMS)"
echo ""
log "Server access from server: ssh -p 8022 \$(tailscale ip -4 phone)"
log "Dashboard: https://localhost:8443 (after starting tunnel)"
