# Security Hardening Procedures

Post-setup server hardening. Procedures for personal server security without excessive paranoia.

## Security Model

The archive contains complete digital life data: emails, files, conversations, relationship mapping. Security model: **only authorized user access permitted.**

Three defense layers:

1. **Network isolation** — Dashboard reachable only via Tailscale VPN. No public internet exposure.
2. **Authentication** — SSH requires private key (no passwords). Dashboard requires token.
3. **Encryption** — Backups encrypted client-side before upload. Backup provider cannot access plaintext.

## SSH Hardening

Server SSH port (22) exposed to internet. Bots continuously attempt brute-force attacks — thousands of attempts daily. Key-only authentication blocks all attempts. Additional lockdown recommended.

### Disable Password Authentication (typically pre-configured)

```bash
# Check current setting
grep "PasswordAuthentication" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*

# If not already "no", create hardening configuration:
echo "PasswordAuthentication no" | sudo tee /etc/ssh/sshd_config.d/99-hardening.conf
```

### Disable Root Login

```bash
echo "PermitRootLogin no" | sudo tee -a /etc/ssh/sshd_config.d/99-hardening.conf
sudo systemctl restart ssh
```

### Firewall (optional, recommended)

If static IPs available at home and work, whitelist and block all other access:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from HOME_IP to any port 22      # Home
sudo ufw allow from WORK_IP to any port 22      # Work
sudo ufw allow from 100.64.0.0/10 to any port 22     # Tailscale
sudo ufw allow from 100.64.0.0/10 to any port 8443   # Console via Tailscale
sudo ufw enable
```

Without static IPs, key-only SSH provides adequate security. Brute-force attempts are noise — cannot succeed.

**Emergency access:** Lockout recovery via hosting provider web console (DigitalOcean, AWS, etc. provide browser-based terminal access).

## File Permissions

Sensitive files restricted to user-only read access:

```bash
chmod 600 ~/.gmail-app-password
chmod 600 ~/.gmail-api-token.json
chmod 600 ~/.gmail-oauth-credentials.json
chmod 600 ~/.config/rclone/rclone.conf
chmod 600 ~/.mbsyncrc
chmod 600 app/auth_token
chmod 600 app/certs/key.pem
```

## .gitignore Configuration

`.gitignore` must prevent accidental credential commits. Minimum requirements:

```
app/auth_token
app/certs/
.venv/
.env
*.pem
*.key
__pycache__/
*.pyc
sync-status.json
```

Casual `git add .` must never commit secrets.

## Dashboard Security

FastAPI console designed for public internet invisibility:

- **Binds only to Tailscale IP** — not `0.0.0.0`, not `127.0.0.1`, not public IP
- **Requires auth token** via cookie or Bearer header
- **Uses HTTPS** with self-signed certificate
- **Cookie is httponly + samesite=strict** — XSS and CSRF resistant

### Security Considerations

- Auth token stored as file (`app/auth_token`). Maintain 600 permissions.
- Cookie stores raw auth token. Cookie theft provides token access. Acceptable for 2-device Tailscale configuration.
- Email send endpoint passes user input to neomutt. Validate inputs if extending functionality.
- Claude task runner builds shell commands. If modifying, use `shlex.quote()` for user inputs.

## Backup Security

Backup uses rclone crypt:

- **Client-side encryption** — data encrypted on server before upload
- **Zero-knowledge** — Backblaze (or alternative provider) only sees ciphertext
- **Passphrase requirement** — without passphrase, backup permanently unrecoverable

Store encryption passphrase and salt in password manager (1Password, Bitwarden, etc.), not exclusively on server. Server failure with server-only passphrase renders backup useless.

```bash
# Passphrase location in rclone config:
cat ~/.config/rclone/rclone.conf | grep password
# Values are rclone-obscured, not actual passphrase
# Actual passphrase is value typed during `rclone config`
```

## GitHub Security

All private repositories stored on GitHub. Account protection requirements:

- **Enable multi-factor authentication** (hardware key + TOTP + recovery codes)
- **Use SSH keys** for git operations (not HTTPS with tokens)
- **Review authorized applications** periodically (Settings > Applications)
- **Store recovery codes** securely (password manager, printed in safe)

## Tailscale Security

Tailscale functions as dashboard gateway. Account protection requirements:

- **Enable MFA** on Tailscale account
- **Key expiry enabled** (default 180 days) — do not disable
- **Review devices** periodically (`tailscale status`)
- Device loss requires immediate removal from Tailscale admin

## Unnecessary Precautions

- **Encryption at rest on server disk:** Hosting provider (DigitalOcean, etc.) has physical disk access. Full disk encryption assists stolen-laptop scenarios but not compromised cloud provider. Data already backed up encrypted to B2. Hosting provider concern is trust decision, not technical issue.
- **Complex firewall rules:** Key-only SSH already very strong. UFW provides additional security layer.
- **Intrusion detection systems:** Personal server with two connecting devices. Detection would be obvious.
- **Regular auth token rotation:** Personal dashboard behind VPN. Change if compromise suspected, otherwise maintain current token.

## Periodic Verification

Every few months:

- [ ] `tailscale status` — all connected devices recognized?
- [ ] Check SSH `authorized_keys` — only authorized keys present?
- [ ] `gh auth status` — GitHub still connected?
- [ ] Test backup restore: `rclone ls b2-crypt:cloud/google-drive/ | head`
- [ ] Check TLS certificate expiry: `openssl x509 -enddate -noout -in app/certs/cert.pem`
- [ ] Renew certificate if expiring: regenerate with openssl (see README Setup Step 9)
