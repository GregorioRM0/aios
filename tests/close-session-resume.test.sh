#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# /close-session's gate must tell a FINISHED close from an INTERRUPTED one.
#
# Step 5 appends and commits the session block; the observed-context routing
# (steps 6-10) comes after it. A close cut off between the two left a stamp and
# no routing, and the gate — which only asked "did this session commit work
# since its stamp?" — read a re-run as a duplicate and skipped exactly the
# steps that never ran. Now a close records its end (step 10b, or the block
# itself under --auto) and the gate answers one of four verdicts:
#   first · second · duplicate (stamp + done + no work) · resume (stamp, no done)
#
# The gate is EXTRACTED from close-session.md and run, under bash and zsh, so a
# regression in the spec fails here — not a transcription of it. A mutant with
# the done check replaced by the old rule must answer `duplicate` for an
# interrupted close, or the resume case proves nothing.
#
# The commits-only blind spot (work done and not committed reads as "no work")
# has no mechanical signal — uncommitted changes in a shared vault are usually
# a peer's — so the spec hands that judgment to the session's own conversation.
# Those rules are checked as properties of the text.
# ─────────────────────────────────────────────────────────────────────────────
set -u
cd "$(dirname "$0")/.." || exit 1
SPEC="$(pwd)/plugins/aios/commands/close-session.md"
PASS=0; FAIL=0; SKIP=0
ok(){ PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '       %s\n' "$2"; return 0; }
sk(){ SKIP=$((SKIP+1)); printf '  skip %s\n' "$1"; }

echo "== close-session: resume an interrupted close =="

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# The gate block: the fenced bash block that defines SID from CLAUDE_CODE_SESSION_ID.
awk '/^   ```bash$/{inb=1; buf=""; next}
     inb && /^   ```$/{ if (buf ~ /CLAUDE_CODE_SESSION_ID:-unknown/) { printf "%s", buf; exit } inb=0; next }
     inb { sub(/^   /, ""); buf = buf $0 "\n" }' "$SPEC" > "$TMP/gate.sh"
if grep -q 'close-session gate: ' "$TMP/gate.sh"; then
  ok "the gate block is found in the spec and prints a verdict"
else
  no "the gate block does not print a verdict" "extracted $(grep -c . "$TMP/gate.sh") lines; no 'close-session gate:' line"
fi
# Point NOTE at the fixture; everything else runs as written.
sed -i.bak 's|^NOTE=.*|NOTE="$FIXNOTE"|' "$TMP/gate.sh"

# Fixture: HOME/aios is a git repo, the note lives in it.
setup(){
  rm -rf "$TMP/home"; mkdir -p "$TMP/home/aios"
  git -C "$TMP/home/aios" init -q
  git -C "$TMP/home/aios" config user.email t@example.com
  git -C "$TMP/home/aios" config user.name Test
  git -C "$TMP/home/aios" config commit.gpgsign false
  echo seed > "$TMP/home/aios/f"; git -C "$TMP/home/aios" add f
  git -C "$TMP/home/aios" commit -q -m "initial work"
  NOTEF="$TMP/home/aios/note.md"; : > "$NOTEF"
}
head_(){ git -C "$TMP/home/aios" rev-parse HEAD; }
# a close: stamp the current head, commit the note as `session: …` with this SID's trailer
stamp(){ printf '## Session — 10:00 | w\n<!-- close-session: %s @ %s -->\n' "$1" "$2" >> "$NOTEF"
         git -C "$TMP/home/aios" add note.md
         git -C "$TMP/home/aios" commit -q -m "session: 10:00 w" -m "AIOS-Session: $1"; }
done_(){ printf '<!-- close-session-done: %s @ %s -->\n' "$1" "$2" >> "$NOTEF"
         git -C "$TMP/home/aios" add note.md
         git -C "$TMP/home/aios" commit -q -m "session: 10:00 w — done" -m "AIOS-Session: $1"; }
work(){ echo "$RANDOM" >> "$TMP/home/aios/f"; git -C "$TMP/home/aios" add f
        if [ -n "$1" ]; then git -C "$TMP/home/aios" commit -q -m "real work" -m "AIOS-Session: $1"
        else git -C "$TMP/home/aios" commit -q -m "real work"; fi; }

# verdict <shell> <sid> [gate-file]
verdict(){ env HOME="$TMP/home" FIXNOTE="$NOTEF" CLAUDE_CODE_SESSION_ID="$2" "$1" "${3:-$TMP/gate.sh}" 2>/dev/null \
           | sed -n 's/^close-session gate: //p'; }

ME=11111111-aaaa; PEER=22222222-bbbb
SHELLS="bash"; command -v zsh >/dev/null 2>&1 && SHELLS="bash zsh" || sk "zsh not installed — bash only"

for sh in $SHELLS; do
  check(){ local got; got=$(verdict "$sh" "$1" "${3:-}"); [ "$got" = "$2" ] && ok "$sh: $4" || no "$sh: $4" "expected $2, got '${got}'"; }

  setup
  check "$ME" first "" "no stamp → first"

  setup; h=$(head_); stamp "$ME" "$h"; done_ "$ME" "$h"
  check "$ME" duplicate "" "stamp + done + no work since → duplicate"

  setup; h=$(head_); stamp "$ME" "$h"
  check "$ME" resume "" "stamp, no done marker, no work since → resume (the interrupted close)"

  setup; h=$(head_); stamp "$ME" "$h"; work "$ME"
  check "$ME" second "" "stamp + own work since → second, done marker or not"

  setup; h=$(head_); stamp "$ME" "$h"; done_ "$PEER" "$h"
  check "$ME" resume "" "a PEER's done marker does not finish my close"

  setup; h=$(head_); stamp "$ME" "$h"; done_ "$ME" "$h"; work "$ME"; h2=$(head_); stamp "$ME" "$h2"
  check "$ME" resume "" "an EARLIER close's done marker does not finish the latest one"

  setup; h=$(head_); stamp "$ME" "$h"; done_ "$ME" "$h"; work "$PEER"
  check "$ME" duplicate "" "a peer's commit is not my work (precise path still holds)"

  # Owed closes: an EARLIER unfinished close must not be hidden by a LATER finished one.
  # The line must be PRINTED: an absent line reads as "nothing owed" and would pass vacuously.
  owedchk(){ local raw got; raw=$(env HOME="$TMP/home" FIXNOTE="$NOTEF" CLAUDE_CODE_SESSION_ID="$1" "$sh" "$TMP/gate.sh" 2>/dev/null \
               | grep '^close-session owed:'); got=$(printf '%s' "$raw" | sed 's/^close-session owed://' | tr -d ' ')
             [ -n "$raw" ] && [ "$got" = "$2" ] && ok "$sh: $3" || no "$sh: $3" "owed expected '$2', got '${raw:-<no owed line>}'"; }
  setup; hA=$(head_); stamp "$ME" "$hA"; work "$ME"
  check "$ME" second "" "interrupted close A, then committed work → second"
  owedchk "$ME" "$hA" "…and the gate lists A as owed, for the new close to settle"
  hB=$(head_); stamp "$ME" "$hB"; done_ "$ME" "$hB"
  check "$ME" resume "" "B finished but A never did → resume, NOT duplicate (A's routing is still owed)"
  done_ "$ME" "$hA"
  check "$ME" duplicate "" "once B's close also marks A → duplicate"
  owedchk "$ME" "" "…and nothing is owed"

  # The mutant: the old rule — any stamp with no work is a duplicate.
  sed 's|^elif \[ -z "\$OWED" \]; then$|elif true; then|' "$TMP/gate.sh" > "$TMP/gate-old.sh"
  if cmp -s "$TMP/gate.sh" "$TMP/gate-old.sh"; then
    no "$sh: MUTANT could not be built" "the done-marker check is no longer one line in the gate"
  else
    setup; h=$(head_); stamp "$ME" "$h"
    check "$ME" duplicate "$TMP/gate-old.sh" "MUTANT (old rule) answers duplicate for the interrupted close — the case above is load-bearing"
  fi
done

# ── the rules around the gate, as properties of the text ────────────────────
grep -q '^10b\. \*\*Record that this close finished' "$SPEC" \
  && ok "step 10b exists" || no "step 10b (done marker) is missing"
awk '/^10\. \*\*Commit any observed-context/{a=NR} /^10b\. /{b=NR} END{exit !(a && b && b > a)}' "$SPEC" \
  && ok "10b comes after step 10 — the marker is evidence the routing ran" \
  || no "10b is not after step 10"
sed -n '/^10b\. /,/^### /p' "$SPEC" | grep -q 'AIOS_CLOSE_SESSION_NO_PUSH:-' \
  && ok "10b's push honours AIOS_CLOSE_SESSION_NO_PUSH" || no "10b pushes without the opt-out"
sed -n '/^10b\. /,/^### /p' "$SPEC" | grep -q -- '-m "session: ' \
  && ok "10b's commit subject starts 'session: ' — never counted as work" || no "10b's subject would count as work"
grep -q 'Under `--auto`, add the done marker' "$SPEC" \
  && ok "under --auto the block itself carries the done marker" || no "--auto closes never record their end"
grep -q '\*\*`resume`\*\*.*[Dd]o \*\*not\*\* append a second block' "$SPEC" \
  && ok "resume never appends a second block" || no "resume does not forbid a second block"
grep -q '\*\*`duplicate`\*\*.*read your own conversation since that close' "$SPEC" \
  && ok "duplicate checks the conversation for uncommitted work before skipping" \
  || no "duplicate skips on commits alone — uncommitted work is lost"
grep -q 'Do not use uncommitted vault changes as the signal' "$SPEC" \
  && ok "and does not count a shared vault's uncommitted changes as its own" \
  || no "nothing stops uncommitted peer changes from reading as this session's work"
grep -q '\*\*`resume`\*\*.*Run the same conversation check first' "$SPEC" \
  && ok "resume checks the conversation too — new uncommitted work makes it a second close" \
  || no "resume never looks for work done since the unfinished close"
grep -q '\*\*`resume`\*\*.*Under `--auto`, write nothing and no marker' "$SPEC" \
  && ok "an --auto resume writes no marker (it cannot do the routing the marker vouches for)" \
  || no "an --auto resume can mark an interactive close finished without its routing"
grep -q '^10b\. .*interactive closes only' "$SPEC" \
  && ok "10b is for interactive closes only" \
  || no "10b still runs for an --auto resume"
grep -q '^10b\. .*one such line for each hash the gate listed in `close-session owed:`' "$SPEC" \
  && ok "10b settles every owed close, not only its own" \
  || no "10b marks only its own close — an earlier unfinished one stays hidden"
grep -q 'Under `--auto`, add the done marker.*one more such line for each hash in `close-session owed:`' "$SPEC" \
  && ok "an --auto block settles every owed close too" \
  || no "an --auto block marks only its own close"
grep -q '\*\*Owed closes\.\*\*.*puts \*\*the whole session.s\*\* observations in its Tier A candidates' "$SPEC" \
  && ok "an --auto close that settles a debt carries the whole session's observations" \
  || no "an --auto close marks owed closes without carrying their observations"

# ── the producers write exactly what the gate reads ─────────────────────────
# Each producer's literal is taken from the spec, filled in, written to a note,
# and the extracted gate must then answer `duplicate`. A renamed marker in one
# producer would leave every check above green while no real close ever matched.
producer_10b=$(sed -n '/^10b\. /p' "$SPEC" | grep -o '<!-- close-session-done: [^>]*-->' | head -1)
producer_auto=$(grep 'Under `--auto`, add the done marker' "$SPEC" | grep -o '<!-- close-session-done: [^>]*-->' | head -1)
gate_reads() {   # <label> <literal> [gate-file]
  local lit="$2" got
  [ -n "$lit" ] || { no "$1: no marker literal found in the spec"; return; }
  setup; h=$(head_); stamp "$ME" "$h"
  printf '%s\n' "$lit" | sed "s|{SID}|$ME|; s|{VHEAD}|$h|" >> "$NOTEF"
  git -C "$TMP/home/aios" add note.md; git -C "$TMP/home/aios" commit -q -m "session: done" -m "AIOS-Session: $ME"
  got=$(verdict bash "$ME" "${3:-}")
  [ "$got" = duplicate ] && ok "$1: the gate recognises it" || no "$1: the gate does not recognise it" "got '$got' for $lit"
}
gate_reads "step 10b's marker" "$producer_10b"
gate_reads "the --auto block's marker" "$producer_auto"
mut=$(printf '%s' "$producer_10b" | sed 's/close-session-done:/close-session-finished:/')
setup; h=$(head_); stamp "$ME" "$h"
printf '%s\n' "$mut" | sed "s|{SID}|$ME|; s|{VHEAD}|$h|" >> "$NOTEF"
git -C "$TMP/home/aios" add note.md; git -C "$TMP/home/aios" commit -q -m "session: done" -m "AIOS-Session: $ME"
[ "$(verdict bash "$ME")" = resume ] \
  && ok "MUTANT: a renamed marker is not recognised (resume) — the two checks above are load-bearing" \
  || no "MUTANT: the gate accepted a renamed marker"

printf '\n  %d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
