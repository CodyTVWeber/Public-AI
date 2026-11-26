#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$here/lib-slices.sh"

usage() {
  cat <<'USAGE'
Usage: worktree-split.sh --base BRANCH --topic T --slices a,b,c [--root DIR] [--mode worktree|clone]
Creates one branch BRANCH--<slice> from the tip of BRANCH and one checkout per slice:
  worktree (default)  git worktree add  ROOT/<slice>
  clone               git clone --local ROOT/<slice>, then a branch inside the clone
ROOT defaults to ${TMPDIR:-/tmp}/pir-<T>/wt (clone mode: ${XDG_CACHE_HOME:-$HOME/.cache}/pir-<T>/wt,
which survives TMPDIR purges) and must sit outside the repository.
Names match [a-z0-9]+(-[a-z0-9]+)*. Run from the main checkout with a clean tree.
Refuses existing paths, existing branches and an already split ROOT. A failure while creating
rolls back every slice made so far. Writes ROOT/manifest.json for worktree-merge and worktree-clean.
stdout: {topic, mode, base, root, slices:[{name, path, branch}]}
Exit: 0 ok, 2 usage, 3 precondition or creation failure
USAGE
}

base="" topic="" csv="" root="" mode=worktree
created=" "
root_made=0

usage_fail() {
  usage >&2
  exit 2
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help) usage; exit 0 ;;
      --base | --topic | --slices | --root | --mode) [ $# -ge 2 ] || usage_fail ;;
    esac
    case "$1" in
      --base) base=$2; shift 2 ;;
      --topic) topic=$2; shift 2 ;;
      --slices) csv=$2; shift 2 ;;
      --root) root=$2; shift 2 ;;
      --mode) mode=$2; shift 2 ;;
      *) usage_fail ;;
    esac
  done
  [ -n "$base" ] && [ -n "$topic" ] || usage_fail
}

preflight() {
  local name path branch
  check_topic "$topic"
  check_mode "$mode"
  load_slices "$csv"
  need_tools
  require_main_checkout
  require_clean
  require_branch "$base"
  [ -n "$root" ] || root=$(default_root "$topic" "$mode")
  root=$(abs_path "$root")
  require_outside_repo "$root"
  [ ! -e "$(manifest_path "$root")" ] || die 3 "already split: $root"
  for name in "${SLICES[@]}"; do
    path=$root/$name
    branch=$(slice_branch "$base" "$name")
    [ ! -e "$path" ] || die 3 "path exists: $path"
    git check-ref-format --branch "$branch" >/dev/null 2>&1 || die 3 "invalid branch name: $branch"
    ! git show-ref --verify --quiet "refs/heads/$branch" || die 3 "branch exists: $branch"
  done
}

add_slice() {
  local name=$1 path=$root/$1 branch
  branch=$(slice_branch "$base" "$name")
  created="$created$name "
  if [ "$mode" = clone ]; then
    git clone -q --local --branch "$base" "$(git rev-parse --show-toplevel)" "$path" || return 1
    git -C "$path" checkout -q -b "$branch" || return 1
  else
    git worktree add -q -b "$branch" "$path" "$base" || return 1
  fi
}

rollback() {
  local name
  for name in $created; do
    git worktree remove --force "$root/$name" 2>/dev/null || rm -rf "${root:?}/$name"
    git branch -D "$(slice_branch "$base" "$name")" >/dev/null 2>&1 || continue
  done
  git worktree prune
  if [ "$root_made" = 1 ]; then rmdir "$root" 2>/dev/null || return 0; fi
}

create_all() {
  local name
  [ -d "$root" ] || root_made=1
  mkdir -p "$root" || return 1
  for name in "${SLICES[@]}"; do
    add_slice "$name" || return 1
  done
}

render() {
  local name rows="[]"
  for name in "${SLICES[@]}"; do
    rows=$(jq -c --arg n "$name" --arg p "$root/$name" --arg b "$(slice_branch "$base" "$name")" \
      '. + [{name: $n, path: $p, branch: $b}]' <<<"$rows")
  done
  jq -nc --arg t "$topic" --arg m "$mode" --arg b "$base" --arg r "$root" --argjson s "$rows" \
    '{topic: $t, mode: $m, base: $b, root: $r, slices: $s}'
}

main() {
  local doc
  parse_args "$@"
  preflight
  if ! create_all; then
    rollback
    die 3 "slice creation failed; rolled back"
  fi
  doc=$(render)
  printf '%s\n' "$doc" >"$(manifest_path "$root")"
  printf '%s\n' "$doc"
}

main "$@"
