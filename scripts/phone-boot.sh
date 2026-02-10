#!/data/data/com.termux/files/usr/bin/bash
# phone-boot.sh — Termux:Boot auto-start script
# Place in ~/.termux/boot/start-services.sh (or symlink)
#
# Starts on phone reboot:
#   1. SSH server (port 8022) — server can reach phone
#   2. crond — scheduled data exports
#   3. Syncthing — photo/file sync
#   4. autossh tunnel — persistent dashboard access
#
# Install:
#   mkdir -p ~/.termux/boot
#   cp phone-boot.sh ~/.termux/boot/start-services.sh
#   chmod +x ~/.termux/boot/start-services.sh

# Acquire wake lock to prevent Android from killing Termux
termux-wake-lock

# Start SSH server
sshd 2>/dev/null || true

# Start cron daemon
crond 2>/dev/null || true

# Start Syncthing (photo sync) — runs its own web UI on localhost:8384
if command -v syncthing &>/dev/null; then
    syncthing serve --no-browser --no-default-folder &>/dev/null &
fi

# Start ollama server for local LLM (if installed)
if command -v ollama &>/dev/null; then
    ollama serve &>/dev/null &
fi

# Start persistent SSH tunnel to server dashboard
TUNNEL_SCRIPT="$HOME/archive/scripts/phone-tunnel.sh"
if [ -f "$TUNNEL_SCRIPT" ]; then
    bash "$TUNNEL_SCRIPT" &
fi
