#!/usr/bin/env python3
"""model-switch-log.py — record when a session's model changes under it (DRAFT, v0.8.9).

WHY. An unattended worker can be moved to another model without anyone watching — a fallback when
the requested model is unavailable or rate-limited, a switch mid-session. The work then runs on a
model nobody chose, and nothing reports it. This hook appends one line per switch so
/close-session, /close-day and the App can say so.

FORMAT (the shape readers build against): ~/.aios/model-switch.jsonl, one JSON object per line:

    {"at": "2026-10-11T21:40:00Z", "session_id": "<id>", "name": "<registry name or empty>",
     "from": "<model id or empty>", "to": "<model id>", "reason": "<string or empty>"}

  - `at` is UTC, ISO 8601, written by this hook (never taken from the payload).
  - `name` is the session's registry name from ~/.claude/sessions/*.json, empty when unnamed.
  - Unknown values are empty strings, never omitted keys, so readers can index every field.

CONFIRM when built: the PostModelSwitch payload's field names. This draft reads the likely names
and falls back to empty; it never raises, and it exits 0 always (a log must not break a session).
Wired in SETUP §10 once the payload is confirmed.
"""
import datetime
import glob
import json
import os
import sys

LOG = os.environ.get("AIOS_MODEL_SWITCH_LOG") or os.path.expanduser("~/.aios/model-switch.jsonl")


def pick(d, *keys):
    for k in keys:
        v = d.get(k)
        if isinstance(v, str) and v:
            return v
        if isinstance(v, dict):
            v = v.get("id") or v.get("model")
            if isinstance(v, str) and v:
                return v
    return ""


def registry_name(session_id):
    cfg = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
    for f in glob.glob(os.path.join(cfg, "sessions", "*.json")):
        try:
            d = json.load(open(f, encoding="utf-8"))
        except Exception:
            continue
        if d.get("sessionId") == session_id:
            return d.get("name") or ""
    return ""


def main():
    try:
        d = json.load(sys.stdin)
        sid = pick(d, "session_id", "sessionId")
        row = {
            "at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "session_id": sid,
            "name": registry_name(sid) if sid else "",
            "from": pick(d, "from_model", "previous_model", "old_model", "from"),
            "to": pick(d, "to_model", "new_model", "model", "to"),
            "reason": pick(d, "reason", "trigger", "source"),
        }
        os.makedirs(os.path.dirname(LOG), exist_ok=True)
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(json.dumps(row) + "\n")
    except Exception:
        pass
    sys.exit(0)


if __name__ == "__main__":
    main()
