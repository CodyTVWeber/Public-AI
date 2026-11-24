#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib.sh"
new_tmp
unset PRIVACY_REQUIRE_PATTERNS

repo="$TMPROOT/repo"
new_repo "$repo"
mkdir -p "$repo/scripts"
cp "$here/../check-privacy.sh" "$here/../install-hooks.sh" "$repo/scripts/"
: > "$repo/.privacyallow"
ticket="AB""C-12"

out="$(cd "$repo" && scripts/install-hooks.sh 2>&1)"; assert_rc "install ok" 0 $?
for h in pre-commit commit-msg; do
  [ -x "$repo/.git/hooks/$h" ] && ok || bad "$h installed and executable"
done
assert_contains "commit-msg wired" "$(cat "$repo/.git/hooks/commit-msg")" 'check-privacy.sh" --message "$1"'

out="$(cd "$repo" && scripts/install-hooks.sh 2>&1)"; assert_rc "reinstall ok" 0 $?
[ ! -e "$repo/.git/hooks/pre-commit.bak" ] && ok || bad "own hook not backed up on reinstall"

printf 'plain note\n' > "$repo/ok.txt"
git -C "$repo" add -- ok.txt
out="$(git -C "$repo" commit -m 'docs: add note' 2>&1)"; assert_rc "clean commit passes" 0 $?

printf 'see %s\n' "$ticket" > "$repo/bad.txt"
git -C "$repo" add -- bad.txt
out="$(git -C "$repo" commit -m 'docs: second note' 2>&1)"; rc=$?
assert_rc "pre-commit blocks bad content" 1 $rc
assert_contains "block names rule" "$out" "ticket id"
git -C "$repo" reset -q -- bad.txt; rm -f "$repo/bad.txt"

printf 'more\n' >> "$repo/ok.txt"
git -C "$repo" add -- ok.txt
out="$(git -C "$repo" commit -m "docs: mention $ticket" 2>&1)"; rc=$?
assert_rc "commit-msg blocks bad message" 1 $rc
assert_contains "message block reports location" "$out" "message:1"

repo2="$TMPROOT/repo2"
new_repo "$repo2"
mkdir -p "$repo2/scripts" "$repo2/.git/hooks"
cp "$here/../check-privacy.sh" "$here/../install-hooks.sh" "$repo2/scripts/"
printf '#!/bin/sh\necho foreign-ran >&2\n' > "$repo2/.git/hooks/pre-commit"
chmod +x "$repo2/.git/hooks/pre-commit"
out="$(cd "$repo2" && scripts/install-hooks.sh 2>&1)"; assert_rc "install over foreign hook" 0 $?
assert_contains "backup announced" "$out" "pre-commit.bak"
assert_contains "backup kept foreign content" "$(cat "$repo2/.git/hooks/pre-commit.bak")" "foreign-ran"
printf 'x\n' > "$repo2/f.txt"
git -C "$repo2" add -- f.txt
out="$(git -C "$repo2" commit -m 'docs: x' 2>&1)"; assert_contains "foreign hook still runs" "$out" "foreign-ran"

printf '#!/bin/sh\necho other\n' > "$repo2/.git/hooks/commit-msg"
printf '#!/bin/sh\necho older\n' > "$repo2/.git/hooks/commit-msg.bak"
out="$(cd "$repo2" && scripts/install-hooks.sh 2>&1)"; assert_rc "refuses to clobber when .bak taken" 3 $?
assert_contains "foreign commit-msg untouched" "$(cat "$repo2/.git/hooks/commit-msg")" "other"

repo3="$TMPROOT/repo3"
new_repo "$repo3"
mkdir -p "$repo3/scripts/clean-code"
cp "$here/../check-privacy.sh" "$here/../install-hooks.sh" "$repo3/scripts/"
: > "$repo3/.privacyallow"
printf '#!/usr/bin/env bash\necho clean-code-ran >&2\nexit 1\n' > "$repo3/scripts/clean-code/check-clean-code.sh"
printf '#!/usr/bin/env bash\nexit 1\n' > "$repo3/scripts/clean-code/check-mr-size.sh"
chmod +x "$repo3/scripts/clean-code/"*.sh
out="$(cd "$repo3" && scripts/install-hooks.sh 2>&1)"; assert_rc "install with clean-code present" 0 $?
[ -x "$repo3/.git/hooks/pre-push" ] && ok || bad "pre-push installed and executable"
printf 'y\n' > "$repo3/g.txt"
git -C "$repo3" add -- g.txt
out="$(git -C "$repo3" commit -m 'docs: y' 2>&1)"; rc=$?
assert_rc "pre-commit chains clean-code and blocks" 1 $rc
assert_contains "clean-code hook ran" "$out" "clean-code-ran"
(cd "$repo3" && .git/hooks/pre-push origin url >/dev/null 2>&1); assert_rc "pre-push blocks on size exit 1" 1 $?
printf '#!/usr/bin/env bash\nexit 2\n' > "$repo3/scripts/clean-code/check-mr-size.sh"
(cd "$repo3" && .git/hooks/pre-push origin url >/dev/null 2>&1); assert_rc "pre-push allows size exit 2" 0 $?
(cd "$repo" && .git/hooks/pre-push origin url >/dev/null 2>&1); assert_rc "pre-push without clean-code is a no-op" 0 $?

repo4="$TMPROOT/repo4"
new_repo "$repo4"
mkdir -p "$repo4/scripts"
cp "$here/../check-privacy.sh" "$here/../install-hooks.sh" "$repo4/scripts/"
printf '#!/usr/bin/env bash\nexec "$(git rev-parse --show-toplevel)/scripts/check-privacy.sh"\n' > "$repo4/.git/hooks/pre-commit"
chmod +x "$repo4/.git/hooks/pre-commit"
out="$(cd "$repo4" && scripts/install-hooks.sh 2>&1)"; assert_rc "legacy privacy hook replaced" 0 $?
[ ! -e "$repo4/.git/hooks/pre-commit.bak" ] && ok || bad "legacy hook not backed up"
assert_contains "legacy hook upgraded" "$(cat "$repo4/.git/hooks/pre-commit")" "managed-by"

repo5="$TMPROOT/repo5"
new_repo "$repo5"
mkdir -p "$repo5/scripts" "$repo5/skills/setup-repo/assets/scripts"
cp "$here/../check-privacy.sh" "$here/../install-hooks.sh" "$repo5/scripts/"
: > "$repo5/.privacyallow"
printf '#!/usr/bin/env bash\necho canonical-ran >&2\nexit 1\n' > "$repo5/skills/setup-repo/assets/scripts/check-clean-code.sh"
chmod +x "$repo5/skills/setup-repo/assets/scripts/check-clean-code.sh"
out="$(cd "$repo5" && scripts/install-hooks.sh 2>&1)"; assert_rc "install with canonical clean-code only" 0 $?
printf 'z\n' > "$repo5/h.txt"
git -C "$repo5" add -- h.txt
out="$(git -C "$repo5" commit -m 'docs: z' 2>&1)"; rc=$?
assert_rc "pre-commit falls back to the canonical clean-code script" 1 $rc
assert_contains "canonical script ran" "$out" "canonical-ran"
mkdir -p "$repo5/scripts/clean-code"
printf '#!/usr/bin/env bash\necho installed-ran >&2\nexit 0\n' > "$repo5/scripts/clean-code/check-clean-code.sh"
chmod +x "$repo5/scripts/clean-code/check-clean-code.sh"
out="$(git -C "$repo5" commit -m 'docs: z' 2>&1)"; rc=$?
assert_rc "installed copy wins over the canonical script" 0 $rc
assert_contains "installed copy ran" "$out" "installed-ran"
assert_not_contains "canonical script skipped" "$out" "canonical-ran"

repo6="$TMPROOT/repo6"
new_repo "$repo6"
mkdir -p "$repo6/scripts"
cp "$here/../check-privacy.sh" "$here/../install-hooks.sh" "$repo6/scripts/"
: > "$repo6/.privacyallow"
(cd "$repo6" && scripts/install-hooks.sh >/dev/null 2>&1)
assert_not_contains "no require env without a patterns file" "$(cat "$repo6/.git/hooks/pre-commit")" "PRIVACY_REQUIRE_PATTERNS"
printf 'see %s\n' "$ticket" > "$repo6/bad.txt"
git -C "$repo6" add -- bad.txt
git -C "$repo6" commit -q --no-verify -m 'docs: bad'
out="$(cd "$repo6" && .git/hooks/pre-push origin url 2>&1)"; rc=$?
assert_rc "pre-push blocks a pushed ticket id" 1 $rc
assert_contains "pre-push reports the line" "$out" "bad.txt:1"
printf 'fine\n' > "$repo6/ok.txt"
git -C "$repo6" add -- ok.txt
git -C "$repo6" commit -q --no-verify -m 'docs: ok'
out="$(cd "$repo6" && .git/hooks/pre-push origin url 2>&1)"; assert_rc "pre-push without upstream scans the last commit only" 0 $?

repo7="$TMPROOT/repo7"
new_repo "$repo7"
mkdir -p "$repo7/scripts" "$repo7/skills/setup-repo/assets/scripts"
cp "$here/../check-privacy.sh" "$here/../install-hooks.sh" "$repo7/scripts/"
printf '#!/usr/bin/env bash\nexit 1\n' > "$repo7/skills/setup-repo/assets/scripts/check-mr-size.sh"
chmod +x "$repo7/skills/setup-repo/assets/scripts/check-mr-size.sh"
(cd "$repo7" && scripts/install-hooks.sh >/dev/null 2>&1)
(cd "$repo7" && .git/hooks/pre-push origin url >/dev/null 2>&1); assert_rc "pre-push falls back to the canonical size check" 1 $?

repo8="$TMPROOT/repo8"
new_repo "$repo8"
mkdir -p "$repo8/scripts" "$repo8/.git/info"
cp "$here/../check-privacy.sh" "$here/../install-hooks.sh" "$repo8/scripts/"
: > "$repo8/.privacyallow"
printf 'zorb''co[a-z]*\n' > "$repo8/.git/info/privacy-patterns"
(cd "$repo8" && scripts/install-hooks.sh >/dev/null 2>&1)
for h in pre-commit commit-msg pre-push; do
  assert_contains "$h requires the patterns file" "$(cat "$repo8/.git/hooks/$h")" "export PRIVACY_REQUIRE_PATTERNS=1"
done
printf 'fine\n' > "$repo8/ok.txt"
git -C "$repo8" add -- ok.txt
out="$(git -C "$repo8" commit -m 'docs: ok' 2>&1)"; assert_rc "commit passes with the patterns file" 0 $?
rm -f "$repo8/.git/info/privacy-patterns"
printf 'more\n' >> "$repo8/ok.txt"
git -C "$repo8" add -- ok.txt
out="$(git -C "$repo8" commit -m 'docs: more' 2>&1)"; rc=$?
assert_rc "commit blocks once the patterns file is gone" 1 $rc
assert_contains "block names the file" "$out" "privacy-patterns"

repo9="$TMPROOT/repo9"
new_repo "$repo9"
mkdir -p "$repo9/scripts"
cp "$here/../check-privacy.sh" "$here/../install-hooks.sh" "$repo9/scripts/"
git -C "$repo9" config core.hooksPath custom-hooks
out="$(cd "$repo9" && scripts/install-hooks.sh 2>&1)"; assert_rc "install with core.hooksPath" 0 $?
assert_contains "core.hooksPath warned" "$out" "core.hooksPath"
[ -x "$repo9/custom-hooks/pre-commit" ] && ok || bad "hooks written to core.hooksPath"
out="$(cd "$repo" && scripts/install-hooks.sh 2>&1)"
assert_not_contains "no warning without core.hooksPath" "$out" "core.hooksPath"

out="$(cd "$repo" && scripts/install-hooks.sh --bogus 2>&1)"; assert_rc "bad flag" 2 $?
finish
