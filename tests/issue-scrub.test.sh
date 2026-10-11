#!/usr/bin/env bash
# tests/issue-scrub.test.sh
#
# hooks/issue-scrub.py is the last thing between an operator's vault and a public GitHub issue.
# A scrubber that misses a name fails silently: the issue reads fine and is public forever. One
# that over-redacts fails loudly but gets bypassed, because nobody files an issue whose commands
# and file names were replaced with placeholders. So this suite proves BOTH directions:
#
#   1. the planted-name test: build a fake vault (session name, company, client, a contact, the
#      operator's own name and aliases, a private sentence), plant every one of them -- plus home
#      paths, vault paths, vault wikilinks, emails, ids and a token -- into a report, and assert
#      NONE survives;
#   2. the positive control: ordinary technical text (framework paths, commands, a SHA, versions,
#      dates, a framework wikilink, template-example names) passes through byte-identical.
# Plus the contract: --check exit codes, a missing file exits 2, the report line names its counts.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
H="$ROOT/hooks/issue-scrub.py"
PYBIN="${PYBIN:-python3}"
PASS=0; FAIL=0
ok(){ echo "  ✓ $1"; PASS=$((PASS+1)); }
no(){ echo "  ✗ $1"; [ -n "${2:-}" ] && echo "      $2"; FAIL=$((FAIL+1)); }
T="$(mktemp -d "${TMPDIR:-/tmp}/issue-scrub.XXXXXX")" &&[ -d "$T" ] || { echo "cannot create a temp dir"; exit 1; }
trap 'rm -rf "$T"' EXIT
export PYTHONPYCACHEPREFIX="$T/pyc"

# ── a fake operator root: USER.md + vault context + one framework agent ──
F="$T/root"; V="$F/vault/00 - notes"
mkdir -p "$V/context/declared" "$V/context/observed" "$V/context/ventures/northwind-labs" \
         "$V/projects" "$F/agents/aios/engineering"
cat > "$F/USER.md" <<'EOF'
# USER.md

## Identity

| Name | Role | Greeting style |
|------|------|----------------|
| `maplewood` | My main session | Warm |
| *`acmebot`* | *Example row* | *ignore* |

## Companies (mounted)

| Company | Substrate | Source | Venture folder | Last sync |
|---|---|---|---|---|
| northwind-labs | github | git@github.com:northwind-labs/ctx.git | ventures/northwind-labs/ | 2026-10-01 |
| *acme-co* | *github* | *example* | *example* | *2026-05-21* |

## Settings
EOF
cat > "$V/context/declared/about_me.md" <<'EOF'
---
tags: [context, declared, identity]
aliases:
  - "Rosalind"
  - "rozzyq"
---
# about_me.md

## Quick identity
My name is Rosalind Quillfeather.
EOF
cat > "$V/context/observed/ecosystem.md" <<'EOF'
# Ecosystem

### Tomasz Wierzbicki
Advisor on the logistics venture.
EOF
cat > "$V/context/observed/growth.md" <<'EOF'
# Growth

### Avoidance
She keeps postponing the quarterly pricing conversation with the board because it feels like admitting the launch slipped.
EOF
: > "$V/projects/advisory-bluefin-dental.md"
: > "$V/projects/space-orchard-guild.md"
: > "$F/agents/aios/engineering/bug-triager.md"

# Token-shaped strings are assembled at runtime so this file never carries one literally
# (hooks/git/secret-scan.sh would rightly refuse to commit it).
SLACK_TOK="xox""b-1234567890-abcdefghijkl"
DRIVE_ID="1AbC""dEfGhIjKlMnOpQrStUvWxYz0123456789"

# ── 1. the planted-name test ──
cat > "$T/dirty.md" <<EOF
## What happened
Running /aios:close-session as maplewood for Rosalind Quillfeather at northwind-labs failed.
Reported by rozzyq, also seen by Tomasz Wierzbicki on the bluefin-dental engagement (orchard-guild space).
Path: /Users/rquill/aios/hooks/clip and C:\\Users\\rquill\\aios\\hooks\\clip
Note: vault/00 - notes/context/observed/growth.md and ~/aios/vault/01 - calendar/2026-10/2026-10-11.md
Links: [[advisory-bluefin-dental]] and [[growth]]
Contact rosalind@northwind.example or ping D0ABC12345 / C0XYZ98765.
Doc: https://docs.google.com/document/d/$DRIVE_ID/edit
Bare id $DRIVE_ID and token $SLACK_TOK and api_key=sup3rs3cretvalue
Call +1 415 555 0134. ASIN B0CQ12XYZ9.
> She keeps postponing the quarterly pricing conversation with the board because it feels like admitting the launch slipped.
EOF
out="$($PYBIN "$H" --root "$F" "$T/dirty.md" 2>"$T/err")"; rc=$?
[ "$rc" = 0 ] && ok "scrub exits 0" || no "scrub exit $rc" "$(cat "$T/err")"
# Fail-closed guard: an empty output would "remove" every planted name and pass the loop below.
case "$out" in *"What happened"*"Running /aios:close-session"*) ok "output is the scrubbed report, not empty" ;;
  *) no "output missing or truncated -- every check below would pass vacuously" "$out" ;; esac
for planted in maplewood "Rosalind" Quillfeather rozzyq northwind-labs "northwind labs" Wierzbicki Tomasz \
               bluefin-dental orchard-guild rquill "00 - notes" "01 - calendar" "[[advisory-" "[[growth]]" \
               "rosalind@" D0ABC12345 C0XYZ98765 docs.google.com "$DRIVE_ID" "$SLACK_TOK" sup3rs3cretvalue \
               "555 0134" B0CQ12XYZ9 "quarterly pricing conversation"; do
  if printf '%s' "$out" | grep -i -F -- "$planted" >/dev/null; then
    no "planted '$planted' survived" "$(printf '%s' "$out" | grep -i -F -- "$planted")"
  else
    ok "planted '$planted' removed"
  fi
done
case "$out" in *"~/aios/hooks/clip"*) ok "home path becomes ~/..., the framework path stays" ;; *) no "home path not rewritten to ~" "$out" ;; esac
case "$out" in *"<vault path redacted>"*"<vault link redacted>"*) ok "vault paths and links get visible placeholders" ;; *) no "placeholders missing" "$out" ;; esac
case "$out" in *"the primary session"*"the operator"*"a company"*) ok "names become roles, not blanks" ;; *) no "role placeholders missing" "$out" ;; esac
case "$out" in *"a client"*) ok "an advisory-* project reads as a client" ;; *) no "client role missing" "$out" ;; esac
case "$(cat "$T/err")" in *"issue-scrub: redacted:"*"names loaded:"*) ok "report line names its counts and the names loaded" ;; *) no "report line malformed" "$(cat "$T/err")" ;; esac
$PYBIN "$H" --root "$F" --check "$T/dirty.md" 2>/dev/null; rc=$?
[ "$rc" = 1 ] && ok "--check exits 1 on a dirty draft" || no "--check on dirty exit $rc"
printf '%s' "$out" > "$T/scrubbed.md"
$PYBIN "$H" --root "$F" --check "$T/scrubbed.md" 2>"$T/err2"; rc=$?
[ "$rc" = 0 ] && ok "scrubbed output re-checks clean (idempotent)" || no "scrubbed output still dirty (rc $rc)" "$($PYBIN "$H" --root "$F" --check --show-removed "$T/scrubbed.md" 2>&1)"

echo "── extra terms the vault does not hold ──"
out2="$(printf 'Paired with Zebulon Marsh on this.\n' | $PYBIN "$H" --root "$F" --term "Zebulon Marsh" 2>/dev/null)"
case "$out2" in *Zebulon*) no "--term name survived" "$out2" ;; *) ok "--term names are removed" ;; esac

# ── 2. the positive control: ordinary technical text survives untouched ──
cat > "$T/clean.md" <<'EOF'
## fix(close-session): step 4.5 gate skips a second block

**Repro** (macOS 15, AIOS 0.8.7, Claude Code 2.1.296):
1. `bash tests/close-session-idempotency.test.sh` passes.
2. Run `/aios:close-session --auto` twice; `ps -p 4242 -o command=` shows the flag.
3. `LANG=en_US.UTF-8 pbcopy < hooks/clip` arrives intact (control).

Files: plugins/aios/commands/close-session.md, hooks/aios-commit, CLAUDE.md, SETUP.md, CHANGELOG.
Commit 620088be1f3a9c2d4e5b6a7c8d9e0f1a2b3c4d5e on 2026-10-11 at 21:40; see [[bug-triager]].
The UTF-8 locale and the acme-co template row are fine. Session id 3f2a9c1e-4b5d-4e6f-8a7b-9c0d1e2f3a4b.
EOF
outc="$($PYBIN "$H" --root "$F" "$T/clean.md" 2>"$T/errc")"
if [ "$outc" = "$(cat "$T/clean.md")" ]; then ok "technical text passes through byte-identical"
else no "the control was altered" "$(diff <(printf '%s\n' "$outc") "$T/clean.md" | head -8)"; fi
$PYBIN "$H" --root "$F" --check "$T/clean.md" 2>/dev/null; rc=$?
[ "$rc" = 0 ] && ok "--check exits 0 on clean text" || no "--check on clean exit $rc"
case "$(cat "$T/errc")" in *"redacted: 0 normalised, 0 paths, 0 vault paths, 0 vault links, 0 vault quotes, 0 names"*) ok "clean text reports zero redactions" ;; *) no "clean text reported redactions" "$(cat "$T/errc")" ;; esac

echo "── contract ──"
$PYBIN "$H" --root "$F" "$T/does-not-exist.md" >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && ok "missing input file exits 2" || no "missing file exit $rc"
j="$($PYBIN "$H" --root "$F" --json "$T/dirty.md" 2>&1 >/dev/null)"
$PYBIN -c 'import json,sys; d=json.loads(sys.argv[1]); sys.exit(0 if d["redacted"]["names"]>0 and d["names_loaded"]>0 and d["quote_check"] else 1)' "$j" \
  && ok "--json report parses and counts names" || no "--json report wrong" "$j"
e="$(printf 'nothing here\n' | $PYBIN "$H" --root "$T/empty-root" 2>&1 >/dev/null)"
case "$e" in *"no private context files found"*) ok "an empty root says the quote check had nothing to read" ;; *) no "empty root was silent about missing context" "$e" ;; esac
u="$(printf 'caf\303\251 \342\200\224 na\303\257ve\n' | $PYBIN "$H" --root "$F" 2>/dev/null)"
[ "$u" = "$(printf 'caf\303\251 \342\200\224 na\303\257ve')" ] && ok "UTF-8 text round-trips" || no "UTF-8 mangled" "$u"

echo "── names written the way GitHub renders them, not the way a regex reads them ──"
# The security review's bypass class: text that renders as a name on GitHub while matching no
# pattern -- a zero-width character inside it, HTML entities, intraword emphasis, fullwidth letters.
for v in "Z&amp;#101;dekiah" "Z$(printf '\357\274\206')#101;dekiah" "Zede[](https://x.y)kiah" "Zede<b></b>kiah" "Zede<!-- -->kiah" "Zed$(printf '\342\200\213')ekiah" "Z&#101;dekiah" "Zede**kiah**" "$(printf '\357\274\272')edekiah"; do
  out=$(printf 'reported by %s today\n' "$v" | $PYBIN "$H" --root "$F" --term Zedekiah 2>/dev/null)
  case "$out" in *edekiah*|*kiah*) no "a rendered name survived: $(printf '%s' "$v" | od -c | head -1)" "$out" ;; *) ok "redacted: $(printf '%s' "$v" | LC_ALL=C tr -c '[:print:]' '?')" ;; esac
done

# The other side of the same rule: a name STORED in another form (decomposed accents) must still
# match the normalised draft.
out=$(printf 'thanks to Jos\303\251 for the repro\n' | $PYBIN "$H" --root "$F" --term "$(printf 'Jose\314\201')" 2>/dev/null)
case "$out" in *Jos*) no "a name stored decomposed (NFD) did not match the composed text" "$out" ;; *) ok "a name stored decomposed still matches the composed draft" ;; esac

# Idempotence on hostile input: scrubbing the output again must change nothing.
printf 'by Z&amp;#101;dekiah and Zede**kiah** at /Users/someone/aios\n' > "$T/hostile.md"
o1=$($PYBIN "$H" --root "$F" --term Zedekiah "$T/hostile.md" 2>/dev/null); o2=$(printf '%s\n' "$o1" | $PYBIN "$H" --root "$F" --term Zedekiah 2>/dev/null)
[ "$o1" = "$o2" ] && ok "scrubbing the scrubbed output changes nothing" || no "not idempotent" "$o1 | $o2"

echo "── RESULT: $PASS passed, $FAIL failed ──"
[ "$FAIL" = 0 ]
