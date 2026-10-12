#!/usr/bin/env bash
# tests/ps1-encoding.test.sh
#
# Windows PowerShell 5.1 reads a .ps1 with no BOM in the machine's ANSI codepage (often 1252), so a
# UTF-8 character (a section sign, an em dash, a curly quote) becomes mojibake and can break the
# parse. The Windows CI lane checks this; this test runs the same rule on every machine, so it fails
# before a push instead of after. Rule: every tracked .ps1 is pure ASCII, or starts with a UTF-8 BOM.
set -u
cd "$(dirname "$0")/.." || exit 1
PASS=0; FAIL=0
ok(){ echo "  ✓ $1"; PASS=$((PASS+1)); }
no(){ echo "  ✗ $1"; [ -n "${2:-}" ] && echo "      $2"; FAIL=$((FAIL+1)); }
check(){ # prints the offending line numbers, or nothing
  [ "$(head -c3 "$1" | od -An -tx1 | tr -d ' \n')" = efbbbf ] && return 0
  LC_ALL=C grep -n '[^[:print:][:space:]]' "$1" | cut -d: -f1 | tr '\n' ' '
}
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
printf '# MODEL-ROUTING \302\247 x\r\n' > "$T/bad.ps1"
[ -n "$(check "$T/bad.ps1")" ] && ok "control: a BOM-less .ps1 with a section sign is caught" || no "control: the check sees nothing"
printf '\357\273\277# \302\247 ok\r\n' > "$T/bom.ps1"
[ -z "$(check "$T/bom.ps1")" ] && ok "control: the same text with a BOM passes" || no "control: a BOM file was flagged"
bad=""
while IFS= read -r f; do
  lines=$(check "$f"); [ -n "$lines" ] && bad="$bad $f (lines $lines)"
done < <(git ls-files '*.ps1')
[ -z "$bad" ] && ok "every tracked .ps1 is ASCII or carries a BOM" || no "non-ASCII without a BOM:" "$bad"
echo "── RESULT: $PASS passed, $FAIL failed ──"
[ "$FAIL" = 0 ]
