#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# /today must not write back a daily note that moved after it was read.
#
# In update mode /today reads today's note in Message 1b and replaces the whole
# file with `write_note` in Message 2, and its own rules said never to re-read
# after 1b. Whatever landed in between — a /close-session block, a box ticked in
# Obsidian, another session's edit — was overwritten by the older copy, and
# nothing reported it. Now 1b fingerprints the note with `git hash-object` and
# Message 2 compares before writing; a changed hash means re-read and merge.
#
# The fingerprint command is EXTRACTED from today.md and run: it must be stable
# on an untouched note, change when a line is added, work on an uncommitted
# file, and stay inside the command's own `Bash(cd ~/aios && git:*)` permission
# (a scheduled /today has nobody to answer a prompt). The ordering and the
# exception to "never re-read" are checked as properties of the text.
# ─────────────────────────────────────────────────────────────────────────────
set -u
cd "$(dirname "$0")/.." || exit 1
SPEC="$(pwd)/plugins/aios/commands/today.md"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '       %s\n' "$2"; return 0; }

echo "== today: re-check the note before writing it back =="

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# ── 1. the fingerprint command, as the spec prescribes it ────────────────────
cmd=$(grep -m1 'git hash-object "vault/01 - calendar/' "$SPEC" | sed 's/^[[:space:]]*//')
if [ -z "$cmd" ]; then
  no "Message 1b fingerprints today's note" "no 'git hash-object \"vault/01 - calendar/…' line in today.md"
else
  ok "Message 1b fingerprints today's note"
  case "$cmd" in
    "cd ~/aios && git "*) ok "the fingerprint runs under the existing Bash(cd ~/aios && git:*) permission" ;;
    *) no "the fingerprint needs a permission today.md does not grant" "$cmd" ;;
  esac
  grep -q '^allowed-tools:.*Bash(cd ~/aios && git:\*)' "$SPEC" \
    && ok "today.md still grants Bash(cd ~/aios && git:*)" \
    || no "today.md no longer grants Bash(cd ~/aios && git:*)"

  # Run it against a fixture vault. HOME points at the fixture so `~/aios` is it.
  mkdir -p "$TMP/home/aios/vault/01 - calendar/2026-10"
  git -C "$TMP/home/aios" init -q
  N="$TMP/home/aios/vault/01 - calendar/2026-10/2026-10-11.md"
  printf '# Today\n- [ ] ship it\n' > "$N"          # never committed: /7plan output often isn't yet
  run=$(printf '%s' "$cmd" | sed 's|{YYYY-MM}|2026-10|; s|{YYYY-MM-DD}|2026-10-11|')
  fp(){ HOME="$TMP/home" sh -c "$run" 2>/dev/null; }
  a=$(fp); b=$(fp)
  [ -n "$a" ] && [ "$a" = "$b" ] && ok "stable on an untouched, uncommitted note" \
    || no "not stable on an untouched note" "'$a' vs '$b'"
  printf '\n## Session — 09:40 | other session\nbody\n' >> "$N"
  c=$(fp)
  [ -n "$c" ] && [ "$c" != "$a" ] && ok "changes when another session appends a block" \
    || no "does not change when the note moves" "'$a' vs '$c'"
  sed 's/- \[ \] ship it/- [x] ship it/' "$N" > "$N.t" && mv "$N.t" "$N"
  d=$(fp)
  [ -n "$d" ] && [ "$d" != "$c" ] && ok "changes when a box is ticked (same length edit)" \
    || no "a ticked box is invisible to the fingerprint"
fi

# ── 2. the check sits where it can act, and the old rule makes room for it ───
chk=$(grep -n 'Before writing in update mode, check the note did not move' "$SPEC" | head -1 | cut -d: -f1)
wr=$(grep -n '^- Write the daily note (preserving user edits' "$SPEC" | head -1 | cut -d: -f1)
m2=$(grep -n '^### Message 2' "$SPEC" | head -1 | cut -d: -f1)
if [ -n "$chk" ] && [ -n "$wr" ] && [ -n "$m2" ] && [ "$chk" -gt "$m2" ] && [ "$chk" -lt "$wr" ]; then
  ok "the re-check is in Message 2, before the write"
else
  no "the re-check is missing or not before the write" "check=${chk:-none} write=${wr:-none} msg2=${m2:-none}"
fi
sed -n "${chk:-1},${wr:-1}p" "$SPEC" | grep -q 'Re-read the note now and merge' \
  && ok "a changed hash means re-read and merge, not write anyway" \
  || no "a changed hash does not lead to a re-read and merge"
grep -q '^- \*\*Never re-read files\*\* after Message 1b.*One exception: today.s note itself' "$SPEC" \
  && ok "'Never re-read files' names the exception" \
  || no "'Never re-read files' still forbids the re-read the check needs"

printf '\n  %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
