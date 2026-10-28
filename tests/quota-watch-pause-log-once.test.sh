#!/usr/bin/env bash

# ── Resolve a python that RUNS (Windows) ─────────────────────────────────────
# Same probe as tests/quota-watch-pause.test.sh: on Windows `python3` can be a
# Store alias that exits 49 and prints nothing. $PYBIN is used UNQUOTED.
PYBIN=""
for _cand in python3 python "py -3"; do
  if $_cand -c 'import sys' >/dev/null 2>&1; then PYBIN="$_cand"; break; fi
done
if [ -z "$PYBIN" ]; then
  echo "SKIP: no working Python found (tried python3, python, py -3)" >&2
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# A paused quota watcher says PAUSED once per pause, not once per tick.
#
# WHY. The watcher ticks every few minutes. While the operator's pause lasted it
# logged the same "PAUSED by operator until …" line on every tick: one operator
# measured 5,031 identical lines in two weeks, burying every line that mattered.
# The pause is still reported to health on every tick; only the log is quieted.
# It is said again when the pause changes (another `until`) and once a day while
# it lasts, so a long pause is never silent.
#
# Runs _watch.py against a FABRICATED HOME and CLAUDE_CONFIG_DIR; never touches
# the operator's real files. Includes a CONTROL: without the memory marker every
# tick writes again, so the checks can see the difference.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CI="$ROOT/hooks/claude-identity"
FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT
export HOME="$FIX/home" CLAUDE_CONFIG_DIR="$FIX/home/.claude"
export AIOS_QUOTA_NOTIFY=0   # drives real watcher code: never put a quota banner on this machine's desktop
mkdir -p "$CLAUDE_CONFIG_DIR"
fails=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }
tick() { $PYBIN "$CI/_watch.py" "$CI/claude-identity.sh" </dev/null >/dev/null 2>&1; }
paused_lines() { grep -c PAUSED "$CLAUDE_CONFIG_DIR/quota-watch.log" 2>/dev/null || echo 0; }
age() { touch -t 202601010000 "$1"; }   # older than the write grace and than a day

future=$(( $(date +%s) + 86400 * 5 ))
echo "$future" > "$CLAUDE_CONFIG_DIR/quota-watch.paused"; age "$CLAUDE_CONFIG_DIR/quota-watch.paused"
tick; tick; tick
check "three ticks in one pause: a single PAUSED line" '[ "$(paused_lines)" = 1 ]'

echo $(( future + 3600 )) > "$CLAUDE_CONFIG_DIR/quota-watch.paused"; age "$CLAUDE_CONFIG_DIR/quota-watch.paused"
tick; tick
check "a new pause is said once more" '[ "$(paused_lines)" = 2 ]'

age "$CLAUDE_CONFIG_DIR/quota-watch.paused-logged"   # the memory marker is more than a day old
tick; tick
check "after a day the same pause is repeated once" '[ "$(paused_lines)" = 3 ]'

rm -f "$CLAUDE_CONFIG_DIR/quota-watch.paused-logged"; tick
check "CONTROL: without the marker the tick writes again" '[ "$(paused_lines)" = 4 ]'

# The write grace is not a pause of its own: `date +%s > file` leaves the file empty
# for an instant; that tick neither logs PAUSED nor is remembered, and the real
# expiry written right after is said exactly once.
before=$(paused_lines)
rm -f "$CLAUDE_CONFIG_DIR/quota-watch.paused-logged"
: > "$CLAUDE_CONFIG_DIR/quota-watch.paused"
tick
echo $(( future + 7200 )) > "$CLAUDE_CONFIG_DIR/quota-watch.paused"; age "$CLAUDE_CONFIG_DIR/quota-watch.paused"
tick; tick
check "empty marker then the real expiry: one PAUSED line" '[ $(( $(paused_lines) - before )) = 1 ]'

# A clock that went backwards (the marker looks dated in the future) does not silence the reminder.
before=$(paused_lines)
touch -t 203001010000 "$CLAUDE_CONFIG_DIR/quota-watch.paused-logged"
tick
check "a marker dated in the future does not silence the pause" '[ $(( $(paused_lines) - before )) = 1 ]'

# Resume, then pause again until the SAME time within the day: the new pause is said.
until_same=$(( future + 7200 ))
rm -f "$CLAUDE_CONFIG_DIR/quota-watch.paused"; tick            # resumed: one tick not paused
check "a tick without a pause forgets the last one" '[ ! -e "$CLAUDE_CONFIG_DIR/quota-watch.paused-logged" ]'
before=$(paused_lines)
echo "$until_same" > "$CLAUDE_CONFIG_DIR/quota-watch.paused"; age "$CLAUDE_CONFIG_DIR/quota-watch.paused"
tick; tick
check "a new pause with the same until is said once" '[ $(( $(paused_lines) - before )) = 1 ]'

# The marker cannot be removed (read-only folder): it is emptied instead, so the next pause is still said.
tick                                                            # paused: marker holds until_same
chmod 555 "$CLAUDE_CONFIG_DIR"
blocked=0; rm "$CLAUDE_CONFIG_DIR/quota-watch.paused" 2>/dev/null || blocked=1
chmod 755 "$CLAUDE_CONFIG_DIR"; rm -f "$CLAUDE_CONFIG_DIR/quota-watch.paused"   # resume (needs a writable dir)
chmod 555 "$CLAUDE_CONFIG_DIR"; tick; chmod 755 "$CLAUDE_CONFIG_DIR"            # resumed tick cannot unlink
if [ "$blocked" = 1 ] && [ -e "$CLAUDE_CONFIG_DIR/quota-watch.paused-logged" ]; then
  before=$(paused_lines)
  echo "$until_same" > "$CLAUDE_CONFIG_DIR/quota-watch.paused"; age "$CLAUDE_CONFIG_DIR/quota-watch.paused"
  tick
  check "a marker that could not be removed does not silence the next pause" '[ $(( $(paused_lines) - before )) = 1 ]'
else
  echo "skip read-only case: this filesystem or user ignores a read-only folder (Windows, root)"
fi

[ "$fails" = 0 ] && echo "all passed" || echo "$fails failure(s)"
exit $(( fails > 0 ))
