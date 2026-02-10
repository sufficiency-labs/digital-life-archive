#!/data/data/com.termux/files/usr/bin/bash
# phone-tunnel.sh — Persistent SSH tunnel to server dashboard
# Uses autossh for automatic reconnection on failure.
#
# What it forwards:
#   Server dashboard (8443) → localhost:8443 on phone
#   Server ollama (11434) → localhost:11434 on phone
#
# With this running, open https://localhost:8443 on the phone browser
# to access the full archive dashboard.
#
# Usage:
#   phone-tunnel.sh        # Run in foreground
#   phone-tunnel.sh &      # Run in background
#   phone-tunnel.sh stop   # Kill existing tunnel

set -euo pipefail

# CONFIGURE THESE:
SERVER="YOUR_SERVER_TAILSCALE_IP"   # e.g., 100.x.y.z
SERVER_USER="YOUR_USERNAME"         # e.g., user
SSH_PORT=22

# Port forwards: -L local:remote_host:remote_port
DASHBOARD_LOCAL=8443
DASHBOARD_REMOTE=8443
OLLAMA_LOCAL=11434
OLLAMA_REMOTE=11434

# autossh monitoring port (0 = disable monitoring, use ServerAlive instead)
export AUTOSSH_PORT=0

# Kill existing tunnel
if [ "${1:-}" = "stop" ]; then
    pkill -f "autossh.*${SERVER}.*${DASHBOARD_LOCAL}" 2>/dev/null && \
        echo "Tunnel stopped" || echo "No tunnel running"
    exit 0
fi

# Check if already running
if pgrep -f "autossh.*${SERVER}.*${DASHBOARD_LOCAL}" &>/dev/null; then
    echo "Tunnel already running (PID: $(pgrep -f "autossh.*${SERVER}.*${DASHBOARD_LOCAL}"))"
    exit 0
fi

echo "Starting persistent tunnel to $SERVER..."
echo "  Dashboard: https://localhost:$DASHBOARD_LOCAL"
echo "  Ollama:    http://localhost:$OLLAMA_LOCAL (when server LLM is running)"

autossh -M 0 \
    -N -T \
    -L "${DASHBOARD_LOCAL}:localhost:${DASHBOARD_REMOTE}" \
    -L "${OLLAMA_LOCAL}:localhost:${OLLAMA_REMOTE}" \
    -o "ServerAliveInterval=30" \
    -o "ServerAliveCountMax=3" \
    -o "ExitOnForwardFailure=yes" \
    -o "StrictHostKeyChecking=accept-new" \
    -p "$SSH_PORT" \
    "${SERVER_USER}@${SERVER}"
