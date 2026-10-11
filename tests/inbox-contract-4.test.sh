#!/usr/bin/env bash
# tests/inbox-contract-4.test.sh
#
# Contract 4 has two implementations outside this repo (the App and Glass) and one inside it (the
# spawn wrappers). The conformance fixture is what all of them run against, so it must parse, and
# the advisor rung table must say the same thing in the spec, the fixture and both wrappers. (A rung
# resolved through resolve-tier answers `judgment` with an empty string -- naming no advisor at all --
# which is how the first draft of the fixture went wrong.)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
D="$ROOT/skills/aios/orchestration-ladder"
PYBIN="${PYBIN:-python3}"
PASS=0; FAIL=0
ok(){ echo "  ✓ $1"; PASS=$((PASS+1)); }
no(){ echo "  ✗ $1"; [ -n "${2:-}" ] && echo "      $2"; FAIL=$((FAIL+1)); }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
# The checker goes to a file: bash 3.2 cannot parse a quoted heredoc inside $( ).
cat > "$T/check.py" <<'PY'
import json, re, sys
fx, spec, sh, ps = sys.argv[1:5]
d = json.load(open(fx, encoding="utf-8")); cases = d["cases"] if isinstance(d, dict) else d
bad = [c.get("case") for c in cases if not {"case", "request", "expect"} <= set(c)]
print("SHAPE", "ok" if not bad else "missing keys in: %s" % bad)
table = dict(re.findall(r"\|\s*`(frontier|judgment|scale|fast)`\s*\|\s*`([^`]+)`\s*\|", open(spec, encoding="utf-8").read()))
print("TABLE", "ok" if len(table) == 4 and all(table.values()) else "spec rung table incomplete: %s" % table)
shs = open(sh, encoding="utf-8").read(); pss = open(ps, encoding="utf-8").read()
m_sh = dict(re.findall(r"\b(frontier|judgment|scale|fast)\)\s+spawn_advisor='([^']+)'", shs))
m_ps = dict(re.findall(r"'(frontier|judgment|scale|fast)'\s*\{\s*'([^']+)'\s*\}", pss.split("$spawnAdvisor = switch")[1].split("}\n    }")[0] if "$spawnAdvisor = switch" in pss else ""))
print("SH", "ok" if m_sh == table else "sh %s != spec %s" % (m_sh, table))
print("PS", "ok" if m_ps == table else "ps1 %s != spec %s" % (m_ps, table))
rung = [c for c in cases if c["request"].get("advisor") in table]
wrong = [c["case"] for c in rung if c["expect"].get("advisor_model") != table[c["request"]["advisor"]]]
print("FIXTURE", "ok" if rung and not wrong else "rung cases disagree with the table: %s" % (wrong or "none present"))
PY
out=$($PYBIN "$T/check.py" "$D/inbox-contract-4.conformance.json" "$D/inbox-contract-4.md" "$ROOT/hooks/claude-identity/install-wrappers.sh" "$ROOT/hooks/claude-identity/install-wrappers.ps1")
while IFS= read -r line; do
  k="${line%% *}"; v="${line#* }"
  [ "$v" = ok ] && ok "$k agrees" || no "$k" "$v"
done <<< "$out"
echo "── RESULT: $PASS passed, $FAIL failed ──"
[ "$FAIL" = 0 ] && [ "$PASS" -ge 5 ]
