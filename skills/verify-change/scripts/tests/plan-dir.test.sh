#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/../../../../scripts/tests/lib.sh"
new_tmp

tool="$here/../plan-dir.sh"
mkdir -p "$TMPROOT/docs/plans/2026/11"
plan="$TMPROOT/docs/plans/2026/11/2026-11-28_topic.md"
printf '# x\n' > "$plan"

out="$("$tool" "$plan")"; rc=$?
assert_rc "valid underscore rc" 0 $rc
assert_eq "stem" "2026-11-28_topic" "$(jq -r .stem <<<"$out")"
assert_eq "dir" "$TMPROOT/docs/plans/2026/11/2026-11-28_topic" "$(jq -r .dir <<<"$out")"
assert_eq "plan abs" "$plan" "$(jq -r .plan <<<"$out")"

hyphen="$TMPROOT/docs/plans/2026/11/2026-11-28-other.md"
out="$("$tool" "$hyphen")"; rc=$?
assert_rc "hyphen name without file" 0 $rc
assert_eq "hyphen stem" "2026-11-28-other" "$(jq -r .stem <<<"$out")"

"$tool" "$TMPROOT/docs/plans/2026/11/readme.md" >/dev/null 2>&1
assert_rc "bad basename" 2 $?
"$tool" >/dev/null 2>&1
assert_rc "no args" 2 $?
"$tool" -h >/dev/null
assert_rc "help" 0 $?

finish
