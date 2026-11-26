#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$here/lib-slices.sh"

usage() {
  cat <<'USAGE'
Usage: worktree-merge.sh --into BRANCH --topic T --slices a,b,c [--root DIR] [--mode worktree|clone]
Run in the main checkout, on BRANCH, with a clean tree. Merges slice branches BRANCH--<slice>
into BRANCH in the order given, one `git merge --no-ff` each. Clone mode first fetches the slice
branch from ROOT/<slice> into refs/pir/<T>/<slice>. ROOT defaults to ${TMPDIR:-/tmp}/pir-<T>/wt (clone mode: ${XDG_CACHE_HOME:-$HOME/.cache}/pir-<T>/wt).
Stops at the first conflict and leaves the merge in progress for the caller to resolve and commit;
later slices stay in pending. Never rebases, forces or pushes.
stdout: {merged:[slice], pending:[slice], conflict:null | {slice, files:[path]}}
Exit: 0 all merged, 1 conflict, 2 usage, 3 precondition (wrong branch, dirty tree, missing slice)
USAGE
}

into="" topic="" csv="" root="" mode=worktree
merged=()

usage_fail() {
  usage >&2
  exit 2
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help) usage; exit 0 ;;
      --into | --topic | --slices | --root | --mode) [ $# -ge 2 ] || usage_fail ;;
    esac
    case "$1" in
      --into) into=$2; shift 2 ;;
      --topic) topic=$2; shift 2 ;;
      --slices) csv=$2; shift 2 ;;
      --root) root=$2; shift 2 ;;
      --mode) mode=$2; shift 2 ;;
      *) usage_fail ;;
    esac
  done
  [ -n "$into" ] && [ -n "$topic" ] || usage_fail
}

preflight() {
  check_topic "$topic"
  check_mode "$mode"
  load_slices "$csv"
  need_tools
  require_main_checkout
  [ "$(git branch --show-current)" = "$into" ] || die 3 "not on branch: $into"
  require_clean
  [ -n "$root" ] || root=$(default_root "$topic" "$mode")
  root=$(abs_path "$root")
}

resolve_ref() {
  local name=$1 branch ref
  branch=$(slice_branch "$into" "$name")
  if [ "$mode" = clone ]; then
    ref=$(slice_ref "$topic" "$name")
    git fetch -q "$root/$name" "+refs/heads/$branch:$ref" || die 3 "fetch failed for slice: $name"
  else
    ref=refs/heads/$branch
    git show-ref --verify --quiet "$ref" || die 3 "slice branch not found: $branch"
  fi
  printf '%s\n' "$ref"
}

conflict_files() {
  git diff --name-only --diff-filter=U
}

merge_one() {
  local name=$1 ref
  ref=$(resolve_ref "$name") || return 4
  git merge -q --no-ff --no-edit -m "Merge slice $name into $into" "$ref" >/dev/null 2>&1
}

report() {
  local conflict=$1 pending=$2
  jq -nc --argjson m "$(json_array ${merged[@]+"${merged[@]}"})" --argjson p "$pending" --argjson c "$conflict" \
    '{merged: $m, pending: $p, conflict: $c}'
}

pending_from() {
  local seen=0 name out=()
  for name in "${SLICES[@]}"; do
    [ "$name" = "$1" ] && seen=1
    [ "$seen" = 1 ] && out+=("$name")
  done
  json_array ${out[@]+"${out[@]}"}
}

pending_after() {
  local seen=0 name out=()
  for name in "${SLICES[@]}"; do
    [ "$seen" = 1 ] && out+=("$name")
    [ "$name" = "$1" ] && seen=1
  done
  json_array ${out[@]+"${out[@]}"}
}

on_failure() {
  local name=$1 rc=$2 files conflict
  if [ "$rc" = 4 ]; then
    report null "$(pending_from "$name")"
    exit 3
  fi
  if [ ! -f "$(git rev-parse --git-dir)/MERGE_HEAD" ]; then
    report null "$(pending_after "$name")"
    die 3 "merge failed without a conflict for slice: $name"
  fi
  files=$(conflict_files | jq -Rsc 'split("\n") | map(select(length > 0))')
  conflict=$(jq -nc --arg s "$name" --argjson f "$files" '{slice: $s, files: $f}')
  report "$conflict" "$(pending_after "$name")"
  exit 1
}

main() {
  local name
  parse_args "$@"
  preflight
  for name in "${SLICES[@]}"; do
    merge_one "$name" || on_failure "$name" "$?"
    merged+=("$name")
  done
  report null "[]"
}

main "$@"
