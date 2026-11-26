#!/usr/bin/env bash
set -uo pipefail

usage() {
  cat <<'EOF'
Usage: lint-docs.sh [BASE]   (default BASE: HEAD; covers staged, unstaged and untracked .md files)
       lint-docs.sh --hook   (Claude Code PostToolUse: reads hook JSON on stdin, reports only the edited file, exit 2 on violation)

Enforces rules/docs-current-or-dated.md on changed Markdown:
  dated doc = basename YYYY-MM-DD-<slug>.md
  - edited beyond whitespace, renamed or deleted                -> violation
  - added without a `Date: YYYY-MM-DD` line in its first 10 lines matching the filename -> violation
  current doc = any other .md
  - added lines holding time-relative wording (previously, no longer, used to, recently,
    currently, formerly, newly, soon, as of v…, was changed, we switched, has been
    renamed/replaced/changed/removed/deprecated, now supports/uses/requires/returns, Update:) -> violation

Env:  DOCS_LINT_SKIP_PATHS  extra ERE of paths to skip (default skips CHANGELOG*, node_modules, docs-current-or-dated.md)
      DOCS_LINT_SKIP=1      skip all checks
Stdout: JSON {violations:[{file,line,rule,detail}]}   Exit: 0 clean, 1 violations, 2 usage, 3 not a git repo
EOF
}

case "${1:-}" in -h|--help) usage; exit 0 ;; esac

HOOK=0
[[ "${1:-}" == --hook ]] && HOOK=1
if [[ $HOOK -eq 0 ]]; then
  [[ $# -le 1 ]] || { usage >&2; exit 2; }
  [[ "${DOCS_LINT_SKIP:-}" == 1 ]] && { echo '{"violations":[]}'; exit 0; }
  git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repo" >&2; exit 3; }
  BASE="${1:-HEAD}"
  git rev-parse --verify --quiet "$BASE^{commit}" >/dev/null || { echo "bad base: $BASE" >&2; exit 2; }
  cd "$(git rev-parse --show-toplevel)"
fi

SKIP_RE='(^|/)(CHANGELOG[^/]*|node_modules/.*)$|(^|/)docs-current-or-dated\.md$'
[[ -n "${DOCS_LINT_SKIP_PATHS:-}" ]] && SKIP_RE="$SKIP_RE|${DOCS_LINT_SKIP_PATHS}"

DATED_RE='^[0-9]{4}-[0-9]{2}-[0-9]{2}-.+\.md$'
TERMS='previously|no longer|used to|recently|currently|formerly|newly|soon|as of v[0-9a-z.]+|as of version|was changed|we switched|has been (renamed|replaced|changed|removed|deprecated)|now (supports|uses|requires|returns)|update:'
TERM_AWK_RE="(^|[^a-z0-9])($TERMS)([^a-z0-9]|$)"

violations=()

add_violation() {
  violations+=("$(jq -cn --arg f "${1%:*}" --argjson l "${1##*:}" --arg r "$2" --arg d "$3" '{file:$f,line:$l,rule:$r,detail:$d}')")
}

scan_current_lines() {
  local file="$1" line text
  while IFS=$'\t' read -r line text; do
    [[ -z "$line" ]] && continue
    add_violation "$file:$line" "current-doc-time-relative" "$(printf '%s' "$text" | cut -c1-120)"
  done < <(awk -F'\t' -v re="$TERM_AWK_RE" '{ if (match(tolower($2), re)) print $1 "\t" $2 }')
}

added_lines_of() {
  git diff -U0 --no-color "$BASE" -- "$1" | awk '
    /^@@/ { match($0, /\+[0-9]+/); n = substr($0, RSTART + 1, RLENGTH - 1) + 0; next }
    /^\+\+\+/ { next }
    /^\+/ { printf "%d\t%s\n", n, substr($0, 2); n++ }
  '
}

all_lines_of() {
  awk '{ printf "%d\t%s\n", NR, $0 }' "$1"
}

check_dated_header() {
  local file="$1" base_name expected found
  base_name="${file##*/}"
  expected="${base_name:0:10}"
  found=$(head -n 10 "$file" | grep -E '^Date: [0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]*$' | head -n 1 | sed -E 's/^Date: //; s/[[:space:]]+$//')
  if [[ -z "$found" ]]; then
    add_violation "$file:1" "dated-doc-missing-date" "add a 'Date: $expected' line in the first 10 lines"
  elif [[ "$found" != "$expected" ]]; then
    add_violation "$file:1" "dated-doc-date-mismatch" "header $found, filename $expected"
  fi
}

check_tracked() {
  local status="$1" path="$2" name="${2##*/}"
  [[ "$path" == *.md ]] || return 0
  [[ "$path" =~ $SKIP_RE ]] && return 0
  if [[ "$name" =~ $DATED_RE ]]; then
    case "$status" in
      M) [[ -z "$(git diff -w --ignore-blank-lines "$BASE" -- "$path")" ]] || add_violation "$path:1" "dated-doc-edited" "dated docs are immutable; write a new dated doc that supersedes this one" ;;
      D) add_violation "$path:1" "dated-doc-deleted" "dated docs are kept" ;;
      A) check_dated_header "$path" ;;
    esac
    return 0
  fi
  case "$status" in
    A|M) scan_current_lines "$path" < <(added_lines_of "$path") ;;
  esac
}

check_untracked() {
  local path="$1" name="${1##*/}"
  [[ "$path" =~ $SKIP_RE ]] && return 0
  if [[ "$name" =~ $DATED_RE ]]; then
    check_dated_header "$path"
    return 0
  fi
  scan_current_lines "$path" < <(all_lines_of "$path")
}

report_and_exit() {
  if [[ ${#violations[@]} -eq 0 ]]; then
    echo '{"violations":[]}'
    exit 0
  fi
  printf '%s\n' "${violations[@]}" | jq -sc '{violations: .}'
  exit 1
}

run_hook() {
  local target dir top rel status
  target="$(jq -r '.tool_input.file_path // empty' 2>/dev/null)"
  [[ "$target" == *.md ]] || exit 0
  dir="$(cd "$(dirname "$target")" 2>/dev/null && pwd -P)" || exit 0
  top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || exit 0
  rel="${dir#"$top"}"
  rel="${rel#/}"
  rel="${rel:+$rel/}$(basename "$target")"
  cd "$top" || exit 0
  BASE=HEAD
  git rev-parse --verify --quiet HEAD >/dev/null || exit 0
  status="$(git diff --name-status --no-renames HEAD -- "$rel" | cut -f1)"
  if [[ -n "$status" ]]; then
    check_tracked "$status" "$rel"
  elif [[ -n "$(git ls-files --others --exclude-standard -- "$rel")" ]]; then
    check_untracked "$rel"
  fi
  [[ ${#violations[@]} -eq 0 ]] && exit 0
  printf 'docs check failed in %s (rules/docs-current-or-dated.md). This edit fails until the file meets the rule: %s\n' "$rel" "$(printf '%s\n' "${violations[@]}" | jq -sc .)" >&2
  exit 2
}

[[ $HOOK -eq 1 ]] && run_hook

while IFS=$'\t' read -r status path; do
  [[ -z "$path" ]] && continue
  check_tracked "$status" "$path"
done < <(git diff --name-status --no-renames "$BASE" | awk -F'\t' '{ print $1 "\t" $2 }')

while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  check_untracked "$path"
done < <(git ls-files --others --exclude-standard -- '*.md')

report_and_exit
