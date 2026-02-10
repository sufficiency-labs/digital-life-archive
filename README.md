# Digital Life Archive

## What is this?

Right now, your digital life probably works like this: your emails are in Gmail, your files are in Google Drive or Dropbox, your conversations are in Slack and Discord and ChatGPT, your code is on GitHub, your photos are on your phone. That all works fine. You don't need to change it.

We made a copy of all of it — every email, every file, every conversation — into a single directory of plain files on a machine we control. That directory works on a laptop, a USB drive, a home server, or a cloud server. It works offline. It works without internet. Everything is just files.

We still use Gmail. We still use Discord. We still use Signal. We didn't leave any platform or ask anyone to follow us anywhere. We just also have our own copy of everything, organized the way we want, searchable with tools we choose, backed up with encryption we hold the keys to.

When there's internet — when it's convenient — the system syncs new data in and pushes backups out. When there's no internet, everything still works. The internet is a convenience you opt into, not a requirement.

**Nobody needs to do anything differently.** You meet people wherever they already are. You just also own your side of the conversation. If you want to do the same thing, this repo is how we did it. Fork it.

The more people who own their own data, the less power any single platform has over any of us. But that's a side effect, not a pitch. This is just a filing cabinet.

### The minimum version

A laptop and a local AI model. That's it. Clone this repo, start putting your files in it, talk to a local model about it. The CLAUDE.md file tells any AI assistant what everything is and how it's organized. No server, no internet, no accounts required.

### The full version

A small server ($25-50/month), automated daily syncs of your cloud accounts, encrypted backups ($1/month), a private dashboard on your phone accessible only over VPN, email search across your entire history, and a communication triage system. You opt into each piece when it's useful to you.

### Progressive enhancement

You can start with nothing and add layers when convenient:

1. **Just files.** Clone the repo. Put your stuff in it. Done. You own your data.
2. **Add Git.** Now you have version history and can't accidentally lose anything.
3. **Add a server.** Now your archive is accessible from anywhere, and syncs can run while you sleep.
4. **Add cloud sync.** Gmail, Google Drive, Dropbox — rclone pulls copies into your archive on a schedule.
5. **Add encrypted backup.** Backblaze B2 with client-side encryption. The provider can't read your data.
6. **Add the dashboard.** A private web app, accessible only over Tailscale VPN, for searching and managing everything from your phone.
7. **Add an AI assistant.** Point a coding assistant at the repo and let it operate the system for you — see below.

Every layer is optional. Every layer works independently. You can stop at step 1 and have something useful.

### The AI situation

For this to work well — for the archive to be something you *use*, not just something you *have* — you want an AI coding assistant that can read your CLAUDE.md and operate the system. We use [Claude Code](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview), but the architecture is model-agnostic — any coding assistant that reads a context file and can run terminal commands will work.

The AI assistant reads CLAUDE.md, understands the archive structure, and can search emails, manage repos, write scripts, fix bugs, and generally act as a sysadmin that knows your context. It runs in the terminal, works over SSH, works on a phone in Termux.

**Local/offline LLMs:** You can run open-source models locally (ollama + llama3.2 on a phone, or 7B-70B models on a server with a GPU). The scripts in this repo support it. Smaller models are useful for quick searches and basic Q&A when offline. Larger models (70B+) are genuinely capable. Local models are improving fast — the architecture supports whatever arrives.

### Trust and safety

When you install an app or sign up for a service, you're trusting a black box. You can't read the code. You can't see what it does with your data. You just hope.

This system is text files in git repos. You can read every byte. `git diff` shows you exactly what changed, when, and by whom. There's nothing to trust because there's nothing hidden. A markdown file can't spy on you.

When someone shares a repo with you — a project, a collaboration, a creative work — you can read every file before you accept it. It's text. It's introspectable. The worst case is you read something you don't like and delete it.

Binary files (images, compressed archives) are the exception — those you can't read by inspection. But you choose which repos contain binaries, and you choose which machines those repos sync to. Which brings us to:

### Selective sync

You don't have to put everything everywhere. Each subrepo is independent. You choose, per-repo and per-machine, what lives where:

- Your laptop has everything.
- Your server has most things, but not the repo with your most private writing.
- A shared repo for a collaboration syncs to both your machine and your collaborator's, but nothing else crosses over.
- A work machine has work repos only. Personal stuff never touches it.

Some repos only exist on one machine and never sync anywhere. Some sync to a server but not to a backup. You decide. The architecture doesn't force anything — git submodules are independently cloneable by design.

This means you can incorporate repos from other people without risk to the rest of your archive. A new repo is just a new directory. It can't see your other directories. You read it, you decide if you want it, you keep it or you don't.

### What it costs

- **Minimum (laptop only):** $0. Just files on your machine.
- **With a server:** $25-50/month for the server, ~$1/month for backup storage. That's it. No subscriptions, no premium tiers, no per-seat pricing.

### What this is not

- It's not a replacement for Gmail or Dropbox or Discord. You keep using those. This just gives you your own copy.
- It's not a social network. There are no user accounts, no profiles, no feeds. It's a filing cabinet.
- It's not a product. Nobody is selling you anything. There are no premium tiers.
- It's not a movement. You don't have to convince anyone of anything. You just set up your own place.
- It doesn't make decisions for you. It doesn't send messages, prioritize contacts, or nudge you. You look when you want to look.

---

## Technical Overview

A directory of plain files — organized, versioned in Git, searchable offline — that contains your entire digital life. Optionally enhanced with automated cloud syncs, encrypted backups, a private web dashboard, and structured knowledge extraction. Works on a laptop with no internet. Scales to a full server when you want it to.

### Core principle

Everything is files. Maildir for email. Markdown for notes and knowledge. Git for version history. Standard Unix tools for search. No databases, no proprietary formats, no services that need to be running. If you can `ls` and `grep`, you can use your archive.

The internet is a sync layer, not a dependency. When you connect, new data flows in and backups flow out. When you disconnect, everything still works.

## What You Get

- **Automated daily sync** of Gmail, Google Drive, and Dropbox via cron
- **Frequent email checking** every 15 minutes with VIP notifications via Signal
- **Full-text email search** across your entire inbox history (notmuch)
- **Encrypted off-site backup** to Backblaze B2 (zero-knowledge, ~$1/month) with error tracking and auto-discovery of all private repos
- **Private web dashboard** accessible only via Tailscale VPN — invisible to the public internet
  - **Next Actions Queue** — ordered task list, reorderable with drag-and-drop, git-committed, links to "place to do work" (comm triage, files, email)
  - **Living Communication Triage** — AI-summarized email threads grouped by person, with draft reply generation (Claude API)
  - **Recent Email** — filtered view of recent human-sent emails (strips out automated/spam)
  - **Notifications** — browser Notification API polling for new next-actions items
  - **Signal integration** — Messages merged into comm triage, phone number matching to relationships
  - **File browser** with inline markdown rendering and edit-and-commit
  - **Email compose and reply** from the dashboard
  - **People search** across relationships repo with INDEX.md viewer
  - **Ideas browser** across idea-index repo with INDEX.md viewer
  - **System status** — backup/sync log monitoring, B2 backup size, disk usage, active sessions
  - **Automated testing** — Playwright UI tests for catching console bugs
- **Privacy cleanup** guide for reducing your public footprint after archiving
- **Health monitoring** with alerts when syncs fail
- **AI assistant integration** for running coding assistant tasks from the dashboard
- **Queued tasks system** — self-contained task briefings for future work sessions

## What Gets Archived

| Source | Method | Automated? |
|--------|--------|------------|
| Google Drive | rclone sync | Yes (cron) |
| Dropbox | rclone sync | Yes (cron) |
| Gmail | mbsync (IMAP) + notmuch indexing | Yes (cron) |
| Slack | slackdump | Semi (re-run manually) |
| Discord | DiscordChatExporter | Semi (re-run manually) |
| ChatGPT | Manual export + parser | No (no API) |
| Claude | Manual export | No (no API) |
| Phone photos/video | rsync via Tailscale SSH (cron, every 30 min) | Yes |
| Google Photos | Google Takeout | No (API can't download existing) |
| Google Calendar | Google Calendar API (OAuth2) or Takeout | Yes (cron) |
| Google Contacts | Takeout / People API | Semi |
| Signal backups | Rsync from phone (encrypted .backup files, every 30 min) | Yes (cron) |
| Signal messages | signal-export (Python, reads desktop DB) | Semi (re-run manually) |
| SMS/MMS/RCS | Termux:API → markdown + git push | Yes (cron, every minute) |
| Phone contacts | Termux:API → JSON + git push | Yes (cron, every minute) |
| Call log | Termux:API → JSON + git push | Yes (cron, every minute) |
| WhatsApp | Per-chat export or GDrive backup | No |
| LinkedIn | Settings > Get a copy of your data | No |
| Browser history | Copy SQLite from Chrome/Firefox | Semi |
| Code repos | git submodules | Yes (already in Git) |

## Architecture

```
your-archive/
├── cloud/
│   ├── google-drive/          # Full GDrive mirror (rclone, each a git submodule)
│   ├── dropbox/               # Full Dropbox mirror (rclone, git submodule)
│   └── gmail/                 # Gmail via mbsync (Maildir format)
├── conversations/
│   ├── openai/                # ChatGPT export (manual + parsed to markdown)
│   ├── claude/                # Claude export (manual)
│   ├── slack/                 # Slack export (slackdump)
│   ├── discord/               # Discord export (DiscordChatExporter)
│   └── linkedin/              # LinkedIn data export
├── private/
│   └── idea-index/            # Your projects, ideas, frameworks (see Knowledge Extraction)
├── config/
│   └── dotfiles/              # Shell config, editor config, etc.
├── app/                       # Private web dashboard (FastAPI + Tailscale)
│   ├── server.py              # API server
│   ├── static/                # Frontend SPA
│   ├── certs/                 # Self-signed TLS certificates
│   └── auth_token             # Bearer token (gitignored)
├── coordination/              # Multi-session task management
│   └── queued/                # Task starter packs for AI assistants
├── docs/
│   ├── security-hardening.md
│   ├── knowledge-extraction.md
│   ├── privacy-cleanup.md
│   └── capture-everything.md
├── scripts/
│   ├── check-mail.py          # Frequent email check + VIP notifications
│   ├── triage-email.py        # Communication triage generator
│   └── phone-media-sync.sh    # Rsync phone media to server (cron, every 30 min)
├── setup.sh                   # One-time server setup
├── sync-all.sh                # Daily automated sync (cron)
├── backup.sh                  # Encrypted backup to B2 (cron)
├── status.sh                  # Health check dashboard
├── import-contacts.py         # Google Contacts + LinkedIn import
├── sync-status.json           # Machine-readable sync status
├── CLAUDE.md                  # AI assistant context
└── HISTORY.md                 # Running narrative of your archive
```

Each cloud/conversation directory is its own Git repo (submodule of the parent). Binary files are tracked with **git-lfs**.

---

## Complete Setup Guide

### Step 0: Prerequisites

- **A Linux server** (Ubuntu 24.04+ recommended)
  - A DigitalOcean droplet works well ($24-48/mo depending on specs)
  - Add a block storage volume if you need >200GB disk
  - A $24/mo droplet (2 vCPU, 4GB RAM) is enough for most archives
  - Upgrade to 4 vCPU / 16GB RAM if you'll run AI assistants or have >100GB of data
- **A GitHub account** with SSH key configured
- **Tailscale account** (free for personal use) for VPN access to your dashboard
- **Accounts/credentials** for the services you want to archive

### Step 1: Provision the Server

```bash
# If using DigitalOcean:
doctl compute droplet create archive-server \
  --region sfo3 \
  --size s-2vcpu-4gb \
  --image ubuntu-24-04-x64 \
  --ssh-keys YOUR_SSH_KEY_FINGERPRINT

# SSH in
ssh root@YOUR_SERVER_IP

# Create your user (if not already done)
adduser yourname
usermod -aG sudo yourname

# Optional: enable passwordless sudo
echo "yourname ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/yourname

# Switch to your user
su - yourname
```

If you have more data than fits on the boot disk, attach a block storage volume:

```bash
# Create and attach a volume (DigitalOcean example)
doctl compute volume create archive-data --region sfo3 --size 500GiB

# Mount it (Ubuntu will auto-mount at /mnt/YOUR_VOLUME_NAME)
# Or manually:
sudo mkfs.ext4 /dev/disk/by-id/YOUR_VOLUME_ID
sudo mkdir -p /mnt/archive-data
sudo mount /dev/disk/by-id/YOUR_VOLUME_ID /mnt/archive-data
# Add to /etc/fstab for persistence

# Symlink your archive directory to the volume
ln -s /mnt/archive-data/archive ~/archive
```

### Step 2: Fork and Clone This Repo

```bash
# Fork on GitHub first, then:
git clone git@github.com:YOUR_USERNAME/digital-life-archive.git ~/archive
cd ~/archive
```

### Step 3: Run the Setup Script

```bash
bash setup.sh
```

This installs all system dependencies: git, git-lfs, rclone, mbsync, notmuch, neomutt, slackdump, DiscordChatExporter, GitHub CLI, Python 3, Tailscale.

### Step 4: Set Up Tailscale

Tailscale creates a private mesh VPN so your dashboard is accessible from your phone/laptop but invisible to the public internet.

```bash
# Install (done by setup.sh, but if needed manually):
curl -fsSL https://tailscale.com/install.sh | sh

# Authenticate
sudo tailscale up

# Note your Tailscale IP
tailscale ip -4
# Example output: 100.x.y.z
```

Install Tailscale on your phone/laptop too. Now you can reach the server at its Tailscale IP from anywhere.

### Step 5: Connect Cloud Accounts

#### rclone (Google Drive + Dropbox)

rclone needs OAuth tokens. On a headless server, generate tokens on a local machine:

```bash
# On your server:
rclone config
# Choose "New remote"
# Name: gdrive (for Google Drive) or dropbox (for Dropbox)
# Type: drive (Google) or dropbox (Dropbox)
# When asked about headless: say yes
# It will give you a URL to run on a machine with a browser

# On your local machine (with a browser):
rclone authorize "drive"    # for Google Drive
rclone authorize "dropbox"  # for Dropbox
# Copy the token blob and paste it on the server
```

**Dropbox warning:** Dropbox aggressively rate-limits API access. Expect `too_many_requests` errors and 300-second waits. Syncs of >50GB may take days. rclone handles retries automatically — just let it run.

**Google Drive:** Generally faster and less rate-limited than Dropbox.

**Google Photos:** The API only allows downloading photos your app uploaded. You **cannot** bulk-download existing photos via API. Use [Google Takeout](https://takeout.google.com) instead.

Verify your remotes work:

```bash
rclone size gdrive:       # Shows total size of your Google Drive
rclone size dropbox:      # Shows total size of your Dropbox
```

#### Gmail (mbsync + notmuch)

1. **Enable 2-Factor Authentication** on your Google account (required for app passwords)

2. **Create a Gmail App Password:**
   - Go to myaccount.google.com > Security > 2-Step Verification > App passwords
   - Generate a password and save it:
   ```bash
   echo "your-app-password" > ~/.gmail-app-password
   chmod 600 ~/.gmail-app-password
   ```

3. **Configure mbsync** (`~/.mbsyncrc`):
   ```
   IMAPAccount gmail
   Host imap.gmail.com
   User your.email@gmail.com
   PassCmd "cat ~/.gmail-app-password"
   SSLType IMAPS
   CertificateFile /etc/ssl/certs/ca-certificates.crt

   IMAPStore gmail-remote
   Account gmail

   MaildirStore gmail-local
   Subfolders Verbatim
   Path ~/Mail/gmail/
   Inbox ~/Mail/gmail/Inbox

   Channel gmail
   Far :gmail-remote:
   Near :gmail-local:
   Patterns *
   Create Both
   Expunge Both
   SyncState *
   ```

4. **Run initial sync:**
   ```bash
   mkdir -p ~/Mail/gmail
   mbsync gmail
   ```
   First run pulls all mail. Large mailboxes (50K+ messages) may take hours. Google may rate-limit — just re-run to continue where it left off.

5. **Set up notmuch** for full-text search:
   ```bash
   notmuch setup   # Follow prompts (point to ~/Mail/gmail)
   notmuch new     # Index all messages
   ```

   Now you can search your entire email history:
   ```bash
   notmuch search "from:someone@example.com"
   notmuch search "subject:important thing"
   notmuch search "date:2024..2025 AND from:boss@company.com"
   notmuch count   # Total indexed messages
   ```

6. **Optional: neomutt** for a full terminal email client that can also send:
   ```bash
   # Already installed by setup.sh
   # Configure SMTP for sending in ~/.neomuttrc:
   set smtp_url = "smtps://your.email@gmail.com@smtp.gmail.com:465/"
   set smtp_pass = "`cat ~/.gmail-app-password`"
   set from = "your.email@gmail.com"
   set realname = "Your Name"
   ```

### Step 6: Create Submodule Repos

Each data source gets its own private GitHub repo, added as a submodule:

```bash
# Create private repos
gh repo create YOUR_USERNAME/archive-gdrive --private
gh repo create YOUR_USERNAME/archive-dropbox --private
gh repo create YOUR_USERNAME/archive-gmail --private
gh repo create YOUR_USERNAME/archive-openai --private
gh repo create YOUR_USERNAME/archive-claude --private
gh repo create YOUR_USERNAME/archive-slack --private
gh repo create YOUR_USERNAME/archive-discord --private

# Add as submodules
git submodule add git@github.com:YOUR_USERNAME/archive-gdrive.git cloud/google-drive
git submodule add git@github.com:YOUR_USERNAME/archive-dropbox.git cloud/dropbox
git submodule add git@github.com:YOUR_USERNAME/archive-gmail.git cloud/gmail
git submodule add git@github.com:YOUR_USERNAME/archive-openai.git conversations/openai
git submodule add git@github.com:YOUR_USERNAME/archive-claude.git conversations/claude
git submodule add git@github.com:YOUR_USERNAME/archive-slack.git conversations/slack
git submodule add git@github.com:YOUR_USERNAME/archive-discord.git conversations/discord

# Add your code repos as submodules too
# git submodule add git@github.com:YOUR_USERNAME/some-project.git private/some-project

git commit -m "Add data submodules"
git push
```

**Important:** Submodules clone in detached HEAD. Always checkout main before pushing:
```bash
cd cloud/google-drive && git checkout main && cd ../..
```

### Step 7: Set Up Git LFS for Binary Files

Cloud data repos contain binary files (images, PDFs, videos). Without LFS, Git will choke:

```bash
cd cloud/google-drive
git lfs install

# Create .gitattributes (a comprehensive one is included in this template)
# It tracks 55+ file types: images, video, audio, documents, archives, databases
git add .gitattributes
git commit -m "Set up LFS tracking"
git push

# Repeat for cloud/dropbox
```

The `.gitattributes` template in this repo tracks:
- Images: jpg, jpeg, png, gif, bmp, tiff, webp, heic, svg, ico, psd, ai
- Video: mp4, mov, avi, mkv, wmv, webm, flv, m4v
- Audio: mp3, wav, flac, aac, ogg, m4a, wma
- Documents: pdf, doc, docx, xls, xlsx, ppt, pptx, odt, ods, odp
- Archives: zip, tar, tar.gz, gz, tgz, bz2, 7z, rar, xz
- Databases: sqlite, db
- Binaries: exe, dmg, iso

### Step 8: Run the First Sync

```bash
bash sync-all.sh
```

This pulls down all your cloud data, commits changes to each submodule, and pushes. Watch the output for errors.

### Step 9: Set Up the Web Dashboard

The dashboard is a FastAPI app that gives you a private web UI accessible only over Tailscale.

1. **Create a Python virtual environment:**
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install fastapi uvicorn[standard] python-multipart
   ```

2. **Generate TLS certificates** (self-signed, for HTTPS):
   ```bash
   mkdir -p app/certs
   openssl req -x509 -newkey rsa:2048 \
     -keyout app/certs/key.pem \
     -out app/certs/cert.pem \
     -days 365 -nodes \
     -subj "/CN=archive-console"
   chmod 600 app/certs/key.pem
   ```

3. **Create an auth token:**
   ```bash
   python3 -c "import secrets; print(secrets.token_urlsafe(32))" > app/auth_token
   chmod 600 app/auth_token
   ```
   Save this token — you'll need it to log into the dashboard.

4. **Configure the server** — Edit `app/server.py` and set your Tailscale IP:
   ```python
   TAILSCALE_IP = "YOUR_TAILSCALE_IP"  # e.g., "100.x.y.z"
   ```

5. **Create a systemd service** for auto-start:
   ```bash
   sudo tee /etc/systemd/system/archive-console.service << 'EOF'
   [Unit]
   Description=Digital Life Archive Console
   After=network.target tailscaled.service
   Wants=tailscaled.service

   [Service]
   Type=simple
   User=YOUR_USERNAME
   WorkingDirectory=/home/YOUR_USERNAME/archive/app
   ExecStart=/home/YOUR_USERNAME/archive/.venv/bin/python server.py
   Restart=always
   RestartSec=5
   Environment=HOME=/home/YOUR_USERNAME

   [Install]
   WantedBy=multi-user.target
   EOF

   sudo systemctl daemon-reload
   sudo systemctl enable archive-console
   sudo systemctl start archive-console
   ```

6. **Access the dashboard:**
   - From your phone/laptop (with Tailscale running): `https://YOUR_TAILSCALE_IP:8443`
   - Accept the self-signed certificate warning
   - Log in with your auth token

**Dashboard features:**
- System status (disk, sync health, active processes)
- Email search and thread reading
- Email compose and reply
- File browser with markdown rendering
- Inline file editing with auto git commit
- Queued task viewer
- AI assistant task launcher (Claude Code integration)
- People/contacts search from your relationships repo
- PWA installable on mobile

### Step 10: Set Up Encrypted Backup

Your 3-2-1 backup strategy: local server + GitHub + Backblaze B2. B2 costs ~$0.005/GB/month (~$1/month for 200GB).

1. **Create a Backblaze B2 account** at backblaze.com
2. **Create a private bucket** (e.g., `your-archive-backup`)
3. **Create an application key** scoped to that bucket
4. **Configure rclone remotes:**
   ```bash
   # Raw B2 remote
   rclone config create b2 b2 account=YOUR_KEY_ID key=YOUR_APP_KEY

   # Encrypted layer on top (zero-knowledge — B2 never sees your plaintext data)
   rclone config create b2-crypt crypt \
     remote=b2:your-bucket-name \
     password=$(rclone obscure YOUR_PASSPHRASE) \
     password2=$(rclone obscure YOUR_SALT)
   ```

5. **Save your encryption passphrase and salt** in a password manager. Without them, the backup is permanently unrecoverable. That's the point — but you must not lose them:
   ```bash
   echo "YOUR_PASSPHRASE" > ~/.b2-crypt-passphrase
   echo "YOUR_SALT" > ~/.b2-crypt-salt
   chmod 600 ~/.b2-crypt-passphrase ~/.b2-crypt-salt
   ```

6. **Run backup:** `bash backup.sh`

7. **Restore** (if ever needed):
   ```bash
   rclone sync b2-crypt:cloud/google-drive/ /local/restore/google-drive/
   ```

### Step 11: Set Up Cron Automation

```bash
crontab -e
```

Add these lines (adjust paths):

```bash
# Cloud data sync (3am daily)
0 3 * * * /home/YOUR_USERNAME/archive/sync-all.sh >> /var/log/archive-sync.log 2>&1

# Encrypted B2 backup (4am daily, after sync completes)
0 4 * * * /home/YOUR_USERNAME/archive/backup.sh >> /var/log/archive-backup.log 2>&1

# Check for new email every 15 minutes (mbsync + notmuch + VIP alerts)
*/15 * * * * /home/YOUR_USERNAME/archive/.venv/bin/python /home/YOUR_USERNAME/archive/scripts/check-mail.py >> /var/log/archive-checkmail.log 2>&1

# Health check + email alert (6am daily)
0 6 * * * /home/YOUR_USERNAME/archive/status.sh 2>&1 | grep -q ERROR && /home/YOUR_USERNAME/archive/status.sh 2>&1 | neomutt -s 'Archive: sync error' your.email@gmail.com
```

Create log files with proper permissions:
```bash
sudo touch /var/log/archive-sync.log /var/log/archive-backup.log /var/log/archive-checkmail.log
sudo chown YOUR_USERNAME:YOUR_USERNAME /var/log/archive-sync.log /var/log/archive-backup.log /var/log/archive-checkmail.log
```

### Step 12: Manual Data Exports

Some services don't have APIs. You'll need to export these by hand:

**ChatGPT:**
1. ChatGPT > Settings > Data Controls > Export
2. Wait for the email, download and unzip into `conversations/openai/`

**Claude:**
1. Claude > Settings > Privacy > Export Data
2. Download and unzip into `conversations/claude/`

**Google Takeout** (for Photos, Calendar, Contacts, Keep, Location History, YouTube):
1. Go to [takeout.google.com](https://takeout.google.com)
2. Select the data types you want
3. Request export (may take hours/days for large accounts)
4. Download and extract to appropriate directories

**LinkedIn:**
1. LinkedIn > Settings > Get a copy of your data
2. Wait for email, download zip
3. Extract to `conversations/linkedin/`

**Signal:**
1. Install `signal-export` (Python): `pip install signal-export`
2. Export: `signal-export ~/archive/conversations/signal/`

**SMS (Android):**
1. Install "SMS Backup & Restore" app on your phone
2. Export to XML, transfer to server
3. Or use `sms-backup-plus` which backs up to a Gmail label

**Browser History:**
```bash
# Chrome (copy from your machine)
scp yourbox:~/.config/google-chrome/Default/History conversations/browser/chrome-history.sqlite

# Firefox
scp yourbox:~/.mozilla/firefox/*.default/places.sqlite conversations/browser/firefox-history.sqlite
```

### Step 13: Knowledge Extraction (Optional)

Once your data is archived, you can start extracting structured knowledge from it. An `idea-index` placeholder is included — point your AI assistant at your archive and ask it to help you populate it.

```bash
# Create a private repo for your ideas and add it as a submodule
gh repo create YOUR_USERNAME/idea-index --private
git submodule add git@github.com:YOUR_USERNAME/idea-index.git private/idea-index

# Then ask your AI assistant to mine your archive:
cd ~/archive && claude
# "Read through my conversations and documents and extract every project,
#  idea, and framework into private/idea-index/"
```

See `docs/knowledge-extraction.md` for more on what you can build from here.

### Step 14: Privacy Cleanup (Optional)

Once your data is archived and verified, you can reduce your public footprint. See `docs/privacy-cleanup.md` for:
- Data broker opt-out URLs (30+ brokers)
- GitHub email privacy settings
- Social media lockdown steps
- Google/Dropbox account deletion procedures (after archiving)
- Ongoing monitoring

---

## AI Assistants

### Coding assistants

An AI coding assistant that reads your CLAUDE.md and can run terminal commands is what turns this from "a pile of files" into something you actually use. We built this with [Claude Code](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview), but the architecture works with any assistant that reads a context file — the CLAUDE.md is the interface contract.

```bash
# Whatever coding assistant you use:
cd ~/archive && claude    # or aider, or goose, etc.
```

### Local LLMs

You can run open-source models locally with ollama:

```bash
curl -fsSL https://ollama.ai/install.sh | sh
ollama pull llama3.2:3b    # 2GB, runs on any server CPU
ollama run llama3.2:3b "summarize this"
```

Smaller models (3B-8B) handle quick search and basic Q&A. Larger models (13B-70B) with a GPU are capable of more substantive work. Local models are improving fast — the architecture supports whatever arrives.

The phone scripts include `phone-llm.sh` which wraps ollama with your archive context for offline use.

---

## Phone as Local Archive Node (Android)

Your phone can be another node on the network — not a "mobile app," just another Linux machine that fits in your pocket. When it has internet, it syncs. When it doesn't, everything still works.

**Requirements:** Android phone with [Termux](https://f-droid.org/en/packages/com.termux/) (F-Droid, NOT Play Store). This does NOT work on iPhone — Apple locks down filesystem access, background processes, and SMS/contacts APIs.

### What lives on the phone
- Knowledge repos (ideas, relationships, organizations) — searchable offline
- Writing projects you're actively working on
- AI coding assistant (runs in Termux, reads your CLAUDE.md)
- Exported SMS, contacts, and call logs from the phone itself
- Photos and media rsync to server every 30 min (rsync over Tailscale SSH — resumable, incremental)
- Optional: local LLM (ollama + phi3:mini) for offline search — handy but limited

### What stays on the server
- Email (Maildir, too large)
- Cloud drive mirrors (Google Drive, Dropbox — 100GB+)
- Bulk conversation archives

### Setup

1. **Install from F-Droid** (all three — **must be same source**):
   - [Termux](https://f-droid.org/en/packages/com.termux/) (terminal emulator)
   - [Termux:API](https://f-droid.org/en/packages/com.termux.api/) (access SMS, contacts, camera, etc.)
   - [Termux:Boot](https://f-droid.org/en/packages/com.termux.boot/) (auto-start services on reboot)

   **Critical:** All three apps must come from F-Droid. Mixing sources (one from Play Store, one from F-Droid) causes the API bridge to fail silently.

2. **Android settings (do these BEFORE running setup):**
   - **Open Termux:API app once** — just launch it, let it load, close it
   - Developer Options → Disable child process restrictions
   - Settings → Apps → Termux → Battery → **Unrestricted**
   - Settings → Apps → Termux:API → Battery → **Unrestricted**
   - **Samsung phones:** Settings → Battery → Background usage limits → remove **both** Termux and Termux:API from "Sleeping apps" and "Deep sleeping apps"
   - **Android 13+:** Settings → Apps → Termux:API → three dots menu → **"Allow restricted settings"**
   - Grant permissions when prompted: SMS, Contacts, Phone/Call Log, Storage

3. **Run the setup script:**
   ```bash
   # In Termux:
   pkg install git
   git clone git@github.com:YOUR_USERNAME/digital-life-archive.git ~/archive
   bash ~/archive/scripts/phone-setup.sh
   ```
   This installs everything: git, python, SSH, rsync, syncthing, ollama, cron. Clones your knowledge repos. Sets up cron jobs for data export and sync. Tests that Termux:API works.

4. **Verify Termux:API works:**
   ```bash
   termux-battery-status    # Should return JSON with battery info
   termux-sms-list -l 1     # Should return your most recent SMS
   ```
   If these hang (no output for 10+ seconds), the API bridge is broken. See troubleshooting below.

5. **Set up media sync** (rsync over Tailscale):
   ```bash
   termux-setup-storage     # Grant storage access (Android dialog pops up)
   ```
   This creates `~/storage/` with symlinks to your phone's DCIM, Pictures, Movies, etc.

   The `phone-media-sync.sh` script rsyncs all phone media to your server every 30 minutes via cron. It syncs:
   - **DCIM/** — camera photos and videos, screenshots
   - **Pictures/** — app-saved images
   - **Movies/** — video files
   - **Recordings/** — voice recordings
   - **VisualVoiceMail/** — voicemail audio
   - **signal_backups/** — Signal encrypted backups
   - **Download/** — downloaded files
   - **Documents/** — documents
   - Loose PDFs in storage root

   Rsync uses `--partial` so interrupted transfers resume automatically. If the server is unreachable (offline), it silently skips and tries again on the next cron run.

   **To customize what gets synced**, edit `phone-media-sync.sh` — add or remove `sync_dir` lines for your directories.

   **Server-side setup:** Create a staging directory on your server:
   ```bash
   # On the server:
   mkdir -p ~/archive/private/photos-staging
   ```
   Then edit `phone-media-sync.sh` and set `SERVER` and `DEST` to match your server's user, IP, and path.

   **Alternative: Syncthing** (peer-to-peer, no SSH needed):
   ```bash
   syncthing                # Start once to generate device ID
   ```
   - Open `http://localhost:8384` in phone browser
   - Add your server as a remote device (use Tailscale IP)
   - Share `~/storage/dcim/Camera` as send-only
   - On server: accept and set receive folder to your photos directory

   Syncthing is better for real-time sync (instant photo upload). Rsync is better for reliability (resumable, scriptable, no daemon needed). You can use both — Syncthing for camera roll, rsync for everything else.

6. **Access the dashboard** from your phone:
   ```bash
   # Edit phone-tunnel.sh first — set your server's Tailscale IP
   ~/archive/scripts/phone-tunnel.sh &
   # Then open: https://localhost:8443
   ```

7. **Install an AI coding assistant:**
   ```bash
   pkg install nodejs
   npm install -g @anthropic-ai/claude-code
   cd ~/archive && claude
   ```
   Any coding assistant that reads CLAUDE.md works. This is what makes the phone a workstation, not just a data capture device.

8. **Optional: local LLM** (for offline use):
   ```bash
   ~/archive/scripts/phone-llm.sh "search for recent project notes"
   ~/archive/scripts/phone-llm.sh chat
   ```

### Data capture (automatic via cron)

Each data type gets its own private git repo on GitHub. The cron jobs export, commit, and push directly — no middleman. The server (or any other node) just pulls from GitHub.

- **SMS/MMS/RCS** (every minute): `export-sms.sh` → `export-sms-markdown.py` — formats every conversation as a markdown file (one per contact), grouped by date, with sent/received indicators. Raw JSON also saved. Commits and pushes to your `sms` repo.
- **Contacts** (every minute): `export-contacts.sh` — JSON export with daily snapshots. Commits and pushes to your `phone-contacts` repo.
- **Call log** (every minute): `export-calls.sh` — JSON export with cumulative deduplication. Commits and pushes to your `call-log` repo.
- **Photos + media** (every 30 min): `phone-media-sync.sh` — rsyncs DCIM, Pictures, Movies, Recordings, voicemail, Signal backups, downloads, and documents to the server staging directory. Uses `--partial` for resumable transfers.
- **Repo sync** (every 30 min): `phone-sync.sh` — pulls knowledge repos from GitHub, pushes any uncommitted data.

The export scripts are idempotent — if nothing changed, they don't commit. If the phone is offline, the push fails silently and succeeds on the next run. No data loss either way.

**What the SMS markdown looks like:**
```markdown
# Alex Chen
**Number:** +15551234567
**Messages:** 47

---

### 2026-02-08

→ **You** (19:20:41): Yeah I'm just over optimizing it's fine.

← **Alex Chen** (19:21:49): Haha - fantastic, love to hear it!
```

### Activation checklist

After running `phone-setup.sh`, verify these are working:

| Component | How to verify | Fix if broken |
|-----------|--------------|---------------|
| Termux:API | `termux-battery-status` returns JSON | See troubleshooting below |
| Cron | `crontab -l` shows 4 jobs | Re-run setup or `crontab -e` |
| crond | `pgrep crond` shows a PID | `crond` to start |
| SSH server | `pgrep sshd` shows a PID | `sshd` to start |
| Boot script | `ls ~/.termux/boot/` shows start-services.sh | Copy from scripts/ |
| Server connectivity | `ping -c 1 SERVER_TAILSCALE_IP` | Check Tailscale is running |
| SSH to server | `ssh user@SERVER_TAILSCALE_IP hostname` | Add phone SSH key to server |
| Storage access | `ls ~/storage/dcim/` shows Camera | `termux-setup-storage` |

### Troubleshooting: Termux:API hangs

If `termux-battery-status` or `termux-sms-list` produce no output and hang indefinitely, the Termux:API Android app bridge is broken. This is the #1 issue on Samsung and Pixel phones.

**Fixes (try in order):**

1. **Kill stuck processes:** `pkill -f termux-api`
2. **Open the Termux:API app** — tap it, let it fully load, close it
3. **Battery settings:** Settings → Apps → Termux:API → Battery → Unrestricted
4. **Samsung only:** Settings → Battery → Background usage limits → remove Termux:API from sleeping/deep sleeping
5. **Android 13+ only:** Settings → Apps → Termux:API → ⋮ → "Allow restricted settings"
6. **Force stop and restart:** Settings → Apps → Termux:API → Force Stop, then retry from Termux
7. **Nuclear option:** Uninstall Termux:API, reinstall from F-Droid, open it once, grant all permissions

After each fix, test with: `termux-battery-status`

The cron export jobs will simply log errors if the API isn't working — no data loss risk. Fix the API whenever convenient and the next cron run will start exporting.

### Two modes
1. **Connected**: tunnel active → full dashboard access, Syncthing moving files, git pull/push working
2. **Offline**: local LLM + local file search only. Data capture still running. Syncs when connection returns.

### Multi-node architecture
```
  Server (cloud/home)          Phone (Android)          Home server (optional)
  ┌──────────────────┐        ┌──────────────────┐      ┌──────────────────┐
  │ Full archive      │        │ Knowledge repos   │      │ Full mirror       │
  │ Email + cloud     │◄─────►│ Writing projects  │      │ Bigger LLM        │
  │ Dashboard         │  git   │ Claude Code       │      │ Fast local access │
  │ Claude Code       │ sync   │ SMS/contacts/call │      │ Second backup     │
  │ Backups to B2     │        │ Photo capture     │      │ Claude Code       │
  └──────────────────┘        └──────────────────┘      └──────────────────┘
         ▲                            ▲                          ▲
         └────────────────────────────┴──────────────────────────┘
                           Tailscale mesh VPN
```

Each node is independently useful. Add nodes when convenient. Every node is just git repos + scripts + Claude Code. The AI assistant is what turns a pile of files into something you actually use.

---

## Multi-Session, Multi-Node Coordination

AI assistants (Claude Code, etc.) can run simultaneously on multiple nodes — your server, your phone, a home server. The `coordination/` directory provides a protocol:

- `coordination/queued/` — Task starter packs. Self-contained briefings that a new session can pick up and execute.
- `coordination/SESSION_*.md` — Active session heartbeat files. Each session creates one on start, updates it during work, marks it COMPLETE on end. Includes **PID** and **Machine** (hostname or IP) so sessions across nodes can identify each other.

Git is the coordination layer. Sessions on different machines commit their session files, push, and pull to see what other sessions are doing. Conflicts are handled by git — the repos are mostly append-only, so collisions are rare and safe.

This prevents two sessions from editing the same files simultaneously. See `coordination/README.md` for the full protocol.

---

## AI Assistant Context (CLAUDE.md)

The `CLAUDE.md` file provides context for AI coding assistants. When an AI session opens your repo, it reads this file and understands:
- What the project is and how it's structured
- What tools are installed and how they work
- What rules to follow (privacy, commit patterns, etc.)
- What's in progress and what's queued

Update this file whenever your infrastructure changes.

---

## Cost Breakdown

| Item | Monthly Cost | Notes |
|------|-------------|-------|
| DigitalOcean droplet (2 vCPU, 4GB) | ~$24 | Scale up if needed |
| Block storage volume (500GB) | ~$25 | Only if needed |
| Backblaze B2 (200GB encrypted) | ~$1 | $0.005/GB/month |
| GitHub (unlimited private repos) | $0 | Free tier |
| Tailscale (personal) | $0 | Free for personal use |
| Domain name (optional) | ~$12/yr | Not required |
| Phone node (Termux) | $0 | Uses existing phone, free software |
| Server LLM (ollama) | $0 | Runs on existing server, CPU-only |
| Home server (optional) | ~$5/mo electricity | One-time ~$350 hardware |
| **Total (minimal)** | **~$25/mo** | |
| **Total (with volume)** | **~$50/mo** | |

---

## Lessons from Running This in Production

Things we learned the hard way that you'll probably run into:

**Centralize your config.** Once you have 5+ scripts importing the same constants (your email addresses, Neo4j credentials, base paths, etc.), create a `scripts/config.py` and import from it everywhere. Hardcoded duplicates across scripts will drift and break.

**Lockfiles for expensive cron jobs.** If you have a fast incremental job (every 5 min) and a slow full rebuild (hourly), the fast job needs to check for the slow job's lockfile and skip if it's running. Otherwise you get partial-state reads. Simple pattern: `if Path("/tmp/rebuild.lock").exists(): sys.exit(0)`.

**Recall over precision for triage.** If you build email triage or notification filtering, start by capturing everything and categorizing later. Aggressive pre-filtering will silently drop real messages. You can always ignore spam in the UI — you can't recover filtered-out replies from real people.

**OAuth on headless servers.** Google APIs need browser-based OAuth. On a headless server, use a reverse SSH tunnel: run the OAuth callback on server localhost:8090, tunnel it to a phone (`ssh -R 8090:localhost:8090 phone`), open the auth URL on the phone browser. The redirect hits localhost:8090 on the phone, which routes through the tunnel back to the server. Works for Calendar, Gmail, Contacts, any Google API.

**Google Calendar API sync.** The Calendar API gives you full read/write access — not just export. You can sync your entire calendar history into a JSON file, version it in git, and optionally create events programmatically. Set up OAuth once (same Google Cloud project as Gmail), then cron it alongside your other syncs.

**What else is possible.** Once you have your archive, you can mine it for structured knowledge — a graph of people, ideas, organizations, events, and relationships extracted from your emails, conversations, and files. That's beyond the scope of this template, but the architecture supports it. The files are there. The AI assistant can read them.

## Known Issues and Gotchas

| Issue | Workaround |
|-------|------------|
| gmvault broken on Python 3.12 (Ubuntu 24.04) | Use mbsync instead |
| Dropbox rate-limits aggressively | Let rclone retry automatically; large syncs take days |
| Google Photos can't bulk-download existing photos | Use Google Takeout |
| OpenAI/Claude have no export API | Manual export only |
| Ubuntu 24.04 blocks system-wide pip (PEP 668) | Use `python3 -m venv .venv` |
| Git submodules clone in detached HEAD | Run `git checkout main` before pushing |
| GitHub rejects files >100MB | Add LFS tracking in `.gitattributes` BEFORE committing |
| Google may rate-limit mbsync on first sync | Re-run `mbsync gmail` to continue |
| rclone OAuth tokens expire | Run `rclone config reconnect REMOTE:` to renew |
| Self-signed TLS certs expire | Regenerate with openssl (see Step 9) |
| Cron logs need write permission | Create log files with proper ownership (see Step 11) |
| `set -uo pipefail` causes silent cron failures | Use `set -o pipefail` without `-u`; add `export PATH` in scripts |
| Backblaze B2 free tier is only 10GB | Upgrade account and add payment method for larger archives |

## Disk Space Planning

| Source | Typical Size | Notes |
|--------|-------------|-------|
| Google Drive | 5-50 GB | Depends on usage |
| Dropbox | 2-100 GB | Camera uploads can be huge |
| Gmail | 1-15 GB | Decades of email |
| Google Photos | 10-200 GB | Use Takeout |
| ChatGPT | 50-500 MB | Compressed JSON + HTML |
| Slack | 100 MB - 5 GB | Depends on workspace count |
| Code repos | 100 MB - 5 GB | Depends on how many |

Plan for 2-3x your cloud storage size (local copy + git objects + LFS). A 500GB disk handles most personal archives comfortably.

---

## Design Principles

- **Ownership.** Your data under your control. Every platform replaceable. Every account deletable.
- **Privacy by default.** Everything private. Nothing public unless you choose. Other people's data treated with care.
- **Augmentation, not surveillance.** Helps you find, remember, and act. Never monitors, nudges, or profiles.
- **Sufficiency.** One server, not a cluster. Shell scripts, not Kubernetes. Simplest thing that works.
- **Durability.** Git + plaintext + open formats. Readable with standard Unix tools in 20 years.
- **Legibility.** Understandable by one person. Every script readable. Every cron job documented.
- **Autonomy.** You decide what to keep, delete, and share. The archive is complete — completeness is the point.

## Security

See `docs/security-hardening.md` for a guide to hardening your server after setup. Key principles:

- SSH key-only authentication (no passwords). Disable root login.
- Firewall (UFW) restricting SSH to known IPs or VPN only.
- Console app binds only to Tailscale IP — invisible to the public internet.
- Auth token and TLS certificates gitignored with proper file permissions (600).
- Encrypted backups with client-side encryption (Backblaze never sees plaintext).
- Defensive `.gitignore` to prevent accidental credential commits.

## License

[PolyForm Noncommercial 1.0.0](LICENSE) — free for personal use, research, education, nonprofits, and government. Not for commercial use. See [polyformproject.org](https://polyformproject.org/licenses/noncommercial/1.0.0/) for details.
