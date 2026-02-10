#!/usr/bin/env python3
"""Archive Console — personal command center for your digital life archive."""

import asyncio
import json
import os
import re
import shutil
import subprocess
import uuid
from datetime import datetime, timezone
from pathlib import Path

from fastapi import FastAPI, Request, Response, HTTPException, Form, Query
from fastapi.responses import HTMLResponse, RedirectResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

try:
    import anthropic
    ANTHROPIC_AVAILABLE = True
except ImportError:
    ANTHROPIC_AVAILABLE = False

APP_DIR = Path(__file__).parent
ARCHIVE_DIR = APP_DIR.parent
ACTIONS_FILE = ARCHIVE_DIR / "coordination" / "next-actions.json"
TRIAGE_FILE = ARCHIVE_DIR / "docs" / "communication-triage.json"
TOKEN_FILE = APP_DIR / "auth_token"
AUTH_TOKEN = TOKEN_FILE.read_text().strip()
COOKIE_NAME = "archive_session"

# Background task storage
TASKS: dict[str, dict] = {}

app = FastAPI(title="Archive Console", docs_url=None, redoc_url=None)
app.mount("/static", StaticFiles(directory=APP_DIR / "static"), name="static")


def check_auth(request: Request) -> bool:
    token = request.cookies.get(COOKIE_NAME)
    if token == AUTH_TOKEN:
        return True
    auth = request.headers.get("Authorization", "")
    if auth == f"Bearer {AUTH_TOKEN}":
        return True
    q = request.query_params.get("token")
    if q == AUTH_TOKEN:
        return True
    return False


def require_auth(request: Request):
    if not check_auth(request):
        raise HTTPException(status_code=401, detail="Unauthorized")


def run_cmd(cmd: list[str], timeout: int = 10) -> str:
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.stdout + r.stderr
    except subprocess.TimeoutExpired:
        return "(timed out)"
    except FileNotFoundError:
        return f"(command not found: {cmd[0]})"


def git_commit_push(files: list[str], message: str):
    """Git add, commit, and push specified files."""
    try:
        for f in files:
            subprocess.run(["git", "add", f], cwd=str(ARCHIVE_DIR),
                           timeout=10, capture_output=True)
        subprocess.run(["git", "commit", "-m", message], cwd=str(ARCHIVE_DIR),
                       timeout=15, capture_output=True)
        subprocess.run(["git", "push"], cwd=str(ARCHIVE_DIR),
                       timeout=30, capture_output=True)
    except Exception:
        pass


def load_actions() -> dict:
    """Load next-actions.json."""
    if ACTIONS_FILE.exists():
        return json.loads(ACTIONS_FILE.read_text())
    return {"actions": []}


def save_actions(data: dict, message: str = "Update next-actions"):
    """Save next-actions.json and git commit+push."""
    ACTIONS_FILE.write_text(json.dumps(data, indent=2) + "\n")
    git_commit_push([str(ACTIONS_FILE)], message)


# --- Auth ---

@app.get("/login", response_class=HTMLResponse)
async def login_page():
    return """<!DOCTYPE html><html><head><title>Archive Console</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <style>body{font-family:monospace;background:#0a0a0a;color:#e0e0e0;display:flex;
    justify-content:center;align-items:center;min-height:100vh;margin:0}
    form{background:#1a1a1a;padding:2rem;border-radius:8px;border:1px solid #333}
    input{background:#0a0a0a;color:#e0e0e0;border:1px solid #444;padding:0.8rem;
    font-family:monospace;font-size:1rem;width:100%;box-sizing:border-box;margin:0.5rem 0}
    button{background:#2d5a27;color:#e0e0e0;border:none;padding:0.8rem 2rem;
    font-family:monospace;font-size:1rem;cursor:pointer;width:100%;margin-top:0.5rem}
    button:hover{background:#3a7a33} h2{margin-top:0;color:#7fba6a}</style></head>
    <body><form method="POST" action="/login">
    <h2>archive</h2>
    <input type="password" name="token" placeholder="access token" autofocus>
    <button type="submit">enter</button></form></body></html>"""


@app.post("/login")
async def login_submit(token: str = Form(...)):
    if token != AUTH_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid token")
    response = RedirectResponse(url="/", status_code=303)
    response.set_cookie(COOKIE_NAME, token, httponly=True, samesite="strict", max_age=86400 * 30)
    return response


# --- Dashboard ---

@app.get("/", response_class=HTMLResponse)
async def dashboard(request: Request):
    if not check_auth(request):
        return RedirectResponse(url="/login")
    return (APP_DIR / "static" / "index.html").read_text()


# --- API: Status ---

@app.get("/api/status")
async def api_status(request: Request):
    require_auth(request)

    total, used, free = shutil.disk_usage(str(ARCHIVE_DIR))

    def dir_size_fast(path: str) -> str:
        r = run_cmd(["du", "-sh", path], timeout=5)
        return r.split("\t")[0].strip() if "\t" in r else "?"

    rclone_procs = run_cmd(["pgrep", "-ac", "rclone"])
    mbsync_procs = run_cmd(["pgrep", "-ac", "mbsync"])

    sync_status_file = ARCHIVE_DIR / "sync-status.json"
    sync_status = None
    if sync_status_file.exists():
        try:
            sync_status = json.loads(sync_status_file.read_text())
        except Exception:
            pass

    mail_count = run_cmd(["notmuch", "count"], timeout=5).strip()

    # Backup and sync log status
    def log_status(log_path: str) -> dict:
        """Get last run time and status from a log file."""
        p = Path(log_path)
        if not p.exists() or p.stat().st_size == 0:
            return {"status": "never", "last_line": "", "age_hours": None}
        try:
            lines = p.read_text().strip().split("\n")
            last_line = lines[-1] if lines else ""
            mtime = p.stat().st_mtime
            age_hours = round((datetime.now().timestamp() - mtime) / 3600, 1)
            has_error = any("ERROR" in l for l in lines[-20:])
            return {
                "status": "error" if has_error else "ok",
                "last_line": last_line[-120:],
                "age_hours": age_hours,
                "lines": len(lines),
            }
        except Exception:
            return {"status": "unknown", "last_line": "", "age_hours": None}

    # Adjust these log paths to match your cron setup
    backup_log = log_status("/var/log/archive-backup.log")
    sync_log = log_status("/var/log/archive-sync.log")
    checkmail_log = log_status("/var/log/archive-checkmail.log")

    # B2 backup size
    b2_size = run_cmd(["rclone", "size", "b2:", "--json"], timeout=15)
    try:
        b2_info = json.loads(b2_size)
        b2_gb = round(b2_info.get("bytes", 0) / 1e9, 2)
        b2_objects = b2_info.get("count", 0)
    except Exception:
        b2_gb = None
        b2_objects = None

    # Active sessions
    sessions = []
    session_dir = ARCHIVE_DIR / "coordination"
    if session_dir.exists():
        for f in sorted(session_dir.glob("SESSION_*.md"), reverse=True)[:5]:
            try:
                content = f.read_text()
                status = "ACTIVE"
                if "STATUS: COMPLETE" in content:
                    status = "COMPLETE"
                lines = content.strip().split("\n")
                title = lines[0].replace("# ", "") if lines else f.stem
                sessions.append({"file": f.name, "title": title, "status": status})
            except Exception:
                pass

    # Queued tasks
    queued = []
    queue_dir = ARCHIVE_DIR / "coordination" / "queued"
    if queue_dir.exists():
        for f in sorted(queue_dir.glob("*.md")):
            if f.name == "README.md":
                continue
            try:
                content = f.read_text()
                priority = "medium"
                status = "queued"
                for line in content.split("\n")[:10]:
                    if "PRIORITY:" in line.upper():
                        priority = line.split(":")[-1].strip().lower()
                    if "STATUS:" in line.upper():
                        status = line.split(":")[-1].strip().lower()
                queued.append({"file": f.stem, "priority": priority, "status": status})
            except Exception:
                pass

    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "disk": {
            "total_gb": round(total / 1e9, 1),
            "used_gb": round(used / 1e9, 1),
            "free_gb": round(free / 1e9, 1),
            "pct": round(used / total * 100, 1),
        },
        "processes": {
            "rclone": int(rclone_procs.strip()) if rclone_procs.strip().isdigit() else 0,
            "mbsync": int(mbsync_procs.strip()) if mbsync_procs.strip().isdigit() else 0,
        },
        "sync_status": sync_status,
        "email_count": mail_count,
        "data_sizes": {
            "dropbox": dir_size_fast(str(ARCHIVE_DIR / "cloud" / "dropbox")),
            "gdrive": dir_size_fast(str(ARCHIVE_DIR / "cloud" / "google-drive")),
            "email": dir_size_fast(os.path.expanduser("~/Mail/gmail")),
        },
        "sessions": sessions,
        "queued_tasks": queued,
        "logs": {
            "backup": backup_log,
            "sync": sync_log,
            "checkmail": checkmail_log,
        },
        "b2_backup": {
            "size_gb": b2_gb,
            "objects": b2_objects,
        },
    }


# --- API: Next Actions ---

@app.get("/api/actions")
async def get_actions(request: Request, include_completed: bool = Query(False)):
    """Return ordered list of actions."""
    require_auth(request)
    data = load_actions()
    if not include_completed:
        data["actions"] = [a for a in data["actions"] if a.get("completed") is None]
    return data


@app.post("/api/actions")
async def add_action(request: Request):
    """Add a new action."""
    require_auth(request)
    body = await request.json()
    text = body.get("text", "").strip()
    if not text:
        raise HTTPException(status_code=400, detail="text is required")

    action = {
        "id": uuid.uuid4().hex[:6],
        "text": text,
        "type": body.get("type", "action"),
        "target": body.get("target"),
        "context": body.get("context", ""),
        "created": datetime.now(timezone.utc).isoformat(),
        "completed": None,
    }
    data = load_actions()
    data["actions"].append(action)
    save_actions(data, f"Add action: {text[:50]}")
    return action


@app.put("/api/actions/{action_id}")
async def update_action(request: Request, action_id: str):
    """Update an action's text/context or mark complete."""
    require_auth(request)
    body = await request.json()
    data = load_actions()

    for action in data["actions"]:
        if action["id"] == action_id:
            if "text" in body:
                action["text"] = body["text"]
            if "context" in body:
                action["context"] = body["context"]
            if "completed" in body:
                action["completed"] = body["completed"]
            save_actions(data, f"Update action: {action['text'][:50]}")
            return action

    raise HTTPException(status_code=404, detail="Action not found")


@app.delete("/api/actions/{action_id}")
async def delete_action(request: Request, action_id: str):
    """Remove an action."""
    require_auth(request)
    data = load_actions()
    original_len = len(data["actions"])
    data["actions"] = [a for a in data["actions"] if a["id"] != action_id]
    if len(data["actions"]) == original_len:
        raise HTTPException(status_code=404, detail="Action not found")
    save_actions(data, f"Remove action {action_id}")
    return {"status": "deleted"}


@app.post("/api/actions/reorder")
async def reorder_actions(request: Request):
    """Set new order. Body: {"order": ["id1","id2","id3"]}"""
    require_auth(request)
    body = await request.json()
    order = body.get("order", [])
    if not order:
        raise HTTPException(status_code=400, detail="order is required")

    data = load_actions()
    by_id = {a["id"]: a for a in data["actions"]}
    reordered = []
    for aid in order:
        if aid in by_id:
            reordered.append(by_id.pop(aid))
    reordered.extend(by_id.values())
    data["actions"] = reordered
    save_actions(data, "Reorder actions")
    return data


# --- API: Triage ---

def load_triage() -> dict:
    """Load communication-triage.json."""
    if TRIAGE_FILE.exists():
        try:
            return json.loads(TRIAGE_FILE.read_text())
        except Exception:
            pass
    return {"generated": None, "items": []}


@app.get("/api/triage")
async def api_triage(request: Request):
    """Return structured communication triage data."""
    require_auth(request)
    return load_triage()


@app.post("/api/triage/refresh")
async def refresh_triage(request: Request):
    """Run triage script in background."""
    require_auth(request)
    script = ARCHIVE_DIR / "scripts" / "triage-email.py"
    if not script.exists():
        raise HTTPException(status_code=404, detail="Triage script not found")
    venv_python = ARCHIVE_DIR / ".venv" / "bin" / "python"
    python_bin = str(venv_python) if venv_python.exists() else "python3"
    log_file = Path("/tmp/archive-triage.log")
    cmd = f"{python_bin} {script} > {log_file} 2>&1"
    subprocess.Popen(["bash", "-c", cmd], start_new_session=True,
                     cwd=str(ARCHIVE_DIR))
    return {"status": "started", "log": str(log_file)}


@app.put("/api/triage/{item_id}/status")
async def update_triage_status(request: Request, item_id: str):
    """Update a triage item's status."""
    require_auth(request)
    body = await request.json()
    new_status = body.get("status")
    valid = {"needs-response", "replied", "waiting", "snoozed", "archived", "to-read", "read"}
    if new_status not in valid:
        raise HTTPException(status_code=400, detail=f"status must be one of: {valid}")

    data = load_triage()
    for item in data.get("items", []):
        if item["id"] == item_id:
            item["status"] = new_status
            TRIAGE_FILE.write_text(json.dumps(data, indent=2) + "\n")
            git_commit_push([str(TRIAGE_FILE)], f"Triage: mark {item_id} as {new_status}")
            return item

    raise HTTPException(status_code=404, detail="Triage item not found")


@app.post("/api/triage/{item_id}/draft-reply")
async def draft_reply(request: Request, item_id: str):
    """Generate a draft reply using Claude API with relationship context."""
    require_auth(request)

    if not ANTHROPIC_AVAILABLE:
        raise HTTPException(status_code=503, detail="anthropic package not installed")

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise HTTPException(status_code=503, detail="ANTHROPIC_API_KEY not set")

    data = load_triage()
    item = None
    for i in data.get("items", []):
        if i["id"] == item_id:
            item = i
            break
    if not item:
        raise HTTPException(status_code=404, detail="Triage item not found")

    thread_id = item.get("thread_id", "")
    if not thread_id:
        raise HTTPException(status_code=400, detail="No thread_id in triage item")

    email_output = run_cmd(["notmuch", "show", "--format=json", f"thread:{thread_id}"], timeout=30)
    try:
        email_thread = json.loads(email_output)
    except Exception:
        email_thread = []

    relationship_slug = item.get("relationship_slug")
    relationship_context = ""
    if relationship_slug:
        rel_path = ARCHIVE_DIR / "private" / "relationships" / "people" / relationship_slug / "README.md"
        if rel_path.exists():
            relationship_context = rel_path.read_text()

    from_name = item.get("from_name", "Unknown")
    from_email = item.get("from_email", "")
    subject = item.get("subject", "")
    summary = item.get("summary", "")

    prompt = f"""You are helping draft a reply to an email. Use the context below to write a warm, personal response.

**From:** {from_name} <{from_email}>
**Subject:** {subject}
**Thread summary:** {summary}

**Relationship context:**
{relationship_context if relationship_context else "No relationship context available."}

**Full email thread:**
{json.dumps(email_thread, indent=2)}

Draft a reply that:
- Is warm and personal
- References specific things from the thread
- Uses the relationship context appropriately
- Keeps it concise (2-4 paragraphs unless more depth is warranted)
- Signs off appropriately for the relationship level

Output ONLY the draft email body, no meta-commentary."""

    try:
        client = anthropic.Anthropic(api_key=api_key)
        message = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1500,
            messages=[{"role": "user", "content": prompt}]
        )
        draft = message.content[0].text

        return {
            "draft": draft,
            "context_used": {
                "has_relationship": bool(relationship_context),
                "relationship_slug": relationship_slug,
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Claude API error: {str(e)}")


# --- API: Email ---

# Domains/patterns to filter out of "recent" view
SPAM_PATTERNS = [
    "noreply@", "no-reply@", "notifications@", "mailer-daemon@",
    "donotreply@", "updates@", "news@", "newsletter@", "marketing@",
    "bounce", "daemon",
]
SPAM_DOMAINS = [
    "github.com", "linkedin.com", "substack.com", "stripe.com",
    "google.com", "googlemail.com", "facebookmail.com", "twitter.com",
    "amazonses.com", "sendgrid.net", "mailchimp.com", "constantcontact.com",
]


def is_automated_email(authors: str, subject: str) -> bool:
    """Check if an email is likely automated/spam."""
    authors_lower = authors.lower()
    for p in SPAM_PATTERNS:
        if p in authors_lower:
            return True
    for d in SPAM_DOMAINS:
        if d in authors_lower:
            return True
    return False


@app.get("/api/email/recent")
async def recent_email(request: Request, limit: int = Query(30)):
    """Return recent non-automated emails."""
    require_auth(request)
    fetch_limit = limit * 4
    output = run_cmd(
        ["notmuch", "search", f"--limit={fetch_limit}", "--format=json",
         "--sort=newest-first", "tag:inbox"],
        timeout=15
    )
    try:
        all_results = json.loads(output)
    except Exception:
        all_results = []

    filtered = []
    for m in all_results:
        authors = m.get("authors", "")
        subject = m.get("subject", "")
        if is_automated_email(authors, subject):
            continue
        filtered.append(m)
        if len(filtered) >= limit:
            break

    return {"results": filtered, "count": len(filtered)}


@app.get("/api/search/email")
async def search_email(request: Request, q: str = Query(..., min_length=1)):
    require_auth(request)
    output = run_cmd(["notmuch", "search", "--limit=50", "--format=json", q], timeout=15)
    try:
        results = json.loads(output)
    except Exception:
        results = []
    return {"query": q, "results": results}


@app.get("/api/email/{thread_id}")
async def read_email(request: Request, thread_id: str):
    """Return parsed email thread with proper message structure."""
    require_auth(request)
    output = run_cmd(["notmuch", "show", "--format=json", "--entire-thread=true",
                       f"thread:{thread_id}"], timeout=15)
    try:
        raw = json.loads(output)
    except Exception:
        return {"thread_id": thread_id, "messages": [], "raw_error": output[:500]}

    messages = []

    def extract_messages(obj):
        if isinstance(obj, dict):
            if "headers" in obj and "body" in obj:
                headers = obj.get("headers", {})
                body_parts = []
                extract_body(obj.get("body", []), body_parts)
                messages.append({
                    "id": obj.get("id", ""),
                    "from": headers.get("From", ""),
                    "to": headers.get("To", ""),
                    "cc": headers.get("Cc", ""),
                    "subject": headers.get("Subject", ""),
                    "date": headers.get("Date", ""),
                    "body": "\n".join(body_parts) if body_parts else "(no text content)",
                    "tags": obj.get("tags", []),
                })
            else:
                for v in obj.values():
                    extract_messages(v)
        elif isinstance(obj, list):
            for item in obj:
                extract_messages(item)

    def extract_body(body, parts):
        if isinstance(body, dict):
            ct = body.get("content-type", "")
            content = body.get("content", "")
            if ct == "text/plain" and isinstance(content, str):
                parts.append(content)
            elif isinstance(content, list):
                for item in content:
                    extract_body(item, parts)
        elif isinstance(body, list):
            for item in body:
                extract_body(item, parts)

    extract_messages(raw)
    return {"thread_id": thread_id, "messages": messages}


@app.post("/api/email/send")
async def send_email(request: Request, to: str = Form(...), subject: str = Form(...),
                      body: str = Form(...)):
    require_auth(request)
    cmd = ["neomutt", "-s", subject, "--", to]
    try:
        r = subprocess.run(cmd, input=body, capture_output=True, text=True, timeout=30)
        if r.returncode == 0:
            return {"status": "sent", "to": to, "subject": subject}
        else:
            return {"status": "error", "detail": r.stderr}
    except Exception as e:
        return {"status": "error", "detail": str(e)}


# --- API: Queue ---

@app.get("/api/queue")
async def get_queue(request: Request):
    """Return queued tasks with their full content."""
    require_auth(request)
    queue_dir = ARCHIVE_DIR / "coordination" / "queued"
    tasks = []
    if queue_dir.exists():
        for f in sorted(queue_dir.glob("*.md")):
            if f.name == "README.md":
                continue
            try:
                content = f.read_text()
                priority = "medium"
                status = "queued"
                title = f.stem.replace("-", " ").title()
                for line in content.split("\n")[:15]:
                    if line.startswith("# Task:"):
                        title = line.replace("# Task:", "").strip()
                    elif "PRIORITY:" in line.upper():
                        priority = line.split(":")[-1].strip().lower()
                    elif "STATUS:" in line.upper():
                        status = line.split(":")[-1].strip().lower()
                tasks.append({
                    "file": f.stem, "title": title,
                    "priority": priority, "status": status, "content": content,
                })
            except Exception:
                pass
    order = {"high": 0, "medium": 1, "low": 2}
    tasks.sort(key=lambda t: order.get(t["priority"], 1))
    return {"tasks": tasks}


# --- API: Files ---

@app.get("/api/files")
async def list_files(request: Request, path: str = Query("", alias="path")):
    require_auth(request)
    base = ARCHIVE_DIR
    target = (base / path).resolve()
    if not str(target).startswith(str(base)):
        raise HTTPException(status_code=403, detail="Access denied")
    if not target.exists():
        raise HTTPException(status_code=404, detail="Not found")
    if target.is_file():
        content = None
        size = target.stat().st_size
        if size < 100_000:
            try:
                content = target.read_text(errors="replace")
            except Exception:
                content = "(binary file)"
        return {"type": "file", "path": path, "size": size, "content": content}
    entries = []
    try:
        for item in sorted(target.iterdir()):
            if item.name.startswith("."):
                continue
            entries.append({
                "name": item.name,
                "is_dir": item.is_dir(),
                "size": item.stat().st_size if item.is_file() else None,
            })
    except PermissionError:
        pass
    return {"type": "directory", "path": path, "entries": entries}


@app.post("/api/files/save")
async def save_file(request: Request, path: str = Form(...), content: str = Form(...),
                    message: str = Form("")):
    """Save a file and git commit."""
    require_auth(request)
    base = ARCHIVE_DIR
    target = (base / path).resolve()
    if not str(target).startswith(str(base)):
        raise HTTPException(status_code=403, detail="Access denied")
    if not target.exists():
        raise HTTPException(status_code=404, detail="File not found")
    if target.is_dir():
        raise HTTPException(status_code=400, detail="Cannot save to a directory")
    target.write_text(content)
    commit_msg = message.strip() or f"Edit {path} via console"
    try:
        subprocess.run(["git", "add", str(target)], cwd=str(base), timeout=10, capture_output=True)
        subprocess.run(["git", "commit", "-m", commit_msg], cwd=str(base), timeout=15, capture_output=True)
        subprocess.run(["git", "push"], cwd=str(base), timeout=30, capture_output=True)
    except Exception:
        pass
    return {"status": "saved", "path": path}


@app.get("/api/search/files")
async def search_files(request: Request, q: str = Query(..., min_length=1)):
    require_auth(request)
    output = run_cmd(["grep", "-rl", "--include=*.md", "--include=*.txt", "--include=*.json",
                       "-i", q, str(ARCHIVE_DIR)], timeout=15)
    files = [f.replace(str(ARCHIVE_DIR) + "/", "") for f in output.strip().split("\n") if f]
    return {"query": q, "files": files[:50]}


# --- API: Contacts ---

@app.get("/api/contacts")
async def search_contacts(request: Request, q: str = Query("", min_length=0)):
    """Search the relationships repo for people."""
    require_auth(request)
    people_dir = ARCHIVE_DIR / "private" / "relationships" / "people"
    contacts = []
    if people_dir.exists():
        for d in sorted(people_dir.iterdir()):
            if not d.is_dir():
                continue
            name = d.name.replace("-", " ").title()
            if q and q.lower() not in name.lower():
                continue
            readme = d / "README.md"
            context = ""
            if readme.exists():
                try:
                    for line in readme.read_text().split("\n"):
                        if "**Context:**" in line:
                            context = line.split("**Context:**")[-1].strip()
                            break
                except Exception:
                    pass
            contacts.append({"slug": d.name, "name": name, "context": context})
    return {"contacts": contacts}


@app.get("/api/contacts/{slug}")
async def get_contact(request: Request, slug: str):
    require_auth(request)
    readme = ARCHIVE_DIR / "private" / "relationships" / "people" / slug / "README.md"
    if not readme.exists():
        raise HTTPException(status_code=404, detail="Contact not found")
    return {"slug": slug, "content": readme.read_text()}


# --- API: People & Ideas Indexes ---

@app.get("/api/people/index")
async def get_people_index(request: Request):
    """Return the relationships INDEX.md content."""
    require_auth(request)
    index_file = ARCHIVE_DIR / "private" / "relationships" / "INDEX.md"
    if not index_file.exists():
        raise HTTPException(status_code=404, detail="People index not found")
    return {"content": index_file.read_text()}


@app.get("/api/ideas/index")
async def get_ideas_index(request: Request):
    """Return the idea-index INDEX.md content."""
    require_auth(request)
    index_file = ARCHIVE_DIR / "private" / "idea-index" / "INDEX.md"
    if not index_file.exists():
        raise HTTPException(status_code=404, detail="Ideas index not found")
    return {"content": index_file.read_text()}


@app.get("/api/ideas/{path:path}")
async def get_idea(request: Request, path: str):
    """Get full details for a single idea."""
    require_auth(request)
    readme = ARCHIVE_DIR / "private" / "idea-index" / "ideas" / path / "README.md"
    if not readme.exists():
        raise HTTPException(status_code=404, detail="Idea not found")
    return {"path": path, "content": readme.read_text()}


# --- API: Notifications ---

NOTIFICATION_STATE_FILE = APP_DIR / ".notification-state.json"


def load_notification_state() -> dict:
    if NOTIFICATION_STATE_FILE.exists():
        try:
            return json.loads(NOTIFICATION_STATE_FILE.read_text())
        except Exception:
            pass
    return {"last_seen": None}


def save_notification_state(state: dict):
    NOTIFICATION_STATE_FILE.write_text(json.dumps(state))


@app.get("/api/notifications")
async def get_notifications(request: Request):
    """Return new next-actions items since last check."""
    require_auth(request)

    state = load_notification_state()
    last_seen = state.get("last_seen")

    data = load_actions()
    new_items = []

    for action in data.get("actions", []):
        if action.get("completed"):
            continue
        created = action.get("created", "")
        if last_seen and created <= last_seen:
            continue
        new_items.append({
            "id": action["id"],
            "text": action["text"],
            "context": action.get("context", ""),
            "created": created,
        })

    return {"new_items": new_items, "count": len(new_items)}


@app.post("/api/notifications/mark-seen")
async def mark_notifications_seen(request: Request):
    """Mark all current notifications as seen."""
    require_auth(request)
    now = datetime.now(timezone.utc).isoformat()
    save_notification_state({"last_seen": now})
    return {"status": "ok", "last_seen": now}


if __name__ == "__main__":
    import uvicorn

    # CHANGE THIS to your Tailscale IP (run: tailscale ip -4)
    TAILSCALE_IP = "YOUR_TAILSCALE_IP"

    cert_dir = APP_DIR / "certs"

    uvicorn.run(
        app,
        host=TAILSCALE_IP,
        port=8443,
        ssl_keyfile=str(cert_dir / "key.pem"),
        ssl_certfile=str(cert_dir / "cert.pem"),
    )
