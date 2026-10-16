#!/usr/bin/env bash
# tests/release-new-command.test.sh
#
# A release that adds a command must tell EXISTING vaults to add its `### /{cmd}` section to
# USER.md. A fresh clone gets the section from the template; an installed vault only ever gets
# what a CHANGELOG action tells its session to do, because /aios:update never writes USER.md.
# v0.8.12 nearly shipped /prospect without that action, and nothing would have said so.
#
# The rule: every plugins/aios/commands/*.md ADDED since the last tag is named as `### /{cmd}`
# in the newest CHANGELOG entry (the one that ships it). Proven on a throwaway repo first, so the
# check is known to fire, then run on this repo when a tag is reachable.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }

# Prints one line per added command the newest CHANGELOG entry does not name. Empty = fine.
# Exit 2 when there is no tag to compare against (nothing measured).
missing(){
  local repo=$1 tag added entry c
  tag=$(git -C "$repo" describe --tags --abbrev=0 HEAD 2>/dev/null) || return 2
  added=$(git -C "$repo" diff --name-only --diff-filter=A "$tag"..HEAD -- 'plugins/aios/commands/*.md' \
    | sed -n 's#^plugins/aios/commands/\([^/]*\)\.md$#\1#p' | grep -v '^_')
  entry=$(awk '/^## [0-9]{4}-[0-9]{2}-[0-9]{2}/{n++} n==1' "$repo/CHANGELOG.md")
  printf '%s\n' "$added" | while IFS= read -r c; do
    [ -n "$c" ] || continue
    printf '%s\n' "$entry" | grep -qF "### /$c" || echo "$c"
  done
}

echo "── the rule fires on a throwaway repo ──"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
g(){ git -C "$T" "$@" >/dev/null 2>&1; }
g init -q; g config user.email t@t; g config user.name t
mkdir -p "$T/plugins/aios/commands"
printf 'old\n' > "$T/plugins/aios/commands/old.md"
printf '## 2026-01-01 — first\n\nnothing\n' > "$T/CHANGELOG.md"
g add -A; g commit -qm one; g tag v0.0.1
printf 'new\n' > "$T/plugins/aios/commands/newcmd.md"
printf '## 2026-01-02 — second\n\nadds a command, forgets existing vaults\n\n## 2026-01-01 — first\n' > "$T/CHANGELOG.md"
g add -A; g commit -qm two
out=$(missing "$T"); [ "$out" = "newcmd" ] && ok "a new command with no ### /{cmd} action is reported" || no "the missing action was not reported" "$out"
printf '## 2026-01-02 — second\n\n1. Add `### /newcmd` to USER.md if missing.\n\n## 2026-01-01 — first\n' > "$T/CHANGELOG.md"
g add -A; g commit -qm three
out=$(missing "$T"); [ -z "$out" ] && ok "naming ### /{cmd} in the newest entry satisfies it" || no "a named command still reported" "$out"
printf 'edit\n' >> "$T/plugins/aios/commands/old.md"; printf 'x\n' > "$T/plugins/aios/commands/_index.md"
g add -A; g commit -qm four
out=$(missing "$T"); [ -z "$out" ] && ok "an edited command and an _index file are not new commands" || no "a non-new file was required" "$out"
T2="$(mktemp -d)"; git -C "$T2" init -q
missing "$T2" >/dev/null; [ $? = 2 ] && ok "no tag: the check says it measured nothing (exit 2), never passes silently" || no "a tagless repo read as passing"
rm -rf "$T2"

echo "── this repo, since its last tag ──"
out=$(missing "$ROOT"); rc=$?
if [ $rc = 2 ]; then
  echo "  - skip: no tag reachable (shallow clone); CI runs this in the full-history job"
else
  [ -z "$out" ] && ok "every command added since $(git -C "$ROOT" describe --tags --abbrev=0 HEAD) has its USER.md action" \
    || no "commands added since the last tag with no ### /{cmd} action in the newest CHANGELOG entry" "$(echo $out)"
fi

echo
printf -- '-- %d passed, %d failed --\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
