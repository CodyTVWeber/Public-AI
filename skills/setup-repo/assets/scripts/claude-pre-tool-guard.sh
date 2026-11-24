#!/usr/bin/env bash
set -uo pipefail

usage() {
  cat <<'EOF'
Usage: claude-pre-tool-guard.sh [-h|--help]

Claude Code PreToolUse hook (matcher: Bash). Reads hook JSON on stdin.
Acts on git push, gh pr create and glab mr create, however written (git -C d push,
git --no-pager push, env X=1 git push, sh -c "git push", chained, via a git alias).
  over the hard MR size limit (check-mr-size.sh exit 1)   -> block (exit 2, stderr to the agent)
  clean-code errors on the commits being pushed            -> block (exit 2), when code-quality-check.sh sits next to this script
    (changed lines in merge-base(HEAD, upstream, else base ref)..HEAD; working tree and untracked files are not read)
  check-mr-size.sh cannot measure (no base ref, crash)    -> ask the user (never silently allow)
  CLEAN_CODE_SKIP=<non-0> anywhere in the command         -> ask the user
  no changes to measure (exit 2), or not a push/MR create -> allow
Parses commands with git-scan.sh (python3); without it a coarser regex decides what counts as a push.
Exit: 0 allow or ask (JSON on stdout), 2 block
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

input="$(cat)"

ask() {
  local reason="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -nc --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
  else
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$reason"
  fi
}

case "$input" in
  *push*|*create*|*send-pack*|*SKIP=*) ;;
  *) exit 0 ;;
esac

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! tags="$("$here/git-scan.sh" <<<"$input" 2>/dev/null)"; then
  if printf '%s' "$input" | grep -Eq 'CLEAN_CODE_SKIP=|git[^|;&]*[[:space:]]push|(gh[[:space:]]+pr|glab[[:space:]]+mr)[[:space:]]+create'; then
    tags="push"
    printf '%s' "$input" | grep -Eq 'CLEAN_CODE_SKIP=[^0[:space:]]' && tags="push
deny:skip"
  else
    exit 0
  fi
fi

has() { printf '%s\n' "$tags" | grep -qx -- "$1"; }

if has deny:skip; then
  ask "CLEAN_CODE_SKIP bypasses the clean-code and MR-size gates. Confirm the user wants to skip them for this command."
  exit 0
fi

{ has push || has push-like || has mr-create; } || exit 0

pushed_base() {
  local base
  git merge-base HEAD '@{u}' 2>/dev/null && return 0
  base="$("$here/check-mr-size.sh" --print-base 2>/dev/null)" || return 1
  git merge-base "$base" HEAD 2>/dev/null
}

clean_code_gate() {
  local analyzer="$here/code-quality-check.sh" merge_base out
  [ -x "$analyzer" ] || return 0
  merge_base="$(pushed_base)" || return 0
  out="$("$analyzer" --range "$merge_base..HEAD" 2>&1 >/dev/null)" && return 0
  printf '%s\n' "$out" >&2
  echo "Fix the clean-code errors on the commits being pushed before pushing." >&2
  return 1
}

out="$("$here/check-mr-size.sh" 2>&1)"
rc=$?
case "$rc" in
  0|2) clean_code_gate || exit 2 ;;
  1)
    printf '%s\n' "$out" >&2
    echo "Split this work into smaller MRs before pushing, or ask the user to run it with CLEAN_CODE_SKIP=1 themselves." >&2
    exit 2
    ;;
  *)
    ask "MR size check could not run (exit $rc): ${out:0:200}. Confirm before pushing."
    ;;
esac
exit 0
