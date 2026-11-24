#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib.sh"

guard="${GUARD:-$here/../guard/git-approval-guard.sh}"
fixtures="$here/fixtures"
NL=$'\n'

decision() {
  local cmd="${1//<NL>/$NL}" out
  out="$("$guard" --command "$cmd" 2>/dev/null)" || { echo "error"; return; }
  [ -z "$out" ] && { echo "none"; return; }
  printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision'
}

while IFS=$'\t' read -r want cmd; do
  assert_eq "attack $want :: $cmd" "$want" "$(decision "$cmd")"
done < "$fixtures/guard-attacks.tsv"

benign=0
while IFS= read -r cmd; do
  benign=$((benign + 1))
  assert_eq "benign none :: $cmd" none "$(decision "$cmd")"
done < "$fixtures/guard-benign.txt"
[ "$benign" -ge 25 ] && ok || bad "benign table has at least 25 rows" "got $benign"

finish
