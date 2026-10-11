#!/usr/bin/env bash
# tests/no-grep-q-after-pipe.test.sh
#
# Under `set -o pipefail`, `writer | grep -q PAT` can fail on a MATCH: grep -q exits at the first
# hit, the writer gets SIGPIPE on its next write, and pipefail reports the writer's 141. The check
# then reads "not found" on some runs and not others (fortress-ladder flaked exactly this way). The
# house form is `writer | grep PAT >/dev/null`: same exit status, and grep reads to the end.
#
# The sweep converted every instance in the pipefail suites; this keeps the class closed. A mutant
# control runs first, so a scanner that matches nothing cannot pass.
set -u
cd "$(dirname "$0")/.." || exit 1
PASS=0; FAIL=0
ok(){ echo "  ✓ $1"; PASS=$((PASS+1)); }
no(){ echo "  ✗ $1"; [ -n "${2:-}" ] && echo "      $2"; FAIL=$((FAIL+1)); }
scan(){ grep -nE '\|[[:space:]]*grep([[:space:]]+-[A-Za-z]+)*[[:space:]]+-[A-Za-z]*q' "$1" | grep -vE '^[0-9]+:[[:space:]]*#' | grep -v '||'; }

T="$(mktemp)"; trap 'rm -f "$T"' EXIT
printf 'set -o pipefail\nprintf x | grep -%sF x && echo hit\n' q > "$T"
[ -n "$(scan "$T")" ] && ok "control: the scanner flags a planted 'printf | grep -qF'" || no "control: scanner flagged nothing"

bad=""
for f in tests/*.sh; do
  grep -q 'pipefail' "$f" || continue
  hits="$(scan "$f")"; [ -n "$hits" ] && bad="$bad
$f: $hits"
done
[ -z "$bad" ] && ok "no pipefail suite pipes into grep -q" || no "grep -q after a pipe (use 'grep PAT >/dev/null'):" "$bad"

echo "── RESULT: $PASS passed, $FAIL failed ──"
[ "$FAIL" = 0 ]
