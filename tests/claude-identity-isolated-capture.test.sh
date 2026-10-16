#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# `--capture` from an isolated config dir saves the NEW account's credential,
# never the active one's.
#
# WHY. The documented way to add an account on macOS is to /login with
# CLAUDE_CONFIG_DIR pointing at an isolated dir, then `--capture` from there.
# Claude Code keeps that login in its own Keychain item, named
# `Claude Code-credentials-<first 8 hex of sha256(dir)>`, while the capture read
# the unsuffixed item -- the ACTIVE account's. It saved that credential under
# the new account's email, with no error, and every later switch to the new
# account logged in as the old one.
#
# Runs the SHIPPED script with a `uname` shim (Darwin) and a fake `security`
# that keeps each Keychain item in a file and logs which item was asked for.
# The real Keychain is never touched, so it runs on any CI runner.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) echo "SKIP: POSIX shims" >&2; exit 0 ;; esac
I="$(pwd)/hooks/claude-identity/claude-identity.sh"
FS="$(pwd)/hooks/claude-identity"
[ -f "$I" ] || { echo "::error::$I missing"; exit 1; }

S=$(mktemp -d)
trap 'rm -rf "$S"' EXIT
A=a@example.com; B=b@example.com
ISO="$S/acct-2"

sha8() {  # independent of the code under test: openssl or shasum, not Python
  if command -v openssl >/dev/null 2>&1; then printf '%s' "$1" | openssl dgst -sha256 | awk '{print substr($NF,1,8)}'
  else printf '%s' "$1" | shasum -a 256 | cut -c1-8; fi
}
SUFFIXED="Claude Code-credentials-$(sha8 "$ISO")"

fixture() {  # seat A active (unsuffixed item); B logged in to $ISO (suffixed item)
  rm -rf "$S/home" "$S/bin" "$S/kc" "$ISO"; mkdir -p "$S/home/.claude" "$S/bin" "$S/kc" "$ISO"
  printf '#!/bin/sh\necho Darwin\n' > "$S/bin/uname"
  cat > "$S/bin/security" <<'SHIM'
#!/bin/sh
# fake Keychain: one file per service under $KC; every lookup is logged
op=$1; shift; svc=""; pw=""; want_pw=0
while [ $# -gt 0 ]; do case "$1" in
  -s) svc=$2; shift 2 ;; -w) if [ "$op" = add-generic-password ]; then pw=$2; shift 2; else want_pw=1; shift; fi ;;
  -a) shift 2 ;; *) shift ;; esac; done
printf '%s %s\n' "$op" "$svc" >> "$KC/log"
case "$op" in
  find-generic-password) [ -f "$KC/$svc" ] || exit 44; cat "$KC/$svc" ;;
  add-generic-password)  printf '%s' "$pw" > "$KC/$svc" ;;
  delete-generic-password) rm -f "$KC/$svc" ;;
esac
SHIM
  chmod +x "$S/bin/uname" "$S/bin/security"
  printf '{"oauthAccount":{"emailAddress":"%s"},"userID":"uid-a"}' "$A" > "$S/home/.claude.json"
  printf '{"oauthAccount":{"emailAddress":"%s"},"userID":"uid-b"}' "$B" > "$ISO/.claude.json"
  printf '{"claudeAiOauth":{"accessToken":"tok-a","refreshToken":"ref-a"}}' > "$S/kc/Claude Code-credentials"
  printf '{"claudeAiOauth":{"accessToken":"tok-b","refreshToken":"ref-b"}}' > "$S/kc/$SUFFIXED"
  printf '## Anthropic accounts\n\n1. `%s`\n2. `%s`\n' "$A" "$B" > "$S/USER.md"
}
run() {  # run <env...> -- <args...>
  local envs=()
  while [ "$1" != "--" ]; do envs+=("$1"); shift; done; shift
  env -u CLAUDE_CONFIG_DIR -u CLAUDE_SECURESTORAGE_CONFIG_DIR -u AIOS_KEYCHAIN_SERVICE \
    PATH="$S/bin:$PATH" HOME="$S/home" KC="$S/kc" USER_MD_PATH="$S/USER.md" "${envs[@]}" \
    bash "$I" "$@"
}
saved() { cat "$1/identities/$2/keychain.json" 2>/dev/null; }

echo "-- 0. control: the old reading (unsuffixed item) reproduces the failure --"
fixture
run CLAUDE_CONFIG_DIR="$ISO" AIOS_KEYCHAIN_SERVICE="Claude Code-credentials" -- switch --capture > "$S/out" 2>&1
saved "$ISO" "$B" | grep tok-a >/dev/null && ok "control: reading the unsuffixed item saves A's credential as B's" \
  || no "control did not reproduce the failure" "without it the checks below prove nothing: $(cat "$S/out")"

echo "-- 1. the item name follows Claude Code's rule --"
fixture
run CLAUDE_CONFIG_DIR="$ISO" -- switch --capture > "$S/out" 2>&1; rc=$?
[ "$rc" = 0 ] && saved "$ISO" "$B" | grep tok-b >/dev/null && ok "capture from an isolated dir saves B's own credential" \
  || no "isolated capture → exit $rc" "$(cat "$S/out"); saved: $(saved "$ISO" "$B")"
grep -qx "find-generic-password $SUFFIXED" "$S/kc/log" && ok "it read the suffixed item, sha256 computed independently" \
  || no "wrong item read" "$(cat "$S/kc/log")"
py=$(cd "$FS" && env -u CLAUDE_SECURESTORAGE_CONFIG_DIR -u AIOS_KEYCHAIN_SERVICE CLAUDE_CONFIG_DIR="$ISO" python3 -c 'import _fs; print(_fs.keychain_service())')
[ "$py" = "$SUFFIXED" ] && ok "_fs.keychain_service() names the same item" || no "_fs disagrees" "got '$py', want '$SUFFIXED'"
grep -q "cp -Rp" "$S/out" && ok "it says how to add the identity to ~/.claude/identities" || no "no copy hint" "$(cat "$S/out")"

echo "-- 2. operators without CLAUDE_CONFIG_DIR keep the item they have --"
fixture
run -- switch --capture > "$S/out" 2>&1; rc=$?
[ "$rc" = 0 ] && saved "$S/home/.claude" "$A" | grep tok-a >/dev/null && grep -qx "find-generic-password Claude Code-credentials" "$S/kc/log" \
  && ok "unset CLAUDE_CONFIG_DIR reads the unsuffixed item" || no "default capture → exit $rc" "$(cat "$S/out"); $(cat "$S/kc/log")"
! grep -q "cp -Rp" "$S/out" && ok "no copy hint for the default dir" || no "copy hint on the default dir"
fixture
run CLAUDE_CONFIG_DIR="" -- switch --capture > "$S/out" 2>&1
grep -qx "find-generic-password Claude Code-credentials" "$S/kc/log" && ok "an empty CLAUDE_CONFIG_DIR is unsuffixed too" \
  || no "empty CLAUDE_CONFIG_DIR" "$(cat "$S/kc/log")"
py=$(cd "$FS" && env -u CLAUDE_CONFIG_DIR -u CLAUDE_SECURESTORAGE_CONFIG_DIR -u AIOS_KEYCHAIN_SERVICE python3 -c 'import _fs; print(_fs.keychain_service())')
[ "$py" = "Claude Code-credentials" ] && ok "_fs agrees on the default" || no "_fs default" "got '$py'"

echo "-- 3. CLAUDE_SECURESTORAGE_CONFIG_DIR replaces CLAUDE_CONFIG_DIR in the rule --"
fixture
run CLAUDE_CONFIG_DIR="$ISO" CLAUDE_SECURESTORAGE_CONFIG_DIR="" -- switch --capture > "$S/out" 2>&1
grep -qx "find-generic-password Claude Code-credentials" "$S/kc/log" && ok "set but empty → unsuffixed" \
  || no "securestorage empty" "$(cat "$S/kc/log")"
fixture
run CLAUDE_CONFIG_DIR="$S/home/.claude" CLAUDE_SECURESTORAGE_CONFIG_DIR="$ISO" -- switch --capture > "$S/out" 2>&1
grep -qx "find-generic-password $SUFFIXED" "$S/kc/log" && ok "set → hashed instead of CLAUDE_CONFIG_DIR" \
  || no "securestorage set" "$(cat "$S/kc/log")"
py=$(cd "$FS" && env -u AIOS_KEYCHAIN_SERVICE CLAUDE_CONFIG_DIR=/elsewhere CLAUDE_SECURESTORAGE_CONFIG_DIR="$ISO" python3 -c 'import _fs; print(_fs.keychain_service())')
[ "$py" = "$SUFFIXED" ] && ok "_fs agrees" || no "_fs securestorage" "got '$py'"

echo "-- 4. a credential already saved under another email is refused --"
fixture
run -- switch --capture > /dev/null 2>&1                       # A captured in the default dir
run CLAUDE_CONFIG_DIR="$ISO" AIOS_KEYCHAIN_SERVICE="Claude Code-credentials" -- switch --capture > "$S/out" 2>&1; rc=$?
[ "$rc" != 0 ] && [ ! -f "$ISO/identities/$B/keychain.json" ] && grep -q "already saved as $A" "$S/out" \
  && ok "A's credential is not saved as B's, even from another config dir" \
  || no "twin credential → exit $rc" "$(cat "$S/out"); saved: $(saved "$ISO" "$B")"
run -- switch --capture > "$S/out" 2>&1; rc=$?
[ "$rc" = 0 ] && ok "re-capturing the same account still works" || no "self re-capture → exit $rc" "$(cat "$S/out")"

echo "-- 4b. a copy left by an earlier bad capture never stops a rotation --"
C=c@example.com
fixture                                                         # A is the seat, never captured
mkdir -p "$S/home/.claude/identities/$B" "$S/home/.claude/identities/$C"
cp "$S/kc/Claude Code-credentials" "$S/home/.claude/identities/$B/keychain.json"   # B holds A's credential
printf '{"emailAddress":"%s"}' "$B" > "$S/home/.claude/identities/$B/oauthAccount.json"; echo uid-b > "$S/home/.claude/identities/$B/userID.txt"
printf '{"claudeAiOauth":{"accessToken":"tok-c","refreshToken":"ref-c"}}' > "$S/home/.claude/identities/$C/keychain.json"
printf '{"emailAddress":"%s"}' "$C" > "$S/home/.claude/identities/$C/oauthAccount.json"; echo uid-c > "$S/home/.claude/identities/$C/userID.txt"
printf '## Anthropic accounts\n\n1. `%s`\n2. `%s`\n3. `%s`\n' "$A" "$B" "$C" > "$S/USER.md"
run -- switch "$C" > "$S/out" 2>&1; rc=$?
[ "$rc" = 0 ] && grep -q tok-c "$S/kc/Claude Code-credentials" && grep -q "$C" "$S/home/.claude.json" \
  && ok "A -> C rotates although B holds a copy of A's credential" \
  || no "rotation with an inherited duplicate → exit $rc" "$(cat "$S/out")"
run -- switch "$A" > /dev/null 2>&1                            # back to A
run -- switch --capture > "$S/out" 2>&1; rc=$?
[ "$rc" = 0 ] && grep -q "$B" "$S/out" && saved "$S/home/.claude" "$A" | grep tok-a >/dev/null \
  && ok "re-capturing A succeeds and names B as the stale copy" \
  || no "re-capture of A with a stale twin → exit $rc" "$(cat "$S/out")"

echo "-- 4c. an identity that exists but cannot be read stops the capture --"
if [ "$(id -u)" = 0 ]; then echo "  skip (root reads mode-000 files)"; else
fixture
run -- switch --capture > /dev/null 2>&1
chmod 000 "$S/home/.claude/identities/$A/keychain.json"
run CLAUDE_CONFIG_DIR="$ISO" AIOS_KEYCHAIN_SERVICE="Claude Code-credentials" -- switch --capture > "$S/out" 2>&1; rc=$?
chmod 600 "$S/home/.claude/identities/$A/keychain.json"
[ "$rc" != 0 ] && [ ! -f "$ISO/identities/$B/keychain.json" ] && grep -q "cannot read" "$S/out" \
  && ok "an unreadable identity is an error, not a skipped comparison" \
  || no "unreadable identity → exit $rc" "$(cat "$S/out"); saved: $(saved "$ISO" "$B")"
fi

echo "-- 5. a missing item fails closed --"
fixture
rm -f "$S/kc/$SUFFIXED"
run CLAUDE_CONFIG_DIR="$ISO" -- switch --capture > "$S/out" 2>&1; rc=$?
[ "$rc" != 0 ] && [ ! -f "$ISO/identities/$B/keychain.json" ] && grep -q "$SUFFIXED" "$S/out" \
  && ok "no item → refused, nothing saved, and the error names the item" \
  || no "missing item → exit $rc" "$(cat "$S/out")"

echo
echo "claude-identity-isolated-capture: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
