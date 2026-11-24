#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib.sh"
new_tmp

tree="$TMPROOT/tree"
mkdir -p "$tree/scripts/lint" "$tree/rules" "$tree/skills/setup-repo/assets/rules"
cp "$here/../lint/check-rules-sync.sh" "$tree/scripts/lint/"
sync="$tree/scripts/lint/check-rules-sync.sh"
mirror="$tree/skills/setup-repo/assets/rules"

printf 'a\n' > "$tree/rules/one.md"
printf 'index\n' > "$tree/rules/README.md"
cp "$tree/rules/one.md" "$mirror/one.md"

out="$("$sync")"; rc=$?
assert_rc "in sync passes" 0 $rc
assert_eq "in sync json" '{"drift":[]}' "$out"

printf 'b\n' > "$tree/rules/one.md"
out="$("$sync")"; rc=$?
assert_rc "content drift fails" 1 $rc
assert_contains "drift named" "$out" "differs from mirror"

printf 'c\n' > "$tree/rules/two.md"
out="$("$sync")"; rc=$?
assert_contains "missing mirror named" "$out" "missing in mirror"

printf 'orphan\n' > "$mirror/orphan.md"
out="$("$sync")"; assert_contains "orphan named" "$out" "no canonical source"

out="$("$sync" --fix)"; rc=$?
assert_rc "fix exits 0" 0 $rc
out="$("$sync")"; assert_rc "in sync after fix" 0 $?
[ -f "$mirror/orphan.md" ] && bad "orphan removed" "orphan.md still present" || ok
[ -f "$mirror/README.md" ] && bad "README not mirrored" "README.md copied" || ok
assert_eq "mirror content copied" "b" "$(cat "$mirror/one.md")"

"$sync" --bogus >/dev/null 2>&1; assert_rc "bad flag is usage error" 2 $?

finish
