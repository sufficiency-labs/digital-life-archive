# Data Source Inventory

Checklist for identifying and archiving all sources of digital data.

## Cloud Storage

- [ ] Google Drive — `rclone sync gdrive:`
- [ ] Dropbox — `rclone sync dropbox:`
- [ ] OneDrive — `rclone sync onedrive:`
- [ ] iCloud — Takeout/export required (rclone not supported)

## Email

- [ ] Gmail — `mbsync` + `notmuch` indexing
- [ ] Work email — Verify employer policy; export may be restricted
- [ ] Additional email accounts — Configure additional mbsync channels

## Conversations

- [ ] ChatGPT — Settings > Data Controls > Export
- [ ] Claude — Settings > Privacy > Export Data
- [ ] Slack — `slackdump` per workspace
- [ ] Discord — `DiscordChatExporter` per server
- [ ] Signal — `signal-export` (Python) or Signal backup with decryption
- [ ] WhatsApp — Per-chat export or Google Drive backup
- [ ] SMS — SMS Backup & Restore application (Android) or ADB
- [ ] LinkedIn — Settings > Get a copy of your data

## Google Takeout (takeout.google.com)

- [ ] Google Photos
- [ ] Google Calendar
- [ ] Google Contacts
- [ ] Google Keep
- [ ] Google Maps location history
- [ ] YouTube watch history / subscriptions
- [ ] Google Fit / health data

## Social Media

- [ ] Twitter/X — Settings > Your Account > Download Archive
- [ ] Reddit — Account > Settings > Data Request
- [ ] Bluesky — Account > Export My Data (or AT Protocol API)
- [ ] Instagram — Account > Your Activity > Download Your Information
- [ ] Facebook — Settings > Your Information > Download Your Information

## Local Machine Data

- [ ] Browser history — Copy Chrome/Firefox SQLite databases
- [ ] Browser bookmarks — Export from browser
- [ ] Shell history — `~/.bash_history`, `~/.zsh_history`
- [ ] SSH config — `~/.ssh/config` (private keys excluded unless encrypted)
- [ ] VS Code settings — `~/.config/Code/User/`
- [ ] Local-only code repositories — Verify no unmigrated projects
- [ ] Desktop notes — Sticky notes or local note applications

## Phone Data

- [ ] Photos — Google Takeout or direct transfer
- [ ] Call log — Backup application or ADB
- [ ] Contacts — Google Contacts export
- [ ] Application-specific data — Varies by application

## Other Services

- [ ] Spotify — Account > Privacy > Download your data
- [ ] Amazon — Account > Order History > Download
- [ ] Goodreads — My Books > Import/Export > Export Library
- [ ] Password manager — Export (encrypt immediately, never commit plaintext)
- [ ] Banking — CSV exports per institution (encrypt)
- [ ] Health data — Google Fit, Apple Health, fitness applications

## Professional / Institutional

- [ ] Confluence / Jira — API exports
- [ ] Google Workspace (work) — Takeout if permitted
- [ ] Work Slack — Verify with IT department

## Implementation Phases

### Phase 1: Automated (configured once, executes daily)

- rclone synchronization (Google Drive, Dropbox)
- mbsync + notmuch (Gmail)
- Cron scheduling

### Phase 2: Manual exports (execute once, repeat periodically)

- Google Takeout requests
- ChatGPT / Claude exports
- Signal / SMS exports
- Social media data requests
- Browser history copies

### Phase 3: Ongoing maintenance

- Re-export manual sources quarterly
- Monitor for new services requiring archival
- Verify backup integrity
