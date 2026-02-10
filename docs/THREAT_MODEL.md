# Threat Model

## Document Purpose

This document identifies assets requiring protection, credible threats to those assets, threat actor capabilities, implemented mitigations, and accepted risks. The threat model informs security architecture decisions and identifies where additional hardening provides diminishing returns.

## Protected Assets

### Primary Assets

1. **Complete digital life archive**
   - All emails (decades of correspondence)
   - All cloud files (documents, photos, videos)
   - All conversations (ChatGPT, Claude, Slack, Discord, Signal, SMS)
   - Relationship context (people you know, with notes)
   - Project and idea tracking
   - Organization mapping

2. **Access credentials**
   - SSH private keys
   - rclone OAuth tokens (Google Drive, Dropbox access)
   - Gmail app password
   - GitHub personal access tokens
   - Tailscale authentication
   - Dashboard auth token
   - Backblaze B2 encryption passphrase

3. **Service continuity**
   - Ability to access archive when needed
   - Ability to synchronize new data
   - Ability to restore from backup if primary fails

### Asset Value Assessment

**Complete archive contents:** Irreplaceable. Decades of life history, relationships, intellectual work. Loss constitutes permanent destruction of personal memory and context.

**Access credentials:** Replaceable but with significant effort. Credential compromise requires credential rotation, service reconfiguration, potential archive re-encryption.

**Service continuity:** Disruption acceptable for hours. Extended disruption (days) causes inconvenience but not permanent harm.

## Threat Actors

### In-Scope Threat Actors

1. **Opportunistic attackers** (automated scanning, mass exploitation)
   - Capabilities: Automated vulnerability scanning, brute-force attacks, exploitation of known vulnerabilities
   - Motivation: Credential theft for resale, ransomware deployment, botnet recruitment
   - Sophistication: Low. Uses publicly available exploits and tools.

2. **Hosting provider** (DigitalOcean, etc.)
   - Capabilities: Physical server access, disk access, network traffic inspection
   - Motivation: Generally aligned (business reputation), but subject to legal compulsion, insider threats, or compromise
   - Sophistication: High technical capability, but incentivized against abuse

3. **GitHub** (repository host)
   - Capabilities: Access to all repository contents (encrypted backups excluded)
   - Motivation: Generally aligned, but subject to legal compulsion or compromise
   - Sophistication: High

4. **Google / Dropbox** (cloud storage providers)
   - Capabilities: Access to all data stored on their platforms
   - Motivation: Business interest in data retention, subject to legal compulsion
   - Sophistication: High

5. **Backup provider (Backblaze B2)**
   - Capabilities: Access to encrypted backup blobs (but not plaintext with proper client-side encryption)
   - Motivation: Generally aligned, subject to legal compulsion
   - Sophistication: High

6. **Self (operator error)**
   - Capabilities: Complete access to all systems
   - Motivation: No malicious intent, but capable of accidental destruction or exposure
   - Sophistication: Variable

### Out-of-Scope Threat Actors

1. **Nation-state actors** (APT groups, intelligence agencies)
   - Rationale: Personal archive contains no state secrets, classified information, or high-value intelligence. Nation-states have no motivation to target this archive specifically. If targeted, technical mitigations are insufficient — nation-state capabilities exceed personal defense capacity.

2. **Organized crime syndicates**
   - Rationale: Archive contains no financial data of criminal interest (no banking credentials, credit card numbers, cryptocurrency keys). Relationship data and personal history have no resale value to organized crime.

3. **Corporate espionage actors**
   - Rationale: Archive contains no trade secrets, proprietary technology, or competitive intelligence of corporate value.

4. **Targeted harassment actors** (stalkers, doxxers)
   - Rationale: Archive is not public. Discovery requires existing knowledge of infrastructure. If targeted by dedicated harassment actor, threat model changes — requires law enforcement involvement, not technical measures.

## Threat Scenarios

### High Priority Threats (Address with technical mitigations)

#### T1: SSH Brute-Force / Credential Stuffing

**Threat:** Automated bots attempt SSH authentication using common passwords or leaked credentials.

**Attack Vector:** Public internet exposure of SSH port (22).

**Impact if Successful:** Complete server compromise. Archive exfiltration. Credential theft. Service disruption.

**Likelihood:** Constant attempts (thousands per day). Success likelihood near-zero with key-only authentication.

**Mitigation:**
- SSH key-only authentication (no password authentication)
- Root login disabled
- Optional: UFW firewall restricting SSH to known IPs or Tailscale-only
- Fail2ban provides marginal additional protection (bans repeat offenders temporarily)

**Residual Risk:** Near-zero. Compromise requires SSH private key theft (separate threat).

#### T2: SSH Private Key Theft

**Threat:** Attacker obtains SSH private key from laptop, phone, or backup.

**Attack Vectors:**
- Laptop theft or compromise
- Phone theft or compromise
- Backup media theft (if private key backed up unencrypted)
- Malware on personal device

**Impact if Successful:** Complete server compromise (same as T1).

**Likelihood:** Low. Requires physical device access or device compromise.

**Mitigation:**
- Private keys password-protected (SSH key passphrase)
- Laptop disk encryption (FileVault, LUKS, BitLocker)
- Phone storage encryption (default on modern Android/iOS)
- Private keys not backed up to cloud storage
- Tailscale authentication requires separate credential (defense in depth)

**Residual Risk:** Low. Physical device theft with encryption cracking required.

#### T3: Hosting Provider Compromise or Legal Compulsion

**Threat:** Hosting provider (DigitalOcean, etc.) accesses server data due to insider threat, provider compromise, or legal subpoena.

**Attack Vector:** Physical server access, disk snapshot, or network traffic interception at provider level.

**Impact if Successful:** Complete archive contents exposed. Access credentials exposed (SSH keys, OAuth tokens, auth tokens).

**Likelihood:** Low for insider threat / compromise. Higher for legal compulsion if subject to investigation.

**Mitigation:**
- **Client-side encrypted backups:** Backblaze B2 backup encrypted with rclone crypt. Provider sees only ciphertext. Encryption passphrase not stored on server (stored in password manager).
- **Tailscale VPN:** Dashboard traffic encrypted end-to-end. Hosting provider cannot intercept dashboard authentication or contents.
- **GitHub:** All repositories on GitHub, not exclusively on server. Hosting provider compromise does not destroy data, only exposes snapshot.

**Accepted Risk:** If hosting provider is compromised or legally compelled, archive contents on server disk are exposed. This is accepted risk — full disk encryption provides minimal protection against hosting provider with physical access. Mitigation is data minimization (most sensitive data stored only on local laptop, not server) and encrypted backup ensuring recovery capability.

#### T4: GitHub Compromise or Legal Compulsion

**Threat:** GitHub accesses repository contents due to compromise or legal compulsion.

**Attack Vector:** GitHub internal access to private repositories.

**Impact if Successful:** Archive contents exposed (conversations, email, cloud files, relationship data, idea index). Credentials in repository history exposed if accidentally committed.

**Likelihood:** Low for compromise. Higher for legal compulsion.

**Mitigation:**
- **Defensive `.gitignore`:** Prevents accidental credential commits (auth tokens, SSH keys, TLS certs, rclone config).
- **Pre-commit hooks (optional):** Automated scanning for credential patterns before commit.
- **Encrypted backups separate from GitHub:** Backblaze B2 encrypted backup not dependent on GitHub.
- **Repository separation:** Different repositories for different sensitivity levels. Most sensitive content can be kept in local-only repositories (not pushed to GitHub).

**Accepted Risk:** GitHub can access all pushed repository contents. This is accepted risk — GitHub is trusted to reasonable degree. Most sensitive personal writing or private notes can be kept in local-only repos.

#### T5: Dashboard Authentication Token Theft

**Threat:** Attacker obtains dashboard auth token and uses it to access dashboard via Tailscale VPN.

**Attack Vectors:**
- Token file theft from server (`app/auth_token`)
- Cookie theft from browser on phone/laptop
- Token exposure via accidental commit to git

**Impact if Successful:** Dashboard access. Archive browsing. Email reading. File editing capability. Potential git commits attributed to legitimate user.

**Likelihood:** Low. Requires either server compromise (see T1, T2, T3) or cookie theft from personal device.

**Mitigation:**
- Token file permissions 600 (user-only read)
- Token gitignored (defensive `.gitignore`)
- Cookie httponly + samesite=strict (resists XSS and CSRF)
- Dashboard binds only to Tailscale IP (requires attacker to be on VPN)
- Tailscale requires separate authentication (defense in depth)

**Accepted Risk:** Cookie theft from personal device provides dashboard access. Token is not rotated regularly. This is accepted for personal 2-device setup. For higher security requirement, implement token rotation and hardware key-based authentication.

#### T6: Backup Encryption Passphrase Loss

**Threat:** Backup encryption passphrase and salt are lost (forgotten, password manager failure, physical media destruction).

**Attack Vector:** Self (operator error), password manager compromise or data loss.

**Impact if Successful:** Complete backup unrecoverable. If server simultaneously fails, archive lost.

**Likelihood:** Low with proper password manager use. Higher if passphrase only stored in one location.

**Mitigation:**
- Passphrase stored in password manager (1Password, Bitwarden, etc.)
- Passphrase additionally stored in separate secure location (paper in safe, separate encrypted backup)
- Regular backup restore tests verify passphrase works

**Residual Risk:** Low. Requires password manager failure AND separate backup failure simultaneously.

#### T7: Accidental Data Deletion

**Threat:** Operator accidentally deletes files, commits destructive changes, or corrupts archive.

**Attack Vector:** Self (operator error).

**Impact if Successful:** Data loss. Degree depends on scope of deletion and backup freshness.

**Likelihood:** Medium. Human error is consistent threat.

**Mitigation:**
- **Git version control:** All changes versioned. Accidental deletion recoverable from git history.
- **Daily encrypted backups:** Backblaze B2 backup provides point-in-time recovery.
- **GitHub redundancy:** All repositories on GitHub. Accidental local deletion recoverable from GitHub.
- **Multi-node architecture:** Phone node and optional home server provide additional redundancy.

**Residual Risk:** Very low. Requires accidental deletion AND backup failure AND git history destruction AND GitHub deletion simultaneously.

### Medium Priority Threats (Monitor, mitigate if cost is low)

#### T8: Tailscale Account Compromise

**Threat:** Attacker compromises Tailscale account via credential theft or account takeover.

**Attack Vectors:**
- Tailscale password theft
- MFA bypass (if MFA not enabled)
- Session cookie theft

**Impact if Successful:** Attacker joins Tailscale VPN. Dashboard becomes accessible. Server SSH becomes accessible via Tailscale IP.

**Likelihood:** Low. Requires Tailscale account compromise (separate from server compromise).

**Mitigation:**
- **MFA enabled on Tailscale account** (recommended)
- **Device authorization required:** New devices must be approved before joining VPN
- **Regular device list review:** Unauthorized devices detected and removed

**Residual Risk:** Low with MFA. Tailscale compromise still requires dashboard auth token or SSH private key for actual access.

#### T9: Malicious Git Submodule or Shared Repository

**Threat:** Collaborator or compromised account creates malicious submodule or commits malicious code to shared repository.

**Attack Vector:** Git submodule addition, commit with malicious script.

**Impact if Successful:** Code execution if malicious script executed. Credential theft if malicious code accesses credential files.

**Likelihood:** Very low. Requires compromised collaborator or malicious collaboration.

**Mitigation:**
- **Code review before accepting shared repositories:** Inspect contents before cloning.
- **Submodules independently cloneable:** Submodule cannot access parent repository files.
- **Sandboxing:** Each repository is directory with no cross-directory access.
- **Git diff review before pull:** Review all changes before incorporating.

**Residual Risk:** Very low. Requires operator to execute unknown code without inspection.

#### T10: Dependency Compromise (Supply Chain Attack)

**Threat:** Python packages (FastAPI, rclone, notmuch, etc.) compromised and include malicious code.

**Attack Vector:** Compromised PyPI package, compromised system package in apt repository.

**Impact if Successful:** Arbitrary code execution. Credential theft. Archive exfiltration.

**Likelihood:** Very low for mainstream packages. Higher for obscure dependencies.

**Mitigation:**
- **Minimal dependency usage:** Only essential packages installed.
- **Virtual environment isolation:** Python packages in `.venv/`, not system-wide.
- **Package source trust:** Use official package repositories (PyPI, Ubuntu apt) rather than third-party sources.
- **Pinning versions (optional):** Pin specific package versions in requirements.txt to prevent automatic malicious updates.

**Residual Risk:** Low. Supply chain attacks on mainstream packages are rare and typically detected quickly.

### Low Priority Threats (Accept risk, no additional mitigation)

#### T11: DDoS Attack on Server

**Threat:** Attacker floods server with traffic, causing service disruption.

**Attack Vector:** Network flood (HTTP, SSH, or lower-level network attack).

**Impact if Successful:** Dashboard unavailable. SSH unavailable. Service disruption only — no data loss.

**Likelihood:** Very low. Personal server has no public-facing web service. Dashboard is Tailscale-only.

**Mitigation:** None beyond Tailscale VPN (eliminates public attack surface for dashboard).

**Accepted Risk:** If attacker floods SSH port, server becomes temporarily unavailable. This is acceptable — service continuity is low-priority asset. Hosting provider typically provides DDoS mitigation for severe attacks.

#### T12: Zero-Day Vulnerability in Server Software

**Threat:** Unpatched vulnerability in SSH, Linux kernel, or other server software allows remote code execution.

**Attack Vector:** Exploitation of unknown vulnerability before patch available.

**Impact if Successful:** Complete server compromise (same as T1).

**Likelihood:** Very low. Server attack surface is minimal (SSH only public-facing service).

**Mitigation:**
- **Automatic security updates enabled:** Ubuntu unattended-upgrades installs security patches automatically.
- **Minimal installed software:** Reduces attack surface.
- **Regular server restarts:** Ensures kernel patches applied.

**Accepted Risk:** Zero-day vulnerabilities exist. Personal server is low-value target. Likelihood of exploitation before patch is very low.

#### T13: Ransomware

**Threat:** Ransomware encrypts archive contents and demands payment.

**Attack Vector:** Server compromise via T1, T2, or T10.

**Impact if Successful:** Archive encrypted. Service disruption.

**Likelihood:** Very low. Ransomware primarily targets Windows. Linux ransomware exists but is rare.

**Mitigation:**
- **Daily encrypted backups:** Backblaze B2 backup provides recovery without ransom payment.
- **Git version control:** All changes versioned. Ransomware encryption is reversible via git history.
- **Multi-node redundancy:** Phone and optional home server provide additional recovery points.

**Accepted Risk:** Ransomware causes temporary disruption only. Archive is recoverable from backup. No payment required.

## Mitigations Summary

| Threat | Mitigation | Residual Risk |
|--------|-----------|---------------|
| T1: SSH brute-force | Key-only auth, root disabled, optional firewall | Near-zero |
| T2: SSH key theft | Key passphrase, device encryption | Low |
| T3: Hosting provider compromise | Encrypted backups, GitHub redundancy, Tailscale VPN | Accepted |
| T4: GitHub compromise | Defensive .gitignore, encrypted backups | Accepted |
| T5: Dashboard token theft | Token permissions, gitignore, cookie security, Tailscale-only | Low |
| T6: Backup passphrase loss | Password manager, redundant storage, regular tests | Low |
| T7: Accidental deletion | Git, daily backups, GitHub redundancy, multi-node | Very low |
| T8: Tailscale compromise | MFA, device authorization, regular review | Low |
| T9: Malicious repository | Code review, submodule isolation, git diff review | Very low |
| T10: Dependency compromise | Minimal dependencies, venv isolation, package source trust | Low |
| T11: DDoS | Tailscale VPN (no public dashboard) | Accepted |
| T12: Zero-day | Auto security updates, minimal software, regular restarts | Accepted |
| T13: Ransomware | Daily backups, git versioning, multi-node redundancy | Very low |

## Accepted Risks

### 1. Hosting Provider Access

**Risk:** Hosting provider (DigitalOcean, etc.) can access server disk and archive contents.

**Rationale:** Full disk encryption provides minimal protection against hosting provider with physical access. Client-side encrypted backups provide recovery capability if hosting provider is hostile. Trust in hosting provider is necessary — alternative is self-hosted hardware (higher cost, higher operational burden).

**Mitigation if risk becomes unacceptable:** Migrate to self-hosted hardware on premises. Accept increased operational burden and single-point-of-failure risk.

### 2. GitHub Repository Access

**Risk:** GitHub can access all pushed repository contents.

**Rationale:** GitHub is trusted to reasonable degree. Encrypted backups exist separate from GitHub. Most sensitive content can be kept in local-only repositories.

**Mitigation if risk becomes unacceptable:** Remove GitHub as remote for sensitive repositories. Accept loss of GitHub's redundancy and collaboration features.

### 3. Service Continuity Disruption

**Risk:** Server becomes unavailable for hours or days due to DDoS, hosting provider outage, or other service disruption.

**Rationale:** Service continuity is lowest-priority asset. Archive is not life-critical infrastructure. Temporary unavailability is acceptable.

**Mitigation if risk becomes unacceptable:** Deploy multi-region redundancy (significantly higher cost). Not justified for personal archive.

### 4. Nation-State or Advanced Persistent Threat Targeting

**Risk:** If targeted by nation-state or APT group, technical mitigations are insufficient.

**Rationale:** Nation-states have capabilities exceeding personal defense capacity (zero-day stockpiles, legal compulsion, covert device compromise). Defense against nation-states requires operational security (OPSEC) changes, not technical changes — assume all technical systems are compromised.

**Mitigation if risk becomes unacceptable:** This represents threat model change. Requires legal counsel, potential relocation, operational security overhaul. Technical mitigations are irrelevant.

## Security Investment Priorities

Based on threat likelihood and impact, security investment should prioritize:

1. **Backup integrity and passphrase redundancy** (T6, T7) — Highest return on investment. Prevents permanent data loss.
2. **SSH hardening** (T1, T2) — Low cost, high effectiveness. Prevents most common attack vector.
3. **Defensive git practices** (T4, T7) — Low cost, prevents accidental exposure and data loss.
4. **Tailscale MFA** (T8) — Low cost, adds authentication layer.
5. **Regular backup restore tests** (T6, T7) — Verifies backup functionality before needed.

Low-return security investments (not recommended unless threat model changes):

- Full disk encryption (minimal protection against hosting provider)
- Hardware security modules (overkill for personal archive)
- Intrusion detection systems (obvious detection with 2-device setup)
- Regular credential rotation (low threat without compromise evidence)
- Multi-region redundancy (high cost for low-priority service continuity)

## Threat Model Maintenance

This threat model should be reviewed and updated when:

- Infrastructure changes significantly (new nodes, new services, new cloud providers)
- Threat actor capabilities change (new vulnerability classes, new attack techniques)
- Asset value changes (archive contains newly sensitive information)
- Residual risk becomes unacceptable (user risk tolerance changes)

## Conclusion

The digital life archive security model prioritizes:

1. **Data durability** over service continuity
2. **Defense in depth** over single-point security
3. **Encryption where effective** (backups) over encryption for compliance (disk encryption against hosting provider)
4. **Simplicity and auditability** over complex security theater

Accepted risks are explicitly documented. Security investment focuses on high-return mitigations. Nation-state and APT threats are out of scope — if threat model changes to include these actors, architecture requires fundamental redesign beyond technical hardening.
