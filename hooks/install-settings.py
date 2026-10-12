#!/usr/bin/env python3
"""install-settings.py — wire the universal hooks into ~/.claude/settings.json, in plain language.

WHY. Setup used to have the session edit ~/.claude/settings.json with its file-edit tool, so a new
operator was asked to approve a wall of JSON they could not read, at the moment they trust the
system least. The hooks are the same; what changes is the approval. This merges them for you,
keeps every key you already have, shows in one line per hook what each one does for you, and asks
for one yes (a command, not a JSON diff).

WHAT IT WIRES (SETUP §10 is the reference; tests/install-settings.test.sh keeps the two in step):
  A  the clock            -- every message carries the real date and time
  B  the status line      -- context and quota display; feeds the quota autopilot's cache
  C  the venture guard    -- only once a company is mounted (a ventures/*/.{v}-sync marker exists)
  D  provenance           -- labels text you did not write (email, chat, docs, web, inbox prompts)
  E  the floor at start   -- a compact context floor delivered to every new session
  F  the model-switch log -- one line whenever a session's model changes under it

USAGE
  install-settings.py              show what would change (default: changes nothing)
  install-settings.py --apply      back up settings.json, merge, write, read back and verify

Merge rules: a hook already present (matched by its script, however it is spelled) is left alone;
an existing statusLine is never replaced (the summary says so, because hook B feeds the quota cache);
every other key in the file is kept byte for byte in meaning. Exit 0 ok · 1 the file is not valid
JSON (nothing written) · 2 the write could not be verified (the backup is named).
"""
import argparse
import datetime
import glob
import json
import os
import shutil
import subprocess
import sys

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("AIOS_ROOT") or os.path.dirname(HERE)
PROVENANCE_MATCHER = ("mcp__forum__.*|mcp__google-workspace__.*|mcp__claude_ai_.*|mcp__slack__.*|"
                      "mcp__atlassian__.*|mcp__claude-in-chrome__.*|mcp__notebooklm.*|WebFetch|WebSearch")


def windows_python():
    if os.environ.get("AIOS_WIN_PYTHON"):  # tests, or an operator who knows better than the probe
        return os.environ["AIOS_WIN_PYTHON"]
    for cand in (["python3"], ["python"], ["py", "-3"]):
        try:
            if subprocess.run(cand + ["-c", ""], capture_output=True, timeout=20).returncode == 0:
                return " ".join(cand)
        except (OSError, subprocess.TimeoutExpired):
            continue
    return "python"


def plan(platform, root, venture_guard):
    """[(key, event, matcher, command, timeout, what it does)] in SETUP §10's exact command forms."""
    if platform == "windows":
        py = windows_python()
        r = root.replace("\\", "/")
        h = lambda s: '%s "%s/hooks/%s"' % (py, r, s)
        clock = 'powershell -NoProfile -ExecutionPolicy Bypass -File "%s/hooks/inject-datetime.ps1"' % r
        rows = [
            ("A", "UserPromptSubmit", None, clock, None),
            ("D", "UserPromptSubmit", None, h("provenance.py") + " --prompt", 10),
            ("D", "PreToolUse", "Write|Edit", h("bus_log.py") + " --hook", 10),
            ("D", "PostToolUse", PROVENANCE_MATCHER, h("provenance.py") + " --tool", 10),
            ("E", "SessionStart", None, h("floor-at-start.py"), 60),
            ("F", "PostModelSwitch", None, h("model-switch-log.py"), 10),
        ]
        if venture_guard:
            rows.append(("C", "PreToolUse", "Edit|Write|MultiEdit|NotebookEdit", h("guard-venture-mount.py"), 10))
        status = ("bash -c 'tee >($HOME/aios/hooks/claude-identity/claude-identity.sh cache > /dev/null) | "
                  "%s $HOME/aios/hooks/claude-identity/context-monitor.py'" % py)
    else:
        rows = [
            ("A", "UserPromptSubmit", None, "bash ~/aios/hooks/inject-datetime.sh", None),
            ("D", "UserPromptSubmit", None, "python3 ~/aios/hooks/provenance.py --prompt", 10),
            ("D", "PreToolUse", "Write|Edit", "python3 ~/aios/hooks/bus_log.py --hook", 10),
            ("D", "PostToolUse", PROVENANCE_MATCHER, "python3 ~/aios/hooks/provenance.py --tool", 10),
            ("E", "SessionStart", None, "python3 ~/aios/hooks/floor-at-start.py", 60),
            ("F", "PostModelSwitch", None, "python3 ~/aios/hooks/model-switch-log.py", 10),
        ]
        if venture_guard:
            rows.append(("C", "PreToolUse", "Edit|Write|MultiEdit|NotebookEdit",
                         "python3 ~/aios/hooks/guard-venture-mount.py", 10))
        status = ("bash -c 'tee >($HOME/aios/hooks/claude-identity/claude-identity.sh cache > /dev/null) | "
                  "python3 $HOME/aios/hooks/claude-identity/context-monitor.py'")
    return rows, status


WHAT = {
    "A": "the clock: every message you send carries the real date and time",
    "B": "the status line: context and quota at the bottom of the terminal; feeds the quota autopilot",
    "C": "the venture guard: stops edits to a company folder that is a synced copy",
    "D": "provenance: marks text you did not write (email, chat, docs, the web, inbox prompts)",
    "E": "the floor at start: each new session starts with your trust contract and recent learnings",
    "F": "the model-switch log: records when a session is moved to another model",
}


def signature(cmd):
    """What identifies a hook regardless of how its interpreter or path is spelled."""
    for key in ("inject-datetime", "floor-at-start.py", "model-switch-log.py", "guard-venture-mount.py",
                "bus_log.py", "provenance.py"):
        if key in cmd:
            if key == "provenance.py":
                return key + (" --prompt" if "--prompt" in cmd else " --tool" if "--tool" in cmd else "")
            return key
    return cmd


def present(settings, event, cmd):
    want = signature(cmd)
    for group in (settings.get("hooks") or {}).get(event, []) or []:
        for hk in group.get("hooks", []) or []:
            if signature(str(hk.get("command", ""))) == want:
                return True
    return False


def main():
    ap = argparse.ArgumentParser(prog="install-settings.py")
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--platform", choices=["windows", "posix"])
    ap.add_argument("--settings")
    a = ap.parse_args()
    platform = a.platform or ("windows" if sys.platform == "win32" else "posix")
    cfg = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
    path = a.settings or os.path.join(cfg, "settings.json")
    venture_guard = bool(glob.glob(os.path.join(ROOT, "vault", "00 - notes", "context", "ventures", "*", ".*-sync")))

    if os.path.exists(path):
        try:
            with open(path, encoding="utf-8") as f:
                raw = f.read()
            settings = json.loads(raw) if raw.strip() else {}
        except ValueError as e:
            print("settings.json is not valid JSON (%s). Nothing was changed; fix or move it first: %s" % (e, path))
            return 1
    else:
        settings = {}

    rows, status = plan(platform, ROOT, venture_guard)
    adds, keeps = [], []
    for key, event, matcher, cmd, timeout in rows:
        (keeps if present(settings, event, cmd) else adds).append((key, event, matcher, cmd, timeout))
    status_add = "statusLine" not in settings
    status_note = None
    if not status_add and "claude-identity.sh cache" not in str(settings.get("statusLine", {}).get("command", "")):
        status_note = ("you already have your own status line, so it is left as it is -- the quota autopilot's "
                       "cache (hook B) will not be fed until it also runs claude-identity.sh cache (SETUP §10)")

    print("Claude Code settings: %s" % path)
    shown = set()
    for key, *_ in adds:
        if key not in shown:
            print("  + add   %s  %s" % (key, WHAT[key])); shown.add(key)
    if status_add:
        print("  + add   B  %s" % WHAT["B"])
    for key, *_ in keeps:
        if key not in shown:
            print("  = keep  %s  already set up" % key); shown.add(key)
    if not status_add and not status_note:
        print("  = keep  B  already set up")
    if status_note:
        print("  ! note  B  " + status_note)
    if not venture_guard:
        print("  - later C  the venture guard is added when you mount a company (/aios:company --mount)")
    print("  Everything else in the file is kept.")

    if not adds and not status_add:
        print("Nothing to change.")
        return 0
    if not a.apply:
        print("Nothing written yet. To make these changes: %s --apply" % os.path.basename(sys.argv[0]))
        return 0

    hooks = settings.setdefault("hooks", {})
    for key, event, matcher, cmd, timeout in adds:
        entry = {"type": "command", "command": cmd}
        if timeout:
            entry["timeout"] = timeout
        group = {"hooks": [entry]}
        if matcher:
            group = {"matcher": matcher, "hooks": [entry]}
        hooks.setdefault(event, []).append(group)
    if status_add:
        settings["statusLine"] = {"type": "command", "command": status}

    backup = None
    if os.path.exists(path):
        backup = path + ".bak-aios-" + datetime.datetime.now().strftime("%Y%m%d%H%M%S")
        shutil.copy2(path, backup)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    # Keep the file's permissions: settings.json can hold tokens and is often 0600. A temp file is
    # created with the default umask (typically 0644), so without this the replace would loosen it.
    mode = (os.stat(path).st_mode & 0o777) if os.path.exists(path) else 0o600
    tmp = path + ".aios-tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.chmod(tmp, mode)
    os.replace(tmp, path)
    try:
        with open(path, encoding="utf-8") as f:
            back = json.load(f)
        ok = all(present(back, ev, cmd) for _, ev, _, cmd, _ in rows) and "statusLine" in back
    except (OSError, ValueError):
        ok = False
    if not ok:
        print("Written, but the read-back did not show every hook. Your previous file is at: %s" % (backup or "(none)"))
        return 2
    print("Done. " + (("Your previous file is saved as %s. " % backup) if backup else "")
          + "A new Claude session picks these up (hooks load at session start).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
