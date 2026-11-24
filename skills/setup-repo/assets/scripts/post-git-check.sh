#!/usr/bin/env bash
set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: post-git-check.sh [-h|--help]

Claude Code PostToolUse hook (matcher: Bash). Reads hook JSON on stdin (.tool_input.command,
.tool_response, .cwd). The git command has already run; this hook never undoes it.
  git commit       clean-code analyzer on the commit's changed lines (code-quality-check.sh
                   --range PARENT..HEAD, so the working tree never counts; a merge commit: its
                   conflict-resolved files), subject over POST_GIT_SUBJECT_MAX chars (default 72),
                   MR size over the soft or hard budget
  git push         reminder to keep exactly one PR/MR for the branch (pr-find.sh when installed)
                   and to run the watch skill until the pipeline is green
  git merge, pull  conflicts left in the tree, or the analyzer on conflict-resolved files
  anything else    exit 0, no output
Every finding, analyzer errors included, arrives as hookSpecificOutput.additionalContext with exit 0.
The hook never exits 2, so a finished commit never forces a follow-up commit; the errors are fixed in
the next planned change and the push gate re-checks them.
Env: POST_GIT_SKIP=1, CLEAN_CODE_SKIP=1 or CC_SKIP=1 skip the hook.
Needs jq, python3 and git-scan.sh next to this script; any missing piece exits 0.
Exit: 0 always (2 only for a usage error)
USAGE
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) usage >&2; exit 2 ;;
esac

SUBJECT_MAX="${POST_GIT_SUBJECT_MAX:-72}"
EMPTY_TREE="4b825dc642cb6eb9a060e54bf8d69288fbee4904"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
errors=""
notes=""
TAB="$(printf '\t')"

add_note() { notes="${notes:+$notes
}$1"; }
add_error() { errors="${errors:+$errors
}$1"; }

skipped() {
  [ "${POST_GIT_SKIP:-0}" = 1 ] || [ "${CLEAN_CODE_SKIP:-0}" = 1 ] || [ "${CC_SKIP:-0}" = 1 ]
}

has() { printf '%s\n' "$tags" | grep -qx -- "$1"; }

first_parent_base() {
  git rev-parse --verify --quiet HEAD^1 >/dev/null && { echo "HEAD^1"; return; }
  echo "$EMPTY_TREE"
}

commit_files() {
  if git rev-parse --verify --quiet HEAD^2 >/dev/null; then
    git diff-tree --cc -r --name-only --no-commit-id HEAD
  else
    git diff-tree -r --name-only --no-commit-id --root HEAD
  fi
}

analyzer_findings() {
  local base="$1" files="$2" analyzer="$here/code-quality-check.sh"
  [ -x "$analyzer" ] && [ -n "$files" ] || return 0
  "$analyzer" --range "$base..HEAD" 2>/dev/null | jq -r --arg files "$files" '
    ($files | split("\n")) as $set
    | .findings[] | select(.file as $f | $set | index($f))
    | "\(.severity)\t\(.file):\(.line) [\(.rule)] \(.message)"' 2>/dev/null
}

report_findings() {
  local findings="$1" line
  [ -n "$findings" ] || return 0
  while IFS= read -r line; do
    case "$line" in
      error*) add_error "${line#*$TAB}" ;;
      *) add_note "clean-code warning: ${line#*$TAB}" ;;
    esac
  done <<<"$findings"
}

check_subject() {
  local subject
  subject="$(git log -1 --format=%s 2>/dev/null)" || return 0
  [ "${#subject}" -le "$SUBJECT_MAX" ] && return 0
  add_note "Commit subject is ${#subject} chars; keep it at $SUBJECT_MAX or fewer (rules/small-mrs.md): amend or follow up with a shorter one."
}

check_size() {
  local out rc
  [ -x "$here/check-mr-size.sh" ] || return 0
  out="$("$here/check-mr-size.sh" 2>&1)"
  rc=$?
  [ "$rc" -eq 1 ] && add_note "MR is over the hard size budget: $(printf '%s' "$out" | head -1). Split it before pushing."
  [ "$rc" -eq 0 ] && case "$out" in *WARN*) add_note "MR is over the soft size budget: $(printf '%s' "$out" | head -1). Say why it cannot be split, or split it." ;; esac
  return 0
}

after_commit() {
  git rev-parse --verify --quiet HEAD >/dev/null || return 0
  check_subject
  report_findings "$(analyzer_findings "$(first_parent_base)" "$(commit_files)")"
  check_size
}

find_pr_find() {
  local root candidate
  root="$(git rev-parse --show-toplevel)"
  for candidate in "$root/.claude/skills/plan-implement-review/scripts/pr-find.sh" "$root/skills/plan-implement-review/scripts/pr-find.sh"; do
    [ -x "$candidate" ] && { printf '%s' "$candidate"; return; }
  done
}

after_push() {
  local branch finder
  branch="$(git branch --show-current 2>/dev/null)"
  finder="$(find_pr_find)"
  if [ -n "$finder" ]; then
    add_note "Pushed ${branch:-HEAD}. Ensure exactly one PR/MR exists for it: run '$finder ${branch:-<branch>}' (read-only; reuse the open one, open one only when none exists), then run the watch skill until the pipeline is green."
  else
    add_note "Pushed ${branch:-HEAD}. Ensure exactly one PR/MR exists for it (reuse the open one, open one only when none exists), then run the watch skill until the pipeline is green."
  fi
}

after_merge() {
  local unmerged
  unmerged="$(git diff --name-only --diff-filter=U 2>/dev/null)"
  if [ -n "$unmerged" ]; then
    add_note "Conflicts remain in: $(printf '%s' "$unmerged" | paste -sd' ' -). Resolve them, then git add and git commit; the commit check runs on the resolved files."
    return 0
  fi
  git rev-parse --verify --quiet HEAD^2 >/dev/null || return 0
  report_findings "$(analyzer_findings HEAD^1 "$(commit_files)")"
}

error_intro() {
  printf 'clean-code errors in the work you just committed. The commit stands: fold the fixes into your next planned change instead of committing again just for them (the push gate re-checks):\n%s' "$errors"
}

emit_result() {
  local context="$notes"
  [ -n "$errors" ] && context="$(error_intro)${notes:+
$notes}"
  [ -n "$context" ] || exit 0
  jq -nc --arg c "$context" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}'
}

input="$(cat)"
case "$input" in *git*|*merge*|*pull*) ;; *) exit 0 ;; esac
skipped && exit 0
command -v jq >/dev/null 2>&1 || exit 0
[ -x "$here/git-scan.sh" ] || exit 0
tags="$("$here/git-scan.sh" <<<"$input" 2>/dev/null)" || exit 0
[ -n "$tags" ] || exit 0
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
cd "${cwd:-${CLAUDE_PROJECT_DIR:-.}}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

has commit && after_commit
{ has merge || has pull; } && after_merge
has push && after_push
emit_result
