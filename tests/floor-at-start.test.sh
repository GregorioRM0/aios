#!/usr/bin/env bash
# tests/floor-at-start.test.sh
#
# hooks/floor-at-start.py delivers a COMPACT context floor at session start (INTENT whole, the
# newest entries' titles, the map of the full floor file) as SessionStart additionalContext. It
# skips routines and resumes, honours AIOS_FLOOR_AT_START=0/1, stays under its byte ceiling, and
# never fails a session start. Runs against a throwaway vault. bash 3.2-safe.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
H="$ROOT/hooks/floor-at-start.py"
PYBIN=""; for c in python3 python "py -3"; do if $c -c 'import sys' >/dev/null 2>&1; then PYBIN="$c"; break; fi; done
[ -n "$PYBIN" ] || { echo "SKIP: no working Python" >&2; exit 0; }
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; return 0; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
V="$T/vault-root"; C="$V/vault/00 - notes/context"
mkdir -p "$C/declared" "$C/observed" "$V/hooks"
cp "$ROOT/hooks/context-floor.py" "$ROOT/hooks/floor-at-start.py" "$V/hooks/"
printf '# Index\n' > "$C/declared/_index.md"; printf '# Index\n' > "$C/observed/_index.md"
printf '# About\n## Who\nprose\n' > "$C/declared/about_me.md"
{ printf '# Patterns\n'; for i in 1 2 3 4 5 6 7; do printf '### Pattern %s (2026-10-0%s)\nbody-%s\n' "$i" "$i" "$i"; done; } > "$C/observed/patterns.md"
printf '# Intent\n## Autonomy levels\nintent-marker-xyz\n' > "$V/INTENT.md"
printf '# User\n## Identity\n| Name | Role | Greeting style |\n|---|---|---|\n| `lead` | primary | hi |\n\n## Other\n' > "$V/USER.md"
export TMPDIR="$T"
hook(){ # $1 source · rest: env assignments
  local src="$1"; shift
  printf '{"session_id":"s1","source":"%s"}' "$src" | env -u AIOS_FLOOR_AT_START -u CLAUDE_AGENT_NAME "$@" $PYBIN "$V/hooks/floor-at-start.py"
}
ctx(){ $PYBIN -c 'import json,sys
try: print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])
except Exception: pass'; }

echo "-- what is delivered --"
OUT=$(hook startup CLAUDE_CODE_ENTRYPOINT=cli | ctx)
case "$OUT" in *intent-marker-xyz*) ok "INTENT.md is delivered whole" ;; *) no "INTENT missing" "$(printf '%s' "$OUT" | head -3)" ;; esac
case "$OUT" in *"patterns.md: Pattern 7"*) ok "the newest entries' titles are delivered" ;; *) no "newest titles missing" ;; esac
printf '%s' "$OUT" | grep 'body-7' >/dev/null && no "an entry BODY was delivered" "compact = titles only" || ok "entry bodies stay in the full file"
printf '%s' "$OUT" | grep 'Pattern 1 ' >/dev/null && no "an old entry's title was delivered" || ok "only the newest titles, not every title"
case "$OUT" in *"Read "*"context-floor-s1.md"*) ok "the map points at the full floor file" ;; *) no "no pointer to the full file" ;; esac
[ -f "$T/aios-floor-$(id -u 2>/dev/null || echo user)/context-floor-s1.md" ] && ok "the full floor file is written" || no "full floor file missing"
printf '%s' "$OUT" | grep 'NOT LOADED YET' >/dev/null && no "the compact floor still says the floor is not loaded" || ok "it does not tell the session the floor is missing"
hook startup CLAUDE_CODE_ENTRYPOINT=cli | $PYBIN -c 'import json,sys; d=json.load(sys.stdin)["hookSpecificOutput"]; assert d["hookEventName"]=="SessionStart"' \
  && ok "SessionStart output is the hook JSON shape" || no "bad SessionStart JSON"

echo "-- who gets it --"
[ -n "$(hook startup CLAUDE_CODE_ENTRYPOINT=sdk-cli)" ] && no "a routine (sdk) got the floor" || ok "routines (CLAUDE_CODE_ENTRYPOINT=sdk-*) are skipped"
[ -n "$(hook resume CLAUDE_CODE_ENTRYPOINT=cli)" ] && no "a resume got it again" || ok "a resume is skipped (the transcript already holds it)"
[ -n "$(hook compact CLAUDE_CODE_ENTRYPOINT=cli)" ] && ok "after a compaction it is delivered again" || no "not delivered after compaction"
[ -n "$(hook startup CLAUDE_CODE_ENTRYPOINT=cli CLAUDE_AGENT_NAME=lead)" ] && ok "a USER.md primary gets it" || no "primary skipped"
[ -n "$(hook startup CLAUDE_CODE_ENTRYPOINT=sdk-cli AIOS_FLOOR_AT_START=1)" ] && ok "AIOS_FLOOR_AT_START=1 opts any session in" || no "opt-in ignored"
[ -n "$(hook startup CLAUDE_CODE_ENTRYPOINT=cli AIOS_FLOOR_AT_START=0)" ] && no "opt-out ignored" || ok "AIOS_FLOOR_AT_START=0 opts any session out"

echo "-- never in the way --"
out=$(printf 'not json' | env -u AIOS_FLOOR_AT_START CLAUDE_CODE_ENTRYPOINT=cli $PYBIN "$V/hooks/floor-at-start.py"); rc=$?
[ "$rc" = 0 ] && ok "malformed stdin: exit 0" || no "malformed stdin rc=$rc"
mv "$C/observed" "$C/observed.off"
out=$(hook startup CLAUDE_CODE_ENTRYPOINT=cli); rc=$?
[ "$rc" = 0 ] && [ -z "$out" ] && ok "a vault the floor refuses: exit 0, silent" || no "broken vault rc=$rc out=$out"
mv "$C/observed.off" "$C/observed"
$PYBIN - "$V/INTENT.md" <<'PY'
import sys; open(sys.argv[1],'w').write('# Intent\n'+('x'*80+'\n')*900)
PY
OUT=$(hook startup CLAUDE_CODE_ENTRYPOINT=cli | ctx)
case "$OUT" in *"too large to deliver compactly"*"context-floor-s1.md"*) ok "past the ceiling it delivers the pointer, not a wall" ;; *) no "no ceiling fallback" "$(printf '%s' "$OUT" | head -c 200)" ;; esac

printf '\n  %d passed, %d failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
