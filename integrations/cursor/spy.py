#!/usr/bin/env python3
"""Claude Lights — Cursor discovery spy (2026-09-10).

Mirrors hooks/state.py's original Fase 0 spy for Claude Code: logs every
event verbatim, decides nothing, changes no state, plays no sound. Exists
because Cursor's own hooks docs (cursor.com/docs/hooks) leave real open
questions this project's own history says not to guess past:
  - No dedicated "PermissionRequest" event — permission is a RESPONSE VALUE
    a hook can attach to preToolUse/beforeShellExecution/etc
    ("permission": "ask"), not something Cursor tells hooks is happening.
    Unclear whether Cursor's own separate trust/approval system (independent
    of what THIS hook decides) ever surfaces to an observing hook at all.
  - No multi-option "ask a question" mechanism exists in Cursor at all
    (confirmed from docs, not just unverified) — only binary allow/deny/ask.
  - postToolUseFailure fires per tool call, not per turn; unclear whether
    that should map to our "error" state (StopFailure's equivalent) or is
    just a recoverable blip the agent continues past.

CRITICAL DIFFERENCE from Claude Code: Cursor hooks are SYNCHRONOUS and
BLOCKING by default — the agent loop waits for this script before
continuing (up to hooks.json's "timeout"). This script must stay fast and
must always print a harmless JSON response and exit 0, or it could visibly
slow down or interfere with the user's actual Cursor session. Never denies,
never asks — pure observation.

Not installed automatically, not wired into the real app in any way yet.
Run integrations/cursor/install.sh only on a machine that actually has
Cursor, use Cursor normally for a while (including something that would
normally trigger an approval dialog), then read the log before writing any
real state-detection logic — same discipline as docs/DISCOVERY.md.
"""
import json
import os
import sys
from datetime import datetime, timezone

STATUS_DIR = os.path.expanduser("~/.claude/claude-status")
LOG_FILE = os.path.join(STATUS_DIR, "cursor-events.log")
LOG_MAX_LINES = 2000
MAX_FIELD_LEN = 500  # truncate long fields (file contents, tool output) — keep the log small


def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def truncate(obj):
    if isinstance(obj, str) and len(obj) > MAX_FIELD_LEN:
        return obj[:MAX_FIELD_LEN] + f"...(+{len(obj) - MAX_FIELD_LEN} chars)"
    if isinstance(obj, dict):
        return {k: truncate(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [truncate(v) for v in obj[:20]]
    return obj


def log_event(data):
    try:
        os.makedirs(STATUS_DIR, exist_ok=True)
        data["_ts"] = now_iso()
        with open(LOG_FILE, "a") as f:
            f.write(json.dumps(truncate(data), ensure_ascii=False) + "\n")
        with open(LOG_FILE) as f:
            lines = f.readlines()
        if len(lines) > LOG_MAX_LINES:
            with open(LOG_FILE, "w") as f:
                f.writelines(lines[-LOG_MAX_LINES:])
    except Exception:
        pass  # never let logging itself break the hook response


def main():
    raw = sys.stdin.read()
    try:
        data = json.loads(raw)
    except Exception:
        data = {"_parse_error": True, "_raw": raw[:MAX_FIELD_LEN]}

    log_event(data)

    # Always allow, always fast, always valid JSON — this hook only watches.
    print("{}")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # Even on an unexpected crash, still respond so Cursor never blocks
        # on us or treats a bug here as a denial.
        print("{}")
