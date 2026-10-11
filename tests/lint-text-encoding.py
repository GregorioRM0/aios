#!/usr/bin/env python3
"""Every text-mode file read or write under hooks/ must name its encoding.

Without `encoding=`, Python uses the locale's encoding: UTF-8 on macOS and most Linux, but cp1252
on a stock Windows install. A hook that writes a note with an accent, or reads ~/.claude.json with
a non-ASCII display name, then mis-decodes or raises on Windows only. CI runs on ubuntu, where the
default happens to be UTF-8, so the class is invisible there by construction; this lint is what
makes it visible. The sweep that cleared the existing sites read each one first (most sit in the
credential and quota code), so this check went green only after that sweep, never before.

What counts: builtin `open()` and `.open()` / `.read_text()` / `.write_text()` on a path, in text
mode, with no `encoding=` keyword. Binary mode (`"rb"`, `"wb"`, ...) is exempt, as are `Image.open`,
`os.open` and friends. Parsed with `ast`, not a regex, so a call split across lines still counts and
a string that merely contains "open(" does not.

A self-check runs first: a known-bad snippet must be flagged and a known-good one must not, so a
lint that silently matches nothing cannot pass. Exit 0 clean · 1 sites found · 2 self-check failed.
"""
import ast
import os
import sys

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
NOT_PATHS = {"Image", "os", "io", "gzip", "tarfile", "zipfile", "webbrowser", "codecs",
             "subprocess", "fitz", "tempfile"}


def sites(src):
    found = []
    for n in ast.walk(ast.parse(src)):
        if not isinstance(n, ast.Call):
            continue
        f = n.func
        if isinstance(f, ast.Name) and f.id == "open":
            builtin = True
        elif (isinstance(f, ast.Attribute) and f.attr in ("open", "read_text", "write_text")
              and not (isinstance(f.value, ast.Name) and f.value.id in NOT_PATHS)):
            builtin = False
        else:
            continue
        if "encoding" in {k.arg for k in n.keywords}:
            continue
        mode = None
        pos = n.args[1] if builtin and len(n.args) >= 2 else (n.args[0] if not builtin and f.attr == "open" and n.args else None)
        if isinstance(pos, ast.Constant) and isinstance(pos.value, str):
            mode = pos.value
        for k in n.keywords:
            if k.arg == "mode" and isinstance(k.value, ast.Constant):
                mode = k.value.value
        if mode and "b" in mode:
            continue
        found.append(n.lineno)
    return found


def self_check():
    bad = 'import json\nd = json.load(open(p))\nq.write_text(s)\nwith open(x, "w") as f:\n    pass\n'
    good = ('d = open(p, encoding="utf-8")\nb = open(p, "rb")\nImage.open(p)\nq.read_text(encoding="utf-8")\n'
            'with open(x, mode="wb") as f:\n    pass\n')
    return len(sites(bad)) == 3 and sites(good) == []


def main():
    if not self_check():
        print("lint-text-encoding: SELF-CHECK FAILED -- the detector no longer flags a known-bad call")
        return 2
    hits = []
    hooks = os.path.join(ROOT, "hooks")
    for dirpath, dirnames, files in os.walk(hooks):
        dirnames[:] = [d for d in dirnames if d not in ("custom", "node_modules", ".venv", "__pycache__")]
        for fn in sorted(files):
            if not fn.endswith(".py"):
                continue
            p = os.path.join(dirpath, fn)
            with open(p, encoding="utf-8") as fh:
                src = fh.read()
            for ln in sites(src):
                hits.append("%s:%d" % (os.path.relpath(p, ROOT), ln))
    if hits:
        print("lint-text-encoding: text IO with no encoding= (cp1252 on Windows):\n")
        for h in hits:
            print("  " + h)
        print('\nAdd encoding="utf-8" to each call (and read the site first: what wrote that file?).')
        return 1
    print("lint-text-encoding: clean -- every text-mode open/read_text/write_text in hooks/ names its encoding")
    return 0


if __name__ == "__main__":
    sys.exit(main())
