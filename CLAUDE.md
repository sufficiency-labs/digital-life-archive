# CLAUDE.md — AI Assistant Context

## What is this?
A digital life archive — one person's entire digital footprint versioned in Git. Cloud storage, email, conversations, code repos, config files — all submodules of a parent monorepo. The goal: own every byte of your data, searchable and backed up, independent of any platform.

## Architecture
- **Parent repo**: orchestrates submodules, holds scripts, app, docs
- **Submodules**: each data source is an independent git repo (all private)
- **Cloud data**: synced via rclone, binary files tracked with git-lfs
- **Email**: mbsync (IMAP) to local Maildir, indexed by notmuch, sendable via neomutt
- **Dashboard**: FastAPI web app, HTTPS, Tailscale-only access (invisible to public internet)
- **Backup**: encrypted client-side via rclone crypt to Backblaze B2 (zero-knowledge)
- **Runs on**: a single Linux server (Ubuntu 24.04, typically a DigitalOcean droplet)
- **Phone node**: Android phone with Termux — knowledge repos, Claude Code, data capture (SMS/contacts/calls/photos), offline-capable
- **AI assistant**: Claude Code running on every node — reads this CLAUDE.md, understands the whole archive, does the actual work. Local LLMs (ollama) available for offline basics but not the main show.
- **Home server** (optional): third node for full mirror, local-speed access

## Key directories
- `cloud/` — Google Drive, Dropbox (rclone sync, each a git submodule with LFS)
- `conversations/` — ChatGPT, Claude, Slack, Discord, LinkedIn exports
- `private/` — Code repos + knowledge extraction repos (idea-index, relationships, organizations)
- `config/` — Dotfiles and environment config
- `app/` — Web dashboard (FastAPI + Tailscale-only binding)
  - `app/server.py` — API server (status, email, notifications, triage, files, contacts, ideas)
  - `app/static/index.html` — Frontend SPA (terminal-aesthetic, PWA-installable)
  - `app/certs/` — Self-signed TLS certificates (gitignored)
  - `app/auth_token` — Bearer token (gitignored, permissions 600)
- `scripts/` — Automation scripts (check-mail, triage, import-contacts)
- `coordination/` — Multi-session task management for AI assistants
  - `coordination/queued/` — Task starter packs (self-contained briefings)
  - `coordination/SESSION_*.md` — Active session heartbeat files
- `docs/` — Guides: knowledge extraction, privacy cleanup, data capture, security hardening

## Tools
- `rclone` — cloud sync (Google Drive, Dropbox, Backblaze B2, 40+ backends)
- `git-lfs` — large file storage for binary/media
- `gh` — GitHub CLI
- `mbsync` (isync) — Gmail IMAP sync to Maildir
- `notmuch` — full-text email search indexer
- `neomutt` — terminal email client with SMTP sending
- `slackdump` — Slack export
- `DiscordChatExporter` — Discord export
- `tailscale` — WireGuard mesh VPN for private access
- `signal-cli` — Signal messaging (optional, for VIP email alerts)
- `ollama` — local LLM inference server (CPU or GPU, runs open-source models)
- `aider` — AI coding assistant that works with local LLMs via ollama
- Python venv at `.venv/` with FastAPI, uvicorn, python-multipart, aider-chat

## Scripts
- `setup.sh` — one-time server provisioning (installs all dependencies)
- `sync-all.sh` — automated cloud + email sync (cron, 3am daily)
- `backup.sh` — encrypted backup to Backblaze B2 (cron, 4am daily, with error tracking)
- `status.sh` — health check dashboard (cron, 6am, email alert on failure)
- `scripts/check-mail.py` — frequent email checking (cron, every 15min), routes to next-actions + Signal alerts for VIP contacts
- `scripts/gpu-droplet.sh` — spin up/down on-demand GPU droplets with ollama for larger models

## Critical rules
- **EVERYTHING IS PRIVATE BY DEFAULT.** Never create public repos unless explicitly told to.
- Never delete user data without explicit confirmation.
- **COMMIT AND PUSH CONTINUOUSLY.** After every meaningful change. If the session dies, uncommitted work is lost.
- Cloud submodules use LFS for binary files — commit .gitattributes first.
- Each cloud submodule should be on `main` branch, not detached HEAD.
- The `.venv/` directory is not committed.
- Sensitive files (auth_token, certs, rclone config) must never be committed — `.gitignore` enforces this.

## Security model
- SSH: key-only auth, root login disabled, optionally firewall-restricted
- Dashboard: Tailscale-only binding (not 0.0.0.0), auth token required, HTTPS
- Backup: client-side encrypted (rclone crypt), provider sees only ciphertext
- GitHub: all repos private, MFA required, SSH keys for auth
- See `docs/security-hardening.md` for the full guide

## Values
This project follows explicit design principles (see README): ownership, privacy by default, augmentation not surveillance, sufficiency, durability, legibility, autonomy.

## Dashboard
- FastAPI app at `app/server.py`
- Binds ONLY to Tailscale IP on port 8443
- Auth token at `app/auth_token` (gitignored)
- TLS certs at `app/certs/` (gitignored)
- Manage: `sudo systemctl {start|stop|restart|status} archive-console`

### Dashboard Features
- **Next Actions Queue** (`coordination/next-actions.json`) — ordered task list, reorderable from phone. Two action types: standalone tasks and pointers (to queued tasks, email threads, contacts). API: GET/POST/PUT/DELETE /api/actions, POST /api/actions/reorder. Auto-commits to git.
- **Email** — search (notmuch), read threads, compose/send (neomutt)
- **Files** — browse, search, read, edit with auto git commit
- **Ideas** — browse idea-index entries
- **Notifications** — `/api/notifications` returns new uncompleted next-actions since last check. Browser Notification API polling every 60s.
- **Status** — system health, sync/backup log status, disk usage, B2 backup size, active sessions, queued tasks

### Backup & Sync Monitoring
- Status API returns `logs` object with `backup`, `sync`, `checkmail` entries (status, age_hours, last_line)
- B2 backup size reported via `rclone size b2: --json`
- `backup.sh` uses error tracking (`ERRORS` counter) and auto-discovers all private repos

## Local LLM (ollama)
- **Server**: ollama runs as a systemd service, API at `localhost:11434`
- **Phone**: ollama optional in Termux, runs smaller models (phi3:mini, 3.8B)
- **Models**: pull with `ollama pull <model>` — e.g., `llama3.2:3b` (CPU), `llama3:70b` (needs GPU)
- **aider**: AI coding assistant in `.venv/`, works with local ollama models
  - Run: `.venv/bin/aider --model ollama/llama3.2:3b`
  - Does file edits, git commits, code review — like Claude Code but with local models
- **No GPU**: CPU-only inference works (~10 tok/s for 3B). For 70B models, add a GPU (RTX 3090 used ~$800, one-time)
- **Dashboard integration**: phone-tunnel.sh forwards server ollama (port 11434) to phone localhost, so phone can query server's model when connected

## Phone node scripts (scripts/)
- `phone-setup.sh` — one-time Termux setup (packages, repos, cron, SSH)
- `phone-boot.sh` — Termux:Boot auto-start (sshd, crond, syncthing, tunnel, ollama)
- `phone-sync.sh` — bidirectional repo sync (pull knowledge repos, push data repos via git)
- `phone-tunnel.sh` — persistent autossh tunnel to server dashboard
- `phone-media-sync.sh` — rsync all phone media (DCIM, Pictures, Movies, Recordings, voicemail, Signal backups, downloads, documents) to server (cron, every 30 min)
- `phone-llm.sh` — local LLM wrapper with CLAUDE.md context + repo search
- `export-sms.sh` — SMS/MMS/RCS export as markdown conversations + git push (cron, every minute)
- `export-sms-markdown.py` — Python script that formats SMS into per-contact markdown files with INDEX.md
- `export-contacts.sh` — contacts export as JSON + git push (cron, every minute)
- `export-calls.sh` — call log export as JSON with deduplication + git push (cron, every minute)

## Phone data repos (separate git repos, pushed to GitHub)
- `sms` — SMS/MMS/RCS messages as markdown conversations (conversations/*.md) + raw JSON (raw/*.json)
- `phone-contacts` — phone contacts as JSON snapshots
- `call-log` — call records as JSON with cumulative deduplication

## Session coordination — MANDATORY
**This is not optional. Every AI session in this repo MUST follow this protocol.**

1. **FIRST THING on session start:** Create `coordination/SESSION_<TIMESTAMP>.md` with what you're working on, including your **PID** (`$PPID` from bash) and **Machine** (hostname or Tailscale IP). Sessions may run on multiple nodes simultaneously — the machine field is how they identify each other. Commit and push it immediately.
2. **Before touching any shared file:** Read ALL other active session files (STATUS: ACTIVE) in `coordination/`. If another session is touching the same files, coordinate or wait.
3. **During work:** Update your session file when changing tasks. Commit and push the update.
4. **On end:** Mark as `STATUS: COMPLETE` with final status and next steps. Commit and push.

See `coordination/README.md` for the full protocol.

## Queued tasks — auto-create for big ideas
When you encounter a substantial task that's too big or unrelated to the current session, **automatically** create a starter pack file at `coordination/queued/<task-name>.md`. This applies to:
- New feature ideas (1+ hours)
- Infrastructure changes needing dedicated focus
- Cross-cutting concerns touching multiple submodules
- Tasks the user mentions in passing that deserve their own session

Each queued task file must be self-contained — a fresh session should be able to read it and start working with no other context. Include: objective, current state, requirements, technical design, files to touch, success criteria.

## Knowledge extraction
The archive supports structured knowledge extraction. An `idea-index` placeholder is included — use your AI assistant to mine your archive for projects, ideas, and frameworks. See `docs/knowledge-extraction.md` for the methodology.

### Scripts
- **check-mail.py** — Frequent email check pipeline: mbsync + notmuch new + optional Signal alerts for VIP contacts.

## Testing
**Playwright UI tests** at `tests/test_console.py` catch console bugs before they reach production. Run with: `./scripts/run-tests.sh`.

Tests cover:
- Basic navigation (page loads, nav buttons)
- Next Actions (complete, delete, navigation, drag-and-drop)
- Communication triage
- Console health (no errors, API responses)

Use `.venv` for all Python dependencies. Add tests for new features. Run before deploying console changes.
