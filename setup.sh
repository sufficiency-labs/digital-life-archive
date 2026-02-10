#!/usr/bin/env bash
set -euo pipefail

# Setup script for digital life archive.
# Run once on a fresh Ubuntu 24.04+ server.
#
# After running this script, you still need to:
#   1. Run `rclone config` to set up Google Drive and Dropbox OAuth remotes
#   2. Set up Gmail app password and mbsync config (see README.md)
#   3. Set up Tailscale: sudo tailscale up
#   4. Set up the web dashboard (see README.md Step 9)
#   5. Run initial data pulls with sync-all.sh
#   6. Set up cron for automated syncs and backups

echo "=== Installing system packages ==="
sudo apt-get update
sudo apt-get install -y \
  git \
  git-lfs \
  curl \
  unzip \
  python3 \
  python3-venv \
  python3-pip \
  fuse3 \
  isync \
  neomutt \
  notmuch \
  openssl \
  jq

echo ""
echo "=== Setting up git-lfs ==="
git lfs install

echo ""
echo "=== Installing rclone ==="
if ! command -v rclone &>/dev/null; then
  curl https://rclone.org/install.sh | sudo bash
else
  echo "rclone already installed: $(rclone version 2>&1 | head -1)"
fi

echo ""
echo "=== Installing Tailscale ==="
if ! command -v tailscale &>/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
else
  echo "Tailscale already installed: $(tailscale version 2>&1 | head -1)"
fi

echo ""
echo "=== Installing slackdump ==="
if ! command -v slackdump &>/dev/null; then
  SLACKDUMP_VERSION=$(curl -s https://api.github.com/repos/rusq/slackdump/releases/latest | grep tag_name | cut -d '"' -f 4)
  curl -Lo /tmp/slackdump.tar.gz "https://github.com/rusq/slackdump/releases/download/${SLACKDUMP_VERSION}/slackdump_Linux_x86_64.tar.gz"
  sudo tar xzf /tmp/slackdump.tar.gz -C /usr/local/bin slackdump
  rm /tmp/slackdump.tar.gz
else
  echo "slackdump already installed"
fi

echo ""
echo "=== Installing DiscordChatExporter ==="
if [ ! -f /usr/local/bin/DiscordChatExporter.Cli ]; then
  if ! command -v dotnet &>/dev/null; then
    curl -Lo /tmp/dotnet-install.sh https://dot.net/v1/dotnet-install.sh
    chmod +x /tmp/dotnet-install.sh
    /tmp/dotnet-install.sh --runtime dotnet --channel 8.0
    echo 'export DOTNET_ROOT=$HOME/.dotnet' >> ~/.bashrc
    echo 'export PATH=$PATH:$DOTNET_ROOT' >> ~/.bashrc
    export DOTNET_ROOT=$HOME/.dotnet
    export PATH=$PATH:$DOTNET_ROOT
  fi

  DCE_VERSION=$(curl -s https://api.github.com/repos/Tyrrrz/DiscordChatExporter/releases/latest | grep tag_name | cut -d '"' -f 4)
  curl -Lo /tmp/dce.zip "https://github.com/Tyrrrz/DiscordChatExporter/releases/download/${DCE_VERSION}/DiscordChatExporter.Cli.linux-x64.zip"
  sudo unzip -o /tmp/dce.zip -d /usr/local/lib/DiscordChatExporter
  sudo ln -sf /usr/local/lib/DiscordChatExporter/DiscordChatExporter.Cli /usr/local/bin/DiscordChatExporter.Cli
  sudo chmod +x /usr/local/bin/DiscordChatExporter.Cli
  rm /tmp/dce.zip
else
  echo "DiscordChatExporter already installed"
fi

echo ""
echo "=== Installing GitHub CLI ==="
if ! command -v gh &>/dev/null; then
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y gh
else
  echo "gh already installed"
fi

echo ""
echo "=== Creating directories ==="
ARCHIVE_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p ~/Mail/gmail
mkdir -p "${ARCHIVE_DIR}/app/certs"
mkdir -p "${ARCHIVE_DIR}/app/static"
mkdir -p "${ARCHIVE_DIR}/coordination/queued"
mkdir -p "${ARCHIVE_DIR}/conversations/linkedin"

echo ""
echo "=== Setting up Python virtual environment ==="
if [ ! -d "${ARCHIVE_DIR}/.venv" ]; then
  python3 -m venv "${ARCHIVE_DIR}/.venv"
  "${ARCHIVE_DIR}/.venv/bin/pip" install --upgrade pip
  "${ARCHIVE_DIR}/.venv/bin/pip" install fastapi 'uvicorn[standard]' python-multipart
  echo "Python venv created at ${ARCHIVE_DIR}/.venv/"
else
  echo "Python venv already exists"
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Authenticate Tailscale:"
echo "     sudo tailscale up"
echo "     tailscale ip -4                    # Note your Tailscale IP"
echo ""
echo "  2. Configure rclone remotes:"
echo "     rclone config                      # Set up 'gdrive' and 'dropbox' remotes"
echo "     On a headless server, generate tokens locally: rclone authorize \"dropbox\""
echo ""
echo "  3. Set up Gmail:"
echo "     - Create app password at myaccount.google.com > Security > App passwords"
echo "     - echo \"your-app-password\" > ~/.gmail-app-password && chmod 600 ~/.gmail-app-password"
echo "     - Create ~/.mbsyncrc (see README.md for template)"
echo "     - mkdir -p ~/Mail/gmail && mbsync gmail"
echo "     - notmuch setup && notmuch new"
echo ""
echo "  4. Set up the web dashboard:"
echo "     - Edit app/server.py: set TAILSCALE_IP to your IP"
echo "     - Generate TLS certs: openssl req -x509 -newkey rsa:2048 -keyout app/certs/key.pem -out app/certs/cert.pem -days 365 -nodes"
echo "     - Create auth token: python3 -c \"import secrets; print(secrets.token_urlsafe(32))\" > app/auth_token"
echo "     - Create systemd service (see README.md Step 9)"
echo ""
echo "  5. Create GitHub repos for submodules (see README.md Step 6)"
echo ""
echo "  6. Run initial sync: bash sync-all.sh"
echo ""
echo "  7. Set up cron for daily automated syncs and backups"
echo ""
echo "NOTE: gmvault is broken on Python 3.12+ (Ubuntu 24.04)."
echo "      This script installs mbsync (isync) instead."
