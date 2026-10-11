#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Every `uv run` a command prescribes must run where sessions run.
#
# `uv` insists on ~/.cache/uv. A sandboxed Bash tool may write the vault and
# $TMPDIR only, so a bare `uv run` dies before running anything — and a hook
# that prints nothing reads exactly like a hook that found nothing. CLAUDE.md
# answers this with UV_CACHE_DIR, and tests/context-floor-invocation.test.sh
# holds the floor to it. The commands drifted: /aios:housekeeping prescribed
# the prefix for one bucket and dropped it two buckets later (Bucket 30's
# context-load-audit, Bucket 31's context-rungs), and /aios:close-day did the
# same for the two route-insight excisions.
#
# Three checks:
#   1. SCAN — no fenced command line in plugins/aios/commands/*.md starts with a
#      bare `uv run`. One exemption: a command whose allowed-tools frontmatter
#      pins that exact bare invocation (`Bash(uv run <script>:*)`) — prefixing
#      it would stop matching its own permission, which is a different fix.
#   2. MUTANT — the scan must flag a copy of housekeeping.md with the prefix
#      stripped back off, or check 1 passes vacuously.
#   3. RUN — the route-insight line close-day prescribes is extracted and run
#      against a HOME whose cache cannot be written, with a CONTROL that strips
#      UV_CACHE_DIR and must produce nothing. Same mechanism and caveats as
#      context-floor-invocation (env -u, XDG_CACHE_HOME cleared).
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
PASS=0; FAIL=0; SKIP=0
ok(){ PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '       %s\n' "$2"; return 0; }
sk(){ SKIP=$((SKIP+1)); printf '  skip %s\n' "$1"; }

echo "== commands: uv run carries UV_CACHE_DIR =="

# Prints "file:line: text" for each bare `uv run` inside a fenced block that the
# file's allowed-tools does not pin. Empty output = clean.
bare_uv_runs() {
  awk '
    FNR == 1 { fence = 0; pinned = "" }
    FNR <= 12 && /^allowed-tools:/ {
      s = $0
      while (match(s, /Bash\(uv run [^:)]*/)) {
        pinned = pinned "|" substr(s, RSTART + 5, RLENGTH - 5) "|"
        s = substr(s, RSTART + RLENGTH)
      }
    }
    /^[[:space:]]*```/ { fence = !fence; next }
    fence && /^[[:space:]]*uv run / {
      line = $0; sub(/^[[:space:]]*/, "", line)
      split(line, w, " "); cmd = "uv run " w[3]
      if (index(pinned, "|" cmd "|") == 0) printf "%s:%d: %s\n", FILENAME, FNR, line
    }
  ' "$@"
}

# ── 1. scan the shipped commands ─────────────────────────────────────────────
hits=$(bare_uv_runs plugins/aios/commands/*.md)
if [ -z "$hits" ]; then
  ok "no fenced command line in plugins/aios/commands/ runs a bare 'uv run'"
else
  no "bare 'uv run' in a command (sandboxed sessions get no output)" "$(printf '%s' "$hits" | head -5)"
fi

# The exemption is real, not a blanket: learned.md pins page-fit bare.
grep -q 'Bash(uv run ~/aios/hooks/page-fit.py:\*)' plugins/aios/commands/learned.md \
  && ok "exemption is scoped: learned.md pins its page-fit call in allowed-tools" \
  || sk "learned.md no longer pins page-fit — exemption unused there"

TMP="$(mktemp -d)"; trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT

# ── 2. mutant: the scan must catch the old shape ─────────────────────────────
mkdir -p "$TMP/mut"
sed 's|UV_CACHE_DIR="${TMPDIR:-/tmp}/uv-cache" uv run ~/aios/hooks/context-rungs.py|uv run ~/aios/hooks/context-rungs.py|' \
  plugins/aios/commands/housekeeping.md > "$TMP/mut/housekeeping.md"
if cmp -s plugins/aios/commands/housekeeping.md "$TMP/mut/housekeeping.md"; then
  no "MUTANT: could not reproduce the old housekeeping line" "the prefixed context-rungs call is gone from the spec"
elif [ -n "$(bare_uv_runs "$TMP/mut/housekeeping.md")" ]; then
  ok "MUTANT: the scan flags housekeeping.md with the prefix stripped"
else
  no "MUTANT: the scan missed a bare 'uv run' — check 1 proves nothing"
fi

# ── 3. RUN the prescribed route-insight line ─────────────────────────────────
if ! command -v uv >/dev/null 2>&1; then
  sk "uv not installed — the execution half cannot run here"
  printf '\n  %d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
  [ "$FAIL" -eq 0 ]; exit $?
fi

line=$(grep -m1 'uv run ~/aios/hooks/route-insight.py' plugins/aios/commands/close-day.md | sed 's/^[[:space:]]*//')
inv=$(printf '%s' "$line" | sed 's|\(route-insight\.py\).*|\1|; s|~/aios/|'"$REPO"'/|')
case "$inv" in
  UV_CACHE_DIR=*) ok "close-day prescribes route-insight with UV_CACHE_DIR" ;;
  *) no "close-day prescribes route-insight without UV_CACHE_DIR" "$line" ;;
esac

FAKE="$TMP/home"; mkdir -p "$FAKE/.cache"; chmod 500 "$FAKE/.cache"
bare=$(printf '%s' "$inv" | sed 's|^UV_CACHE_DIR=[^ ]* ||')

out_ctl="$TMP/ctl.out"
env -u UV_CACHE_DIR -u XDG_CACHE_HOME HOME="$FAKE" TMPDIR="$TMP" sh -c "$bare --help" >"$out_ctl" 2>/dev/null
if [ -s "$out_ctl" ]; then
  no "CONTROL: bare 'uv run' should fail against an unwritable cache" \
     "it produced output — this environment does not reproduce the condition"
else
  ok "CONTROL: bare 'uv run' emits nothing when ~/.cache/uv is unwritable"
fi

out_fix="$TMP/fix.out"
env -u UV_CACHE_DIR -u XDG_CACHE_HOME HOME="$FAKE" TMPDIR="$TMP" sh -c "$inv --help" >"$out_fix" 2>"$TMP/fix.err"
if grep -q 'usage: route-insight' "$out_fix"; then
  ok "the prescribed line runs against an unwritable cache"
else
  no "the prescribed line does not run against an unwritable cache" "$(head -2 "$TMP/fix.err")"
fi

printf '\n  %d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
