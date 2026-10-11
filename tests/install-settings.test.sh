#!/usr/bin/env bash
# tests/install-settings.test.sh
#
# hooks/install-settings.py wires SETUP §10's universal hooks without asking a new operator to
# approve raw JSON. Asserts: it changes nothing without --apply; --apply adds every hook and keeps
# every other key; a second run changes nothing (byte-identical); an operator's own statusLine is
# never replaced; invalid JSON is refused untouched; and every command it writes is one SETUP §10
# prints, on both platforms -- so the helper and the manual reference cannot drift apart.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
H="$ROOT/hooks/install-settings.py"
PYBIN="${PYBIN:-python3}"
PASS=0; FAIL=0
ok(){ echo "  ✓ $1"; PASS=$((PASS+1)); }
no(){ echo "  ✗ $1"; [ -n "${2:-}" ] && echo "      $2"; FAIL=$((FAIL+1)); }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
S="$T/settings.json"
run(){ AIOS_ROOT="$T/aios" $PYBIN "$H" --settings "$S" "$@"; }
mkdir -p "$T/aios"

printf '{\n  "model": "x",\n  "permissions": {"allow": ["Bash(ls:*)"]}\n}\n' > "$S"
cp "$S" "$T/orig.json"
out=$(run --platform posix)
cmp -s "$S" "$T/orig.json" && ok "without --apply nothing is written" || no "dry run changed the file"
case "$out" in *"+ add   A"*"+ add   D"*"+ add   E"*"+ add   F"*"+ add   B"*) ok "the summary lists A, B, D, E, F in plain language" ;; *) no "summary incomplete" "$out" ;; esac
case "$out" in *'"hooks"'*|*'"command"'*) no "the summary shows raw JSON" ;; *) ok "the summary shows no JSON" ;; esac

run --platform posix --apply >/dev/null; rc=$?
[ "$rc" = 0 ] && ok "--apply exits 0 after verifying its own write" || no "--apply exit $rc"
$PYBIN - "$S" <<'PY' && ok "every hook present, statusLine set, existing keys kept" || no "merged file wrong" "$(cat "$S")"
import json,sys
d=json.load(open(sys.argv[1]))
h=d["hooks"]; cmds=json.dumps(h)
need=["inject-datetime.sh","provenance.py --prompt","bus_log.py --hook","provenance.py --tool","floor-at-start.py","model-switch-log.py"]
assert all(n in cmds for n in need), cmds
assert d["model"]=="x" and d["permissions"]["allow"]==["Bash(ls:*)"]
assert "claude-identity.sh cache" in d["statusLine"]["command"]
assert "guard-venture-mount" not in cmds  # no company mounted
PY
ls "$T"/settings.json.bak-aios-* >/dev/null 2>&1 && ok "the previous file was backed up" || no "no backup written"
cp "$S" "$T/once.json"; out=$(run --platform posix --apply)
cmp -s "$S" "$T/once.json" && case "$out" in *"Nothing to change"*) ok "a second run changes nothing" ;; *) no "second run did something" "$out" ;; esac || no "second run altered the file"

printf '{"statusLine": {"type": "command", "command": "my-own-line"}}\n' > "$S"
out=$(run --platform posix --apply)
grep '"my-own-line"' "$S" >/dev/null && ok "an operator's own statusLine is kept" || no "statusLine replaced"
case "$out" in *"! note  B"*) ok "and the summary says what that costs" ;; *) no "no note about the kept statusLine" "$out" ;; esac

printf '{ not json' > "$S"; cp "$S" "$T/bad.json"
run --platform posix --apply >/dev/null; rc=$?
[ "$rc" = 1 ] && cmp -s "$S" "$T/bad.json" && ok "invalid JSON is refused and left untouched" || no "invalid JSON handling (rc=$rc)"

mkdir -p "$T/aios/vault/00 - notes/context/ventures/acme"; : > "$T/aios/vault/00 - notes/context/ventures/acme/.acme-sync"
rm -f "$S"; run --platform posix --apply >/dev/null
grep 'guard-venture-mount' "$S" >/dev/null && ok "a mounted company brings in the venture guard (C)" || no "venture guard not added with a mount"

rm -f "$S"; printf '{}' > "$S"; chmod 600 "$S"; run --platform posix --apply >/dev/null
perm=$($PYBIN -c 'import os,sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$S")
[ "$perm" = "0o600" ] && ok "a 0600 settings.json stays 0600 after --apply" || no "permissions loosened to $perm"
rm -f "$S"; run --platform posix --apply >/dev/null
perm=$($PYBIN -c 'import os,sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$S")
[ "$perm" = "0o600" ] && ok "a new settings.json is created 0600" || no "new file created $perm"

echo "── parity: every command written is one SETUP §10 prints ──"
for plat in posix windows; do
  rm -f "$S"; AIOS_WIN_PYTHON=python AIOS_ROOT="C:/Users/<you>/aios" $PYBIN "$H" --settings "$S" --platform $plat --apply >/dev/null
  missing=$($PYBIN - "$S" "$ROOT/SETUP.md" <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); setup=open(sys.argv[2],encoding="utf-8").read()
cmds=[hk["command"] for groups in d["hooks"].values() for g in groups for hk in g["hooks"]]+[d["statusLine"]["command"]]
for c in cmds:
    if json.dumps(c)[1:-1] not in setup: print(c)
PY
)
  [ -z "$missing" ] && ok "$plat: all commands match SETUP §10 verbatim" || no "$plat: commands SETUP does not print" "$missing"
done

echo "── RESULT: $PASS passed, $FAIL failed ──"
[ "$FAIL" = 0 ]
