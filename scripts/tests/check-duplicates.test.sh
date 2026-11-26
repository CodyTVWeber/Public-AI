#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib.sh"
new_tmp

src="$TMPROOT/src"
other="$TMPROOT/other"
new_repo "$src"
new_repo "$other"
mkdir -p "$src/scripts/lint" "$src/rules" "$other/rules" "$other/.claude"
cp "$here/../lint/check-duplicates.sh" "$src/scripts/lint/"
tool="$src/scripts/lint/check-duplicates.sh"
printf 'rule one\n' > "$src/rules/one.md"
printf 'rule two\n' > "$src/rules/two.md"
printf 'license\n' > "$src/LICENSE"
: > "$src/empty"
git -C "$src" add -A

printf 'unrelated\n' > "$other/own.md"
out="$("$tool" "$other")"; rc=$?
assert_rc "no overlap passes" 0 $rc
assert_eq "no overlap json" '{"duplicates":[]}' "$out"

cp "$src/rules/one.md" "$other/rules/one.md"
cp "$src/rules/two.md" "$other/rules/renamed.md"
cp "$src/LICENSE" "$other/LICENSE"
: > "$other/empty"
git -C "$other" add -A
out="$("$tool" "$other")"; rc=$?
assert_rc "duplicates fail" 1 $rc
assert_contains "same-name duplicate named" "$out" '"path":"rules/one.md","matches":["rules/one.md"]'
assert_contains "renamed duplicate named" "$out" '"path":"rules/renamed.md","matches":["rules/two.md"]'
assert_not_contains "LICENSE allowed" "$out" LICENSE
assert_not_contains "empty ignored" "$out" empty

printf '{"files":{"rules/one.md":{}}}\n' > "$other/.claude/ai-guardrails.json"
git -C "$other" add -A
out="$("$tool" "$other")"
assert_not_contains "installed file allowed" "$out" '"path":"rules/one.md"'
assert_contains "uninstalled still listed" "$out" rules/renamed.md

"$tool" "$TMPROOT/missing" >/dev/null 2>&1; assert_rc "non-repo is usage error" 2 $?
"$tool" --help | grep -q '^Usage' && ok || bad "help prints usage"
finish
