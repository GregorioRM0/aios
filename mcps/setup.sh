#!/bin/bash
# MCP Setup — creates virtual environments and installs dependencies for bundled MCPs.
# Run after /aios:update adds a new MCP, or when you decide you want one.
#
# Usage: bash mcps/setup.sh              # every bundled MCP (the old behaviour, unchanged)
#        bash mcps/setup.sh slack-mcp    # just these — one or more names
#        bash mcps/setup.sh --list       # what is available
#
# WHY selection exists: run with no arguments this installs TEN MCPs. On a new machine that
# means multiple Chrome-for-Testing downloads, several venvs and a few minutes of output in
# which one failure looks like a crash and a long download looks like a hang. A newcomer needs
# NONE of it — the vault only needs the Obsidian MCP, which is a published package registered
# directly with `claude mcp add` and is not even in this directory. Everything here is
# convenience: Slack, Atlassian, Google, image generation. They are worth installing WHEN the
# operator wants them, which is what /aios:mcps-setup asks. Making that the deferred path
# keeps the first ten minutes of AIOS about the AIOS.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ "$1" = "--list" ]; then
  echo "Bundled MCPs in $SCRIPT_DIR:"
  for d in "$SCRIPT_DIR"/*-mcp; do [ -d "$d" ] && echo "  $(basename "$d")"; done
  echo ""
  echo "Either spelling works — the folder name above, or the connector id"
  echo "without the -mcp suffix (e.g. nano-banana-mcp OR nano-banana)."
  echo ""
  echo "Install one:  bash mcps/setup.sh <name>"
  echo "Install all:  bash mcps/setup.sh"
  exit 0
fi

# No arguments → everything, exactly as before. Arguments → only those, so a later
# "I do want Slack after all" is one command instead of a ten-MCP reinstall.
WANTED="$*"
# Every caller below passes a FOLDER name (`nano-banana-mcp`), but the name an operator — or a
# tool reading `connector.json` — actually has is the connector ID (`nano-banana`). The AIOS App
# passed the id, nothing matched, and the script still reported success (see the MATCHED guard
# below). Accept BOTH spellings rather than making every caller remember which one this file wants.
want() {
  [ -z "$WANTED" ] && return 0
  _bare="${1%-mcp}"
  case " $WANTED " in
    *" $1 "*)      MATCHED=1; return 0 ;;   # folder name:  nano-banana-mcp
    *" $_bare "*)  MATCHED=1; return 0 ;;   # connector id: nano-banana
  esac
  return 1
}

# Did any requested name match a real MCP? Without this the script's closing line reports success
# unconditionally — it printed "All MCPs installed" after matching nothing and doing no work, on a
# real first install. A success message that cannot fail is not a success message.
MATCHED=0

if [ -n "$WANTED" ]; then echo "Setting up selected MCPs in $SCRIPT_DIR: $WANTED"; else echo "Setting up ALL bundled MCPs in $SCRIPT_DIR..."; fi
echo ""
# NOTE: intentionally no `set -e` — each MCP block is independent. One failure
# shouldn't kill the rest. Errors are surfaced per block.

# Cross-platform venv binary dir: Unix → .venv/bin, Windows (Git Bash) → .venv/Scripts.
# Call from inside the MCP dir AFTER `$PY -m venv .venv`. Without this, the
# hardcoded `.venv/bin/pip` path does not exist on Windows, the `&& echo "✓"`
# chain short-circuits, and the operator sees no error while nothing installed —
# the silent-failure bug surfaced on a Windows operator's machine 2026-05-26.
# Git Bash resolves bare names (pip, playwright) to their .exe, so no suffix needed.
vbin() { if [ -d ".venv/Scripts" ]; then echo ".venv/Scripts"; else echo ".venv/bin"; fi; }

# A pin bump must reach an install that already exists. Every Python MCP below used to be
# guarded by `[ ! -d .venv ]`, so it installed once and never again: a machine set up in May
# kept May's versions forever, whatever requirements.txt said (measured 2026-09-25: a
# notebooklm-py pinned nowhere and frozen at 0.3.4 while 0.8.2 shipped). Each install now
# records a hash of its requirements.txt in the venv, and a changed file reinstalls.
# CRLF-normalised, so a Windows checkout does not read as a change. Without a working Python
# there is nothing to hash, and an existing venv is left alone rather than rebuilt blind.
req_sha() { $PY -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read().replace(b"\r\n",b"\n")).hexdigest())' "$1" 2>/dev/null; }
needs_install() {
  [ -d "$1/.venv" ] || return 0
  # A venv but no Python >= 3.10 to check it with: the venv may be the one an older script built
  # on Python 3.9, which this MCP's pins cannot run on. Skipping it quietly ended in "All MCPs
  # installed" over an install nobody verified, so it is named as a failure instead.
  if [ -z "$PY" ]; then
    echo "→ $(basename "$1")..." >&2
    echo "  ✗ not checked — its .venv exists, but no Python >= ${PY_MIN:-3.10} is here to verify or update it" >&2
    FAILED="${FAILED:-} $(basename "$1")"; return 1
  fi
  [ -f "$1/requirements.txt" ] || return 1
  [ "$(cat "$1/.venv/.aios-requirements.sha256" 2>/dev/null)" != "$(req_sha "$1/requirements.txt")" ]
}
stamp_install() { req_sha requirements.txt > .venv/.aios-requirements.sha256; }

# Cross-platform Python launcher. On Windows, `python3.exe` is the Microsoft Store
# redirector stub by default — invoking it opens an "install Python" page and exits
# non-zero, so `python3 -m venv` silently no-ops while the `&& echo "✓"` chain hides
# it (the second half of the Windows silent-install bug — first half was the .venv/bin
# vs .venv/Scripts path, fixed via vbin() above; surfaced by a Windows operator
# 2026-05-27). Probe for a REAL interpreter: python3 → python → py -3. $PY is used
# UNQUOTED below so `py -3` word-splits correctly.
#
# A REAL interpreter is not enough — it must also be NEW enough. The `mcp` package needs
# Python >= 3.10, and macOS ships /usr/bin/python3 at 3.9: the probe accepted it, pip found
# "No matching distribution for mcp==1.28.1", and the block still printed "✓ installed" over an
# empty venv (measured 2026-10-20 on a fresh Mac). So: prefer versioned names, accept only
# >= 3.10, and fall back to uv (which can fetch a Python without admin rights) before giving up.
PY_MIN="3.10"
py_ok() { $1 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' >/dev/null 2>&1; }
PY=""
for cand in python3.12 python3.13 python3.11 python3.10 python3 python "py -3"; do
  if py_ok "$cand"; then PY="$cand"; break; fi
done
if [ -z "$PY" ] && command -v uv >/dev/null 2>&1; then
  _uvpy="$(uv python find 3.12 2>/dev/null)"
  if [ -z "$_uvpy" ]; then
    echo "→ No Python >= $PY_MIN on PATH — fetching Python 3.12 via uv (no admin needed)..."
    uv python install 3.12 >/dev/null 2>&1 && _uvpy="$(uv python find 3.12 2>/dev/null)"
  fi
  [ -n "$_uvpy" ] && py_ok "$_uvpy" && PY="$_uvpy"
fi
if [ -z "$PY" ]; then
  echo "✗ No Python >= $PY_MIN found (python3.1x / python3 / python / py -3 / uv all failed)."
  echo "  macOS ships Python 3.9, which is too old. Easiest fix: install uv"
  echo "  (https://docs.astral.sh/uv/) and re-run — this script then fetches Python itself."
  echo "  On Windows: install Python from python.org, then disable the Store alias —"
  echo "  Settings → Apps → Advanced app settings → App execution aliases → turn OFF"
  echo "  python.exe and python3.exe. Node-only MCPs (slack/stitch) still set up below."
  echo ""
else
  echo "Using Python: $PY ($($PY -c 'import sys; print(sys.version.split()[0])'))"
  echo ""
fi

# Build the venv and install requirements for one Python MCP; return non-zero on ANY failure
# and record it in FAILED. Every block used to run `pip install … && stamp_install` and then
# echo "✓ installed" unconditionally, so a failed pip was reported as success. A venv built by
# a too-old Python (the 3.9 case above) is rebuilt rather than reused, or the next run would
# fail the same way inside it forever.
FAILED=""
py_install() {
  _name="$1"
  if [ -z "$PY" ]; then
    echo "  ✗ skipped — no Python >= $PY_MIN"; FAILED="$FAILED $_name"; return 1
  fi
  if [ -d .venv ] && ! py_ok "$(vbin)/python"; then
    echo "  ↻ existing .venv uses a Python older than $PY_MIN — rebuilding it"
    rm -rf .venv
  fi
  if ! { [ -d .venv ] || $PY -m venv .venv; }; then
    echo "  ✗ could not create .venv"; FAILED="$FAILED $_name"; return 1
  fi
  # A venv made by `uv venv` has no pip — bootstrap it rather than fail on a missing binary.
  # pip is called as `python -m pip`: ensurepip installs only `pip3`, never a bare `pip`.
  "$(vbin)/python" -m pip --version >/dev/null 2>&1 || "$(vbin)/python" -m ensurepip -q >/dev/null 2>&1
  if ! "$(vbin)/python" -m pip install -r requirements.txt -q; then
    echo "  ✗ pip install failed — see the error above"; FAILED="$FAILED $_name"; return 1
  fi
  stamp_install
}

# Platform-correct install hint for a missing tool. The messages below used to say
# "brew install X" unconditionally, which on Windows and most Linux boxes names a
# package manager the operator does not have — a dead end dressed as instructions.
# Same $PY/vbin lesson one layer up: the script already knew it runs on three
# platforms, the ADVICE did not.
pkg_hint() {
  case "$(uname -s)" in
    Darwin)               echo "brew install $1" ;;
    MINGW*|MSYS*|CYGWIN*) echo "winget install $1" ;;
    *)                    echo "your package manager, e.g. apt install $1" ;;
  esac
}

# Chrome presence, per platform. The bare `[ -d "/Applications/Google Chrome.app" ]`
# check is mac-only, so on Windows and Linux it ALWAYS failed and printed
# "Google Chrome not found" at an operator who had Chrome installed — a false
# warning is worse than no warning, because it teaches you to ignore the output.
have_chrome() {
  case "$(uname -s)" in
    Darwin) [ -d "/Applications/Google Chrome.app" ] ;;
    MINGW*|MSYS*|CYGWIN*)
      [ -f "/c/Program Files/Google/Chrome/Application/chrome.exe" ] \
        || [ -f "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe" ] \
        || [ -f "$LOCALAPPDATA/Google/Chrome/Application/chrome.exe" ] \
        || command -v chrome >/dev/null 2>&1
      ;;
    *) command -v google-chrome >/dev/null 2>&1 \
        || command -v google-chrome-stable >/dev/null 2>&1 \
        || command -v chromium >/dev/null 2>&1 ;;
  esac
}

# --- Google Workspace MCP: NOTHING TO INSTALL (runtime is `uvx workspace-mcp`, from PyPI) ---
# This used to `python -m venv .venv && pip install -e .` against a vendored copy of the
# upstream server. It built ~196MB per operator for code that the registration never ran:
# SETUP.md registered the vendored tree, setup.sh's own summary advertised uvx, and
# mcps/_index.md called it "vendored" — three surfaces, three different answers about what
# the runtime was. The vendored copy had meanwhile frozen at 1.15.0 (upstream: 1.22.2) and
# imported a `gappsscript` module that was never vendored, so enabling that service would
# have crashed. uvx resolves the published package on demand — no venv, no staleness, no
# second copy to drift. Do not reintroduce a build step here.
if want google-workspace-mcp; then
  echo "→ google-workspace-mcp: no build needed (installed on demand via 'uvx workspace-mcp')"
fi

# --- Slack MCP (Node/NPM — invoked via npx at runtime, no install needed) ---
if want slack-mcp && [ -d "$SCRIPT_DIR/slack-mcp" ]; then
  echo "→ slack-mcp..."
  if ! command -v npx >/dev/null 2>&1; then
    echo "  ⚠ npx not found — install Node.js first"
  else
    npx -y @jtalk22/slack-mcp@5.0.0 --version >/dev/null 2>&1 \
      && echo "  ✓ ready (invoked via npx @jtalk22/slack-mcp@5.0.0 at runtime)" \
      || echo "  ✓ ready (will install on first invocation)"
  fi
fi

# --- NotebookLM MCP ---
if want notebooklm-mcp && [ -d "$SCRIPT_DIR/notebooklm-mcp" ] && needs_install "$SCRIPT_DIR/notebooklm-mcp"; then
  echo "→ notebooklm-mcp..."
  cd "$SCRIPT_DIR/notebooklm-mcp"
  if py_install notebooklm-mcp; then
    "$(vbin)/playwright" install chromium 2>/dev/null
    "$(vbin)/notebooklm" skill install 2>/dev/null || true
    echo "  ✓ installed (authenticate: run notebooklm login from mcps/notebooklm-mcp/$(vbin))"
  fi
fi

# --- Playwright MCP ---
if want playwright-mcp && [ -d "$SCRIPT_DIR/playwright-mcp" ] && needs_install "$SCRIPT_DIR/playwright-mcp"; then
  echo "→ playwright-mcp..."
  cd "$SCRIPT_DIR/playwright-mcp"
  if py_install playwright-mcp; then
    "$(vbin)/playwright" install chromium 2>/dev/null
    echo "  ✓ installed (chromium bundled)"
  fi
fi

# --- Atlassian MCP (vendored via pipx/uvx) ---
if want atlassian-mcp && [ -d "$SCRIPT_DIR/atlassian-mcp" ]; then
  echo "→ atlassian-mcp..."
  if ! command -v uvx >/dev/null 2>&1 && ! command -v pipx >/dev/null 2>&1; then
    echo "  ⚠ neither uvx nor pipx found — install one ($(pkg_hint uv)), then re-run"
  else
    if command -v uvx >/dev/null 2>&1; then
      if uvx 'mcp-atlassian==0.23.1' --help >/dev/null 2>&1; then
        echo "  ✓ ready (invoked via uvx mcp-atlassian==0.23.1 at runtime)"
      else
        echo "  ✗ uvx could not fetch mcp-atlassian==0.23.1 (offline, or no Python >= $PY_MIN for uv)"
        FAILED="$FAILED atlassian-mcp"
      fi
    else
      if pipx install 'mcp-atlassian==0.23.1' --force; then
        echo "  ✓ installed via pipx"
      else
        echo "  ✗ pipx install failed — see the error above"; FAILED="$FAILED atlassian-mcp"
      fi
    fi
  fi
fi

# --- Nano Banana MCP (Gemini image gen) ---
if want nano-banana-mcp && [ -d "$SCRIPT_DIR/nano-banana-mcp" ] && needs_install "$SCRIPT_DIR/nano-banana-mcp"; then
  echo "→ nano-banana-mcp..."
  cd "$SCRIPT_DIR/nano-banana-mcp"
  py_install nano-banana-mcp && echo "  ✓ installed (requires GEMINI_API_KEY — see README)"
fi

# --- PDF Generator MCP ---
if want pdf-generator-mcp && [ -d "$SCRIPT_DIR/pdf-generator-mcp" ] && needs_install "$SCRIPT_DIR/pdf-generator-mcp"; then
  echo "→ pdf-generator-mcp..."
  cd "$SCRIPT_DIR/pdf-generator-mcp"
  if py_install pdf-generator-mcp; then
    command -v pandoc >/dev/null 2>&1 || echo "  ⚠ pandoc not found — $(pkg_hint pandoc)"
    have_chrome || echo "  ⚠ Google Chrome not found — install from https://google.com/chrome"
    echo "  ✓ installed (requires pandoc + Chrome)"
  fi
fi

# --- Spotify DJ MCP ---
if want spotify-dj-mcp && [ -d "$SCRIPT_DIR/spotify-dj-mcp" ] && needs_install "$SCRIPT_DIR/spotify-dj-mcp"; then
  echo "→ spotify-dj-mcp..."
  cd "$SCRIPT_DIR/spotify-dj-mcp"
  py_install spotify-dj-mcp && echo "  ✓ installed (requires Spotify Dev app + SPOTIFY_CLIENT_ID/SECRET — see README)"
fi

# --- Stitch MCP (Google AI-native design — runs via npx, no install needed) ---
if want stitch-mcp && [ -d "$SCRIPT_DIR/stitch-mcp" ]; then
  echo "→ stitch-mcp..."
  if ! command -v npx >/dev/null 2>&1; then
    echo "  ⚠ npx not found — install Node.js first"
  else
    npx -y @_davideast/stitch-mcp --version >/dev/null 2>&1 \
      && echo "  ✓ ready (invoked via npx @_davideast/stitch-mcp proxy at runtime; requires Google Cloud OAuth login — see README)" \
      || echo "  ✓ ready (will install on first invocation)"
  fi
fi

echo ""
if [ -n "$WANTED" ] && [ "$MATCHED" = "0" ]; then
  echo ""
  echo "✗ Nothing matched: $WANTED"
  echo "  No MCP by that name is bundled here, so NOTHING was installed."
  echo "  Run \`bash mcps/setup.sh --list\` to see the real names (either the folder"
  echo "  name like \`nano-banana-mcp\` or the connector id like \`nano-banana\` works)."
  exit 1
fi

if [ -n "$FAILED" ]; then
  echo "✗ These MCPs did NOT install:$FAILED"
  echo "  Read the ✗ lines above for the reason, fix it, and re-run this script with those names."
  exit 1
fi

echo "All MCPs installed. Recommended: ask Claude to run \`/mcps-setup\` — it walks"
echo "you through tokens + register + verify for each MCP in a guided flow."
echo ""
echo "Manual auth steps per MCP (if you prefer):"
echo "  • pdf-generator    : no auth (works immediately — just register)"
echo "  • google-workspace : uvx workspace-mcp (opens browser on first call)"
echo "  • slack            : npx -y @jtalk22/slack-mcp@5.0.0 --refresh-tokens  (extracts from Chrome; posts AS YOU)"
echo "  • notebooklm       : run 'notebooklm login' from mcps/notebooklm-mcp/.venv/bin (Unix) or .venv/Scripts (Windows)"
echo "  • atlassian        : export ATLASSIAN_URL / ATLASSIAN_USERNAME / ATLASSIAN_API_TOKEN"
echo "  • nano-banana      : export GEMINI_API_KEY (requires Cloud Billing enabled — ~\$0.04/image)"
echo "  • spotify-dj       : export SPOTIFY_CLIENT_ID / SPOTIFY_CLIENT_SECRET (Developer app)"
echo "  • stitch           : npx -y @_davideast/stitch-mcp init (browser OAuth sign-in; needs gcloud)"
echo "  • playwright       : per-service browser-state login, see playwright-mcp/README.md"
echo ""
echo "Register each with: claude mcp add {name} -- {command}  (see each README)"
