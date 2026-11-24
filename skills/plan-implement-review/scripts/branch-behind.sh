#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$here/lib-forge.sh"

usage() {
  cat <<'USAGE'
usage: branch-behind.sh <target>
Compare HEAD with <target> (e.g. origin/main) without touching the working tree.
stdout: {target, behind, ahead, conflicts}
behind/ahead: commits in target not in HEAD / in HEAD not in target.
conflicts: true|false from `git merge-tree --write-tree`; null when git is too old or histories are unrelated.
A bare name that is not a ref falls back to origin/<name>. Run `git fetch origin` first for fresh numbers.
exit: 0 ok, 2 usage, 3 precondition (not a repo, target not found)
USAGE
}

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
  "" | -*)
    usage >&2
    exit 2
    ;;
esac
[ "$#" -eq 1 ] || {
  usage >&2
  exit 2
}

target=$1
git_init
if ! git rev-parse --verify --quiet "$target^{commit}" >/dev/null; then
  if git rev-parse --verify --quiet "origin/$target^{commit}" >/dev/null; then
    target="origin/$target"
  else
    die 3 "target ref not found: $target"
  fi
fi

counts=$(git rev-list --left-right --count "$target...HEAD")
behind=${counts%%[[:space:]]*}
ahead=${counts##*[[:space:]]}

rc=0
git merge-tree --write-tree HEAD "$target" >/dev/null 2>&1 || rc=$?
case "$rc" in
  0) conflicts=false ;;
  1) conflicts=true ;;
  *) conflicts=null ;;
esac

jq -nc --arg t "$target" --argjson b "$behind" --argjson a "$ahead" --argjson c "$conflicts" \
  '{target: $t, behind: $b, ahead: $a, conflicts: $c}'
