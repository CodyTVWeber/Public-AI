#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-1k-cross.sh <base> [--worktree] [--json] [-h|--help]

Lists files in the diff that cross the 1000-line line: <= 1000 lines at the merge-base with
<base> (0 when new) and > 1000 lines at HEAD. Lock, snapshot, minified and generated files are
ignored.
  --worktree  measure the working-tree file instead of HEAD (uncommitted work)
  --json      print a JSON array of {path, base_lines, head_lines}
Env: LIMIT (default 1000)
Exit: 0 none crossed, 1 at least one crossed, 2 usage, 3 base ref not found
EOF
}

base=""
worktree=0
json=0
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --worktree) worktree=1 ;;
    --json) json=1 ;;
    -*) usage >&2; exit 2 ;;
    *) [ -z "$base" ] && base="$arg" || { usage >&2; exit 2; } ;;
  esac
done
[ -n "$base" ] || { usage >&2; exit 2; }

limit="${LIMIT:-1000}"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "check-1k-cross: not a git repo" >&2; exit 3; }
mb="$(git merge-base "$base" HEAD 2>/dev/null)" || { echo "check-1k-cross: cannot resolve base: $base" >&2; exit 3; }

count_lines() { awk 'END{print NR}'; }
results=()

while IFS= read -r -d '' path; do
  case "$path" in
    *.lock|*lock.json|*lock.yaml|*.snap|*.min.js|*.min.css|*/generated/*|*.generated.*|*.d.ts) continue ;;
  esac
  if [ "$worktree" -eq 1 ]; then
    [ -f "$path" ] || continue
    head_lines="$(count_lines < "$path")"
  else
    head_lines="$(git show "HEAD:$path" 2>/dev/null | count_lines || true)"
  fi
  [ "$head_lines" -gt "$limit" ] || continue
  base_lines="$(git show "$mb:$path" 2>/dev/null | count_lines || true)"
  [ "$base_lines" -le "$limit" ] || continue
  results+=("$path"$'\t'"$base_lines"$'\t'"$head_lines")
done < <(
  if [ "$worktree" -eq 1 ]; then
    git diff --name-only -z --diff-filter=AMR "$mb" --
    git ls-files --others --exclude-standard -z
  else
    git diff --name-only -z --diff-filter=AMR "$mb" HEAD --
  fi
)

if [ "$json" -eq 1 ]; then
  if [ "${#results[@]}" -eq 0 ]; then echo '[]'; else
    printf '%s\n' "${results[@]}" | jq -Rn '[inputs | split("\t") | {path: .[0], base_lines: (.[1]|tonumber), head_lines: (.[2]|tonumber)}]'
  fi
else
  for r in "${results[@]+"${results[@]}"}"; do
    IFS=$'\t' read -r p b h <<<"$r"
    echo "$p: $b -> $h lines (crosses $limit)"
  done
fi
[ "${#results[@]}" -eq 0 ] || exit 1
exit 0
