#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib.sh"
new_tmp

tree="$TMPROOT/tree"
mkdir -p "$tree/scripts/lint" "$tree/rules" "$tree/mirror/rules" "$tree/mirror/scripts"
cp "$here/../lint/check-copies.sh" "$tree/scripts/lint/"
sync="$tree/scripts/lint/check-copies.sh"
printf 'rules/*.md\tmirror/rules/\n!rules/README.md\nscripts/tool.sh\tmirror/scripts/tool.sh\n' > "$tree/scripts/lint/copies.list"

printf 'a\n' > "$tree/rules/one.md"
printf 'index\n' > "$tree/rules/README.md"
printf 'tool\n' > "$tree/scripts/tool.sh"
cp "$tree/rules/one.md" "$tree/mirror/rules/one.md"
cp "$tree/scripts/tool.sh" "$tree/mirror/scripts/tool.sh"

out="$("$sync")"; rc=$?
assert_rc "in sync passes" 0 $rc
assert_eq "in sync json" '{"drift":[]}' "$out"

printf 'b\n' > "$tree/rules/one.md"
out="$("$sync")"; rc=$?
assert_rc "content drift fails" 1 $rc
assert_contains "drift named" "$out" "differs from rules/one.md"

printf 'c\n' > "$tree/rules/two.md"
out="$("$sync")"; assert_contains "missing copy named" "$out" "missing copy of rules/two.md"

printf 'orphan\n' > "$tree/mirror/rules/orphan.md"
out="$("$sync")"; assert_contains "orphan named" "$out" "no canonical source"

printf 'changed\n' > "$tree/scripts/tool.sh"
out="$("$sync")"; assert_contains "single-file pair drift named" "$out" "mirror/scripts/tool.sh"

out="$("$sync" --fix)"; rc=$?
assert_rc "fix exits 0" 0 $rc
out="$("$sync")"; assert_rc "in sync after fix" 0 $?
[ -f "$tree/mirror/rules/orphan.md" ] && bad "orphan removed" "orphan.md still present" || ok
[ -f "$tree/mirror/rules/README.md" ] && bad "excluded path not copied" "README.md copied" || ok
assert_eq "glob copy content" "b" "$(cat "$tree/mirror/rules/one.md")"
assert_eq "pair copy content" "changed" "$(cat "$tree/mirror/scripts/tool.sh")"

rm "$tree/scripts/tool.sh"
out="$("$sync")"; assert_contains "missing canonical named" "$out" "canonical file missing"

"$sync" --bogus >/dev/null 2>&1; assert_rc "bad flag is usage error" 2 $?
rm "$tree/scripts/lint/copies.list"
"$sync" >/dev/null 2>&1; assert_rc "missing manifest is usage error" 2 $?

"$here/../lint/check-copies.sh" >/dev/null; assert_rc "this repo's copies are in sync" 0 $?
finish
