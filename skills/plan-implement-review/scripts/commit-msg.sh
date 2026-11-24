#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: commit-msg.sh <branch> <item>...
  Prints "<branch>: 1. <item> 2. <item> ..." on one line (numbered-list commit convention).
  Items are whitespace-trimmed; a trailing period is kept as given.
Exit: 0 ok, 2 usage (missing branch/items, empty item)
USAGE
}

case "${1:-}" in -h|--help) usage; exit 0 ;; esac
[[ $# -ge 2 ]] || { usage; exit 2; }

branch="$1"
shift
[[ -n "${branch// /}" ]] || { echo "commit-msg: empty branch" >&2; exit 2; }

out="$branch:"
n=0
for item in "$@"; do
  clean="$(printf '%s' "$item" | tr '\n\t' '  ' | sed -e 's/  */ /g' -e 's/^ //' -e 's/ $//')"
  [[ -n "$clean" ]] || { echo "commit-msg: empty item" >&2; exit 2; }
  n=$((n + 1))
  out="$out $n. $clean"
done
printf '%s\n' "$out"
