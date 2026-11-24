#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/fixtures.sh"
new_tmp

mkdir -p "$TMPROOT/clone"
clone="$(cd "$TMPROOT/clone" && pwd -P)"
fake_clone "$clone" write-plan review
status_of() { jq -r --arg id "$2" '.checks[] | select(.id == $id) | .status' <<<"$1"; }
applied() {
  local dir="$1"
  shift
  go_bare "$dir"
  "$BOOTSTRAP" "$dir" --apply --yes --skills-from "$clone" "$@" >/dev/null 2>&1
}

a="$TMPROOT/ok"; applied "$a"
json="$("$VERIFY" "$a" 2>/dev/null)"; assert_rc "applied fixture verifies" 0 $?
assert_eq "report is ok" "true" "$(jq -r .ok <<<"$json")"
assert_eq "install record found" "true" "$(jq -r .installed_record <<<"$json")"
for id in scripts git-hooks settings hook-scripts analyzer post-git skills agents-doc; do
  assert_eq "$id passes" "pass" "$(status_of "$json" "$id")"
done
assert_eq "ci skipped when not installed" "skip" "$(status_of "$json" ci)"
assert_eq "verify leaves the tree as it was" "" "$(git -C "$a" status --porcelain | grep -v -e '^??' || true)"

b="$TMPROOT/broken-analyzer"; applied "$b"
rm -rf "$b/scripts/clean-code/cleancode"
json="$("$VERIFY" "$b" 2>/dev/null)"; assert_rc "missing analyzer package fails" 1 $?
assert_eq "scripts check fails" "fail" "$(status_of "$json" scripts)"
assert_eq "analyzer check fails" "fail" "$(status_of "$json" analyzer)"

c="$TMPROOT/broken-json"; applied "$c"
printf '{ nope' > "$c/.claude/settings.json"
json="$("$VERIFY" "$c" 2>/dev/null)"; assert_rc "invalid settings fails" 1 $?
assert_eq "settings check fails" "fail" "$(status_of "$json" settings)"

d="$TMPROOT/broken-hooks"; applied "$d"
git -C "$d" config --local --unset core.hooksPath
json="$("$VERIFY" "$d" 2>/dev/null)"; assert_rc "inactive hooks fail" 1 $?
assert_eq "git-hooks check fails" "fail" "$(status_of "$json" git-hooks)"

e="$TMPROOT/broken-link"; applied "$e"
rm -rf "$clone/skills/review"
json="$("$VERIFY" "$e" 2>/dev/null)"; assert_rc "dangling skill link fails" 1 $?
assert_eq "skills check fails" "fail" "$(status_of "$json" skills)"
fake_clone "$clone" review

f="$TMPROOT/broken-script"; applied "$f"
chmod -x "$f/scripts/clean-code/post-git-check.sh"
json="$("$VERIFY" "$f" 2>/dev/null)"; assert_rc "non-executable hook script fails" 1 $?
assert_eq "hook-scripts check fails" "fail" "$(status_of "$json" hook-scripts)"

g="$TMPROOT/ci"; go_bare "$g"; git -C "$g" remote add origin "$GITLAB_REMOTE"
"$BOOTSTRAP" "$g" --apply --yes --with ci --without skills >/dev/null 2>&1
json="$("$VERIFY" "$g" 2>/dev/null)"; assert_rc "ci fixture verifies" 0 $?
assert_eq "ci passes" "pass" "$(status_of "$json" ci)"
rm "$g/.gitlab/ci/ai-guardrails.yml"
json="$("$VERIFY" "$g" 2>/dev/null)"; assert_rc "missing ci file fails" 1 $?
assert_eq "ci check fails" "fail" "$(status_of "$json" ci)"

h="$TMPROOT/bare-install"; go_bare "$h"
"$SCRIPTS/install.sh" "$h" >/dev/null 2>&1
json="$("$VERIFY" "$h" 2>/dev/null)"; assert_rc "install.sh alone verifies without a record" 0 $?
assert_eq "no install record" "false" "$(jq -r .installed_record <<<"$json")"

husky="$TMPROOT/husky"; js_husky_gitlab "$husky"
"$BOOTSTRAP" "$husky" --apply --yes --without skills >/dev/null 2>&1
json="$("$VERIFY" "$husky" 2>/dev/null)"; assert_rc "husky fixture verifies" 0 $?
assert_eq "husky hooks pass" "pass" "$(status_of "$json" git-hooks)"

lefthook="$TMPROOT/lefthook"; go_bare "$lefthook"
"$BOOTSTRAP" "$lefthook" --apply --yes --hooks-via lefthook --without skills >/dev/null 2>&1
json="$("$VERIFY" "$lefthook" 2>/dev/null)"; assert_rc "manual hook systems are skipped, not failed" 0 $?
assert_eq "lefthook is skipped" "skip" "$(status_of "$json" git-hooks)"

plain="$TMPROOT/plain"; mkdir -p "$plain"
"$VERIFY" "$plain" >/dev/null 2>&1; assert_rc "non-repo is a precondition error" 3 $?
"$VERIFY" >/dev/null 2>&1; assert_rc "no target is usage" 2 $?
"$VERIFY" --help >/dev/null; assert_rc "help" 0 $?
finish
