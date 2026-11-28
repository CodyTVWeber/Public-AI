#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/../../../../scripts/tests/lib.sh"
new_tmp

tool="$here/../check-pyramid.sh"
plan="$TMPROOT/plan.md"

check() { out="$("$tool" "$plan" 2>&1)"; rc=$?; }
expect_rule() { has_rule "$2" && ok || bad "$1" "no $2 in: $out"; }
has_rule() { jq -e --arg r "$1" 'any(.violations[]; .rule == $r)' <<<"$out" >/dev/null; }

header='| Layer | Cases | AC | Observable | Writer |
| --- | --- | --- | --- | --- |'
sys='| system | happy | AC-1 | member opens gallery and sees templates | atdd |'
api='| api | happy | AC-2 | GET /templates returns published templates | atdd |'
script='| system | happy | AC-1 | go to gallery and open a preview | script |'

write_plan() {
  printf '# Plan\n\n- AC-1: gallery lists templates\n- AC-2: preview opens in place\n\n## Verification\n\n%s\n' "$1" >"$plan"
}

write_plan "$header
$sys
$api
$script"
check
assert_rc "good plan" 0 "$rc"
assert_eq "no violations" '{"violations":[]}' "$(jq -c . <<<"$out")"

write_plan "No runtime change: pyramid skipped."
check
assert_rc "skip line" 0 "$rc"

printf '# Plan\n\n- AC-1: x\n' >"$plan"
check
assert_rc "missing heading" 1 "$rc"
expect_rule "missing heading" missing-heading

write_plan "See the table later."
check
expect_rule "no table" no-table

write_plan "$header
| unit | happy | AC-1 | a function returns 1 | atdd |
$api"
check
expect_rule "unit forbidden" unit-layer

write_plan "$header
| service | happy | AC-1 | a box glows | atdd |
$api"
check
expect_rule "unknown layer" bad-layer

write_plan "$header
| system | edge | AC-1 | member sees a spinner | atdd |
$api"
check
expect_rule "edge cases" bad-cases

write_plan "$header
| system | happy | AC-1 | member sees templates | feature |
$api"
check
expect_rule "bad writer" bad-writer

write_plan "$header
$sys"
check
expect_rule "AC-2 uncovered" uncovered-criterion

{
  printf '# Plan\n\n- AC-1: gallery lists templates\n\n## Verification\n\n%s\n' "$header"
  for i in 1 2 3 4 5; do
    printf '| system | happy | AC-1 | click %s | atdd |\n' "$i"
  done
} >"$plan"
check
expect_rule "too many system" too-many-system

"$tool" >/dev/null 2>&1
assert_rc "no args" 2 $?
"$tool" "$TMPROOT/missing.md" >/dev/null 2>&1
assert_rc "missing file" 3 $?
"$tool" -h >/dev/null
assert_rc "help" 0 $?

finish
