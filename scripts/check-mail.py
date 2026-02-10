#!/usr/bin/env python3
"""
Check for new important emails and route to next-actions.json.
Runs after mbsync + notmuch new. Tracks last-seen timestamp.

Priority contacts get Signal notifications (optional).
Known contacts (anyone in relationships repo) get added to next-actions.

Cron example (every 15 minutes):
  */15 * * * * /home/YOU/archive/.venv/bin/python /home/YOU/archive/scripts/check-mail.py >> /var/log/archive-checkmail.log 2>&1
"""

import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ARCHIVE_DIR = Path(os.environ.get("ARCHIVE_DIR", os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
STATE_FILE = ARCHIVE_DIR / "scripts" / ".check-mail-state.json"
NEXT_ACTIONS = ARCHIVE_DIR / "coordination" / "next-actions.json"
PEOPLE_DIR = ARCHIVE_DIR / "private" / "relationships" / "people"

# CONFIGURE: Your email address (to filter out self-sent mail)
MY_EMAIL = os.environ.get("MY_EMAIL", "you@gmail.com")

# CONFIGURE: Optional Signal notification for VIP contacts
# Set SIGNAL_ACCOUNT to your phone number to enable Signal alerts
SIGNAL_ACCOUNT = os.environ.get("SIGNAL_ACCOUNT", "")

# CONFIGURE: VIP contacts — get immediate Signal notification
# Add email addresses of people whose messages you want alerted on immediately
VIP_EMAILS = set()
# Example:
# VIP_EMAILS = {
#     "spouse@example.com",
#     "boss@company.com",
#     "mentor@university.edu",
# }

# Ignore these (automated, no action needed)
IGNORE_PATTERNS = [
    "noreply@", "no-reply@", "notifications@", "mailer-daemon@",
    "donotreply@", "updates@", "news@", "newsletter@",
    "support@github.com", "github.com", "linkedin.com",
    "substack.com", "stripe.com", "googlealerts",
]


def load_state():
    if STATE_FILE.exists():
        with open(STATE_FILE) as f:
            return json.load(f)
    return {"last_check": 0}


def save_state(state):
    with open(STATE_FILE, "w") as f:
        json.dump(state, f)


def run_mbsync():
    """Run mbsync to fetch new mail."""
    result = subprocess.run(
        ["mbsync", "gmail"],
        capture_output=True, text=True, timeout=300
    )
    return result.returncode == 0


def run_notmuch_new():
    """Index new mail with notmuch."""
    result = subprocess.run(
        ["notmuch", "new"],
        capture_output=True, text=True, timeout=120
    )
    return result.stdout.strip()


def get_new_emails(since_timestamp):
    """Query notmuch for emails newer than timestamp."""
    query = f"date:{since_timestamp}.. NOT from:{MY_EMAIL}"
    result = subprocess.run(
        ["notmuch", "search", "--format=json", "--output=summary", query],
        capture_output=True, text=True, timeout=60
    )
    if result.returncode != 0:
        return []
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return []


def get_sender_email(thread_id):
    """Get the actual sender email address from a thread."""
    result = subprocess.run(
        ["notmuch", "show", "--format=json", "--entire-thread=false", f"thread:{thread_id}"],
        capture_output=True, text=True, timeout=30
    )
    if result.returncode != 0:
        return None, None
    try:
        data = json.loads(result.stdout)
        if data and isinstance(data, list):
            msg = data[0]
            while isinstance(msg, list):
                msg = msg[0]
            if isinstance(msg, dict) and "headers" in msg:
                from_header = msg["headers"].get("From", "")
                if "<" in from_header and ">" in from_header:
                    email = from_header.split("<")[1].split(">")[0].lower()
                    name = from_header.split("<")[0].strip().strip('"')
                    return email, name
                return from_header.lower(), from_header
    except (json.JSONDecodeError, IndexError, KeyError):
        pass
    return None, None


def should_ignore(email):
    """Check if this email should be ignored."""
    if not email:
        return True
    email = email.lower()
    if email == MY_EMAIL:
        return True
    for pattern in IGNORE_PATTERNS:
        if pattern in email:
            return True
    return False


def is_known_person(email):
    """Check if this email belongs to someone in the relationships repo."""
    if not email or not PEOPLE_DIR.exists():
        return False
    result = subprocess.run(
        ["grep", "-rl", email.lower(), str(PEOPLE_DIR), "--include=*.md"],
        capture_output=True, text=True, timeout=30
    )
    return bool(result.stdout.strip())


def add_to_next_actions(subject, sender_name, sender_email, thread_id):
    """Add a new email notification to next-actions.json."""
    if not NEXT_ACTIONS.exists():
        return False

    with open(NEXT_ACTIONS) as f:
        data = json.load(f)

    # Check for duplicates
    action_id = f"mail-{thread_id[-6:]}"
    for action in data.get("actions", []):
        if action.get("id") == action_id:
            return False

    now = datetime.now(timezone.utc).isoformat()
    new_action = {
        "id": action_id,
        "text": f"Reply to {sender_name}: {subject}",
        "type": "pointer",
        "target": f"email:thread:{thread_id}",
        "context": f"From {sender_email}. Detected by check-mail.",
        "created": now,
        "completed": None,
    }

    data["actions"].insert(0, new_action)

    with open(NEXT_ACTIONS, "w") as f:
        json.dump(data, f, indent=2)

    return True


def send_signal_notification(message):
    """Send a Signal message notification (requires signal-cli configured)."""
    if not SIGNAL_ACCOUNT:
        return
    try:
        subprocess.run(
            ["signal-cli", "-a", SIGNAL_ACCOUNT, "send", "-m", message, SIGNAL_ACCOUNT],
            capture_output=True, text=True, timeout=30
        )
    except Exception:
        pass  # Best effort


def main():
    state = load_state()
    last_check = state.get("last_check", 0)

    # Run mbsync
    log("Running mbsync...")
    if not run_mbsync():
        log("mbsync failed, skipping")
        return 1

    # Index new mail
    notmuch_output = run_notmuch_new()
    if notmuch_output:
        log(f"notmuch: {notmuch_output}")

    # Calculate timestamp for query
    if last_check:
        since = datetime.fromtimestamp(last_check, tz=timezone.utc).strftime("%Y-%m-%d")
    else:
        # First run: only check last 24 hours
        since = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    # Get new emails
    emails = get_new_emails(since)
    log(f"Found {len(emails)} threads since {since}")

    vip_notifications = []
    actions_added = 0

    for thread in emails:
        thread_id = thread.get("thread", "")
        subject = thread.get("subject", "(no subject)")
        authors = thread.get("authors", "")
        timestamp = thread.get("timestamp", 0)

        if timestamp <= last_check:
            continue

        sender_email, sender_name = get_sender_email(thread_id)

        if should_ignore(sender_email):
            continue

        if not sender_name:
            sender_name = authors

        is_vip = sender_email and sender_email.lower() in VIP_EMAILS
        is_known = is_vip or is_known_person(sender_email)

        if is_vip:
            vip_notifications.append(f"{sender_name}: {subject}")
            add_to_next_actions(subject, sender_name, sender_email, thread_id)
            actions_added += 1
            log(f"  VIP: {sender_name} -- {subject}")
        elif is_known:
            add_to_next_actions(subject, sender_name, sender_email, thread_id)
            actions_added += 1
            log(f"  Known: {sender_name} -- {subject}")

    # Send Signal notification for VIPs
    if vip_notifications:
        msg = "New email from:\n" + "\n".join(f"  - {n}" for n in vip_notifications)
        send_signal_notification(msg)
        log(f"Signal notification sent ({len(vip_notifications)} VIP emails)")

    if actions_added:
        log(f"Added {actions_added} items to next-actions.json")

    # Update state
    state["last_check"] = int(datetime.now(timezone.utc).timestamp())
    save_state(state)

    return 0


def log(msg):
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {msg}")


if __name__ == "__main__":
    sys.exit(main())
