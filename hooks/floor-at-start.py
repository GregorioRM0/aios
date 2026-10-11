#!/usr/bin/env python3
"""floor-at-start.py — SessionStart hook: the context floor is DELIVERED, not chosen.

WHY. CLAUDE.md tells every session to run the context floor first. Measured across one vault's
transcripts (2026-10-03 -> 10-11), that instruction alone did not deliver it: 5 of 16 named
sessions never ran it, most of the rest piped or redirected the output and worked from the
1.5 KB map as if it were the floor, and only a few read the floor file to its end. A rule each
session must remember to follow is the weakest kind; the harness can do it instead.

WHAT. At session start (and after /clear or a compaction, when the context is gone) this hook
writes the full floor file exactly as `context-floor.py` does, and hands the session a COMPACT
floor as additionalContext:

    1. INTENT.md, whole            -- the trust contract: what the session may do without asking
    2. the titles of the newest entries of every observed file -- what was learned lately
    3. the map                     -- every section of the full floor file, with its path

The full file stays where the map says, for depth. Measured budget on a heavy vault: ~33 KB,
about 8,200 tokens, once per new interactive session (cached across its turns), against ~47,000
for the whole floor. INTENT ships whole rather than "rule sections" picked by heading: headings
vary per vault, and INTENT is the one file that governs what a session may do.

WHO. The floor exists so every session starts with the highest intelligence -- the right
information at the right time -- so the default is delivery, not opt-in:
  - every INTERACTIVE session (CLAUDE_CODE_ENTRYPOINT=cli), named or not, including workers
    another session spawned through the inbox -> the compact floor
  - ROUTINES (CLAUDE_CODE_ENTRYPOINT=sdk-*: headless `claude -p` and the SDKs) -> INTENT.md
    alone, about 6,700 tokens: they commit and send with nobody watching, so the trust contract
    is the one thing they must carry; titles and the map are for a session that can go look
  - AIOS_FLOOR_AT_START=0 opts any session out (a worker that truly needs nothing);
    AIOS_FLOOR_AT_START=1 gives any session the compact floor
  - source "resume": nothing -- the resumed transcript already holds what was delivered

Exit 0 always and print nothing on any failure: a context hook must never stop a session from
starting. Wired per SETUP §10 Hook E. Guarded by tests/floor-at-start.test.sh.
"""
import json
import os
import re
import subprocess
import sys

for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        try:
            _stream.reconfigure(encoding="utf-8", errors="replace")
        except (ValueError, OSError):
            pass

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("AIOS_ROOT") or os.path.dirname(HERE)
FLOOR = os.path.join(HERE, "context-floor.py")
MAX_BYTES = 60 * 1024  # a ceiling, not the budget: past it, deliver the map and pointer only


def mode(data, env):
    """'compact', 'intent' or None -- what this session receives."""
    flag = env.get("AIOS_FLOOR_AT_START", "")
    if flag == "0":
        return None
    if flag == "1":
        return "compact"
    if (data.get("source") or "") == "resume":
        return None
    if (env.get("CLAUDE_CODE_ENTRYPOINT") or "").startswith("sdk"):
        return "intent"
    return "compact"


def intent_text(root):
    try:
        return open(os.path.join(root, "INTENT.md"), encoding="utf-8").read().strip()
    except OSError:
        return "(no INTENT.md in this vault -- assume nothing is pre-authorised)"


def compact(root, session_id):
    env = dict(os.environ)
    if session_id:
        env["CLAUDE_CODE_SESSION_ID"] = session_id
    run = subprocess.run([sys.executable, FLOOR, root], capture_output=True, text=True,
                         encoding="utf-8", errors="replace", timeout=60, env=env)
    if run.returncode != 0 or not run.stdout.strip():
        return None
    the_map = run.stdout.strip()
    m = re.search(r"NEXT: Read (.+?) in parts", the_map)
    floor_path = m.group(1) if m else ""

    sys.path.insert(0, HERE)
    import importlib.util
    spec = importlib.util.spec_from_file_location("context_floor", FLOOR)
    cf = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(cf)
    base = os.path.join(root, "vault", "00 - notes", "context")
    obs = cf.folder(base, "observed") or []
    titles = []
    for fn, lines in obs:
        if cf.is_restated(lines):
            continue
        es, is_lib, _ = cf.recent_slice(lines, cf.DEFAULT_RECENT)
        if is_lib:
            continue
        for block in cf.newest(es, cf.DEFAULT_RECENT):
            titles.append("  %s: %s" % (fn, block[0].lstrip("#").strip()))

    intent = intent_text(root)

    out = ["CONTEXT FLOOR (compact, delivered at session start by hooks/floor-at-start.py)",
           "",
           "== 1. INTENT.md -- the trust contract: what you may do without asking ==",
           intent,
           "",
           "== 2. What was learned lately -- the newest entries of each observed file (titles) ==",
           "Open an entry in its file when the task touches it; the full floor file below has their bodies.",
           *titles,
           "",
           "== 3. The full floor, for depth ==",
           the_map.replace("THIS IS ONLY THE MAP -- THE CONTEXT FLOOR IS NOT LOADED YET.",
                           "The compact floor above is loaded; the full floor is here for depth.")]
    text = "\n".join(out)
    if len(text.encode("utf-8")) > MAX_BYTES:
        text = ("CONTEXT FLOOR: too large to deliver compactly in this vault (%d KB). Read the full "
                "floor file to its END line before acting: %s" % (len(text.encode("utf-8")) // 1024, floor_path))
    return text


def main():
    try:
        try:
            data = json.load(sys.stdin)
        except ValueError:
            data = {}
        m = mode(data, os.environ)
        if m is None:
            return
        if m == "intent":
            text = ("INTENT.md -- the trust contract, delivered at session start by "
                    "hooks/floor-at-start.py. This run is unattended: nobody is present to approve "
                    "anything outside it.\n\n" + intent_text(ROOT))
        else:
            text = compact(ROOT, data.get("session_id") or "")
        if text:
            print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart",
                                                     "additionalContext": text}}))
    except Exception:
        pass


if __name__ == "__main__":
    main()
    sys.exit(0)
