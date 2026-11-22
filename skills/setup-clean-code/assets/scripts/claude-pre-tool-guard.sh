#!/usr/bin/env bash
# Claude Code PreToolUse hook (matcher: Bash). Blocks pushing or opening an MR/PR while the
# branch is over the hard size limit. Exit 2 = block and show stderr to the agent.
#
# Reads the hook JSON on stdin; only acts on git push / gh pr create / glab mr create.

set -uo pipefail

input="$(cat)"
cmd="$(printf '%s' "$input" | python3 -I -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)"
[ -z "$cmd" ] && cmd="$input"

printf '%s' "$cmd" | grep -Eq '(^|[;&|])[[:space:]]*(git[[:space:]]+push|gh[[:space:]]+pr[[:space:]]+create|glab[[:space:]]+mr[[:space:]]+create)([[:space:]]|$)' || exit 0

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="$("$here/check-mr-size.sh" 2>&1)"
rc=$?
if [ "$rc" -eq 1 ]; then
  printf '%s\n' "$out" >&2
  echo "Split this work into smaller MRs before pushing, or ask the user to approve CLEAN_CODE_SKIP=1." >&2
  exit 2
fi
exit 0
