#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$here/lib-slices.sh"

usage() {
  cat <<'USAGE'
Usage: worktree-clean.sh --topic T [--into BRANCH] [--root DIR] [--mode worktree|clone] [--force]
Removes the topic's slice checkouts under ROOT, deletes the slice branches (clone mode:
refs/pir/<T>/*), runs `git worktree prune`, and counts what is left.
ROOT defaults to ${TMPDIR:-/tmp}/pir-<T>/wt, or ${XDG_CACHE_HOME:-$HOME/.cache}/pir-<T>/wt when
only that holds a manifest or --mode clone is given. ROOT must sit outside the repository.
BRANCH and the mode come from ROOT/manifest.json unless given.
Acts only on slice names listed in the manifest or registered in `git worktree list` under ROOT,
and only when the name matches [a-z0-9]+(-[a-z0-9]+)*. Other folders under ROOT are never touched.
A slice is removed only if it is a worktree of this repo or a clone whose origin is this repo;
anything else is listed in skipped and left intact.
A slice with commits not merged into BRANCH, with uncommitted changes, or whose `git status`
fails, stays intact and is listed in kept; --force removes it anyway and lists it in discarded.
Run from the main checkout.
stdout: {removed:[slice], kept:[{slice, branch, commits, dirty}], discarded:[...], skipped:[{slice, reason}], worktrees_left:n}
Exit: 0 clean, 1 something kept, skipped or left, 2 usage, 3 precondition (no feature branch, linked worktree, root inside repo)
USAGE
}

topic="" into="" root="" mode="" force=0
removed=()
kept="[]"
discarded="[]"
skipped="[]"
had_manifest=0
registered=""

usage_fail() {
  usage >&2
  exit 2
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help) usage; exit 0 ;;
      --force) force=1; shift; continue ;;
      --topic | --into | --root | --mode) [ $# -ge 2 ] || usage_fail ;;
    esac
    case "$1" in
      --topic) topic=$2; shift 2 ;;
      --into) into=$2; shift 2 ;;
      --root) root=$2; shift 2 ;;
      --mode) mode=$2; shift 2 ;;
      *) usage_fail ;;
    esac
  done
  [ -n "$topic" ] || usage_fail
}

pick_root() {
  local alt
  [ -z "$root" ] || return 0
  root=$(default_root "$topic" "${mode:-worktree}")
  [ -z "$mode" ] && [ ! -f "$(manifest_path "$root")" ] || return 0
  alt=$(default_root "$topic" clone)
  if [ -f "$(manifest_path "$alt")" ]; then root=$alt; fi
}

preflight() {
  check_topic "$topic"
  need_tools
  require_main_checkout
  pick_root
  root=$(abs_path "$root")
  require_outside_repo "$root"
  [ ! -f "$(manifest_path "$root")" ] || had_manifest=1
  [ -n "$into" ] || into=$(manifest_get "$root" .base)
  [ -n "$mode" ] || mode=$(manifest_get "$root" .mode)
  [ -n "$mode" ] || mode=worktree
  check_mode "$mode"
}

manifest_names() {
  local file
  file=$(manifest_path "$root")
  [ -f "$file" ] || return 0
  jq -r '.slices[]?.name? // empty' "$file" 2>/dev/null || return 0
}

registered_names() {
  local line rel
  [ "$mode" != clone ] || return 0
  while IFS= read -r line; do
    rel=${line#"worktree $root/"}
    case "$rel" in */*) ;; *) printf '%s\n' "$rel" ;; esac
  done <<<"$registered"
}

slice_names() {
  { manifest_names; registered_names; } | sort -u
  return 0
}

is_registered() {
  grep -qxF "worktree $root/$1" <<<"$registered"
}

same_dir() {
  [ -d "$1" ] && [ -d "$2" ] && [ "$(cd "$1" && pwd -P)" = "$(cd "$2" && pwd -P)" ]
}

clone_owned() {
  local dir=$root/$1 top origin self
  top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || return 1
  same_dir "$top" "$dir" || return 1
  origin=$(git -C "$dir" remote get-url origin 2>/dev/null) || return 1
  self=$(git rev-parse --show-toplevel)
  same_dir "$origin" "$self"
}

owner_problem() {
  local name=$1
  valid_name "$name" || { echo "invalid slice name"; return 0; }
  [ -e "$root/$name" ] || return 0
  if [ "$mode" = clone ]; then
    clone_owned "$name" || echo "not a clone of this repository"
  else
    is_registered "$name" || echo "not a worktree of this repository"
  fi
  return 0
}

import_clone_ref() {
  local name=$1 branch ref
  branch=$(slice_branch "$into" "$name")
  ref=$(slice_ref "$topic" "$name")
  if [ -d "$root/$name" ]; then
    git fetch -q "$root/$name" "+refs/heads/$branch:$ref" 2>/dev/null || die 3 "cannot read slice branch from clone: $name"
  fi
  printf '%s\n' "$ref"
}

head_ref() {
  if [ "$mode" = clone ]; then import_clone_ref "$1"; else printf 'refs/heads/%s\n' "$(slice_branch "$into" "$1")"; fi
}

unmerged_count() {
  git show-ref --verify --quiet "$1" || { echo 0; return; }
  git rev-list --count "$into..$1"
}

is_dirty() {
  local dir=$root/$1 top out
  [ -d "$dir" ] || return 1
  top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || return 0
  same_dir "$top" "$dir" || return 0
  out=$(git -C "$dir" status --porcelain 2>/dev/null) || return 0
  [ -n "$out" ]
}

delete_slice() {
  local name=$1 ref=$2
  if [ "$mode" = clone ]; then
    rm -rf "${root:?}/$name"
    git update-ref -d "$ref"
    return 0
  fi
  git worktree remove --force "$root/$name" 2>/dev/null || [ ! -e "$root/$name" ] || return 1
  git worktree prune
  git branch -D "$(slice_branch "$into" "$name")" >/dev/null 2>&1 || return 0
}

skip_slice() {
  skipped=$(jq -c --arg s "$1" --arg r "$2" '. + [{slice: $s, reason: $r}]' <<<"$skipped")
}

entry() {
  jq -nc --arg s "$1" --arg b "$(slice_branch "$into" "$1")" --argjson c "$2" --argjson d "$3" \
    '{slice: $s, branch: $b, commits: $c, dirty: $d}'
}

process_slice() {
  local name=$1 ref commits dirty=false row problem
  problem=$(owner_problem "$name")
  if [ -n "$problem" ]; then
    skip_slice "$name" "$problem"
    return 0
  fi
  ref=$(head_ref "$name")
  commits=$(unmerged_count "$ref")
  is_dirty "$name" && dirty=true
  row=$(entry "$name" "$commits" "$dirty")
  if [ "$commits" -gt 0 ] || [ "$dirty" = true ]; then
    if [ "$force" = 0 ]; then
      kept=$(jq -c --argjson r "$row" '. + [$r]' <<<"$kept")
      return 0
    fi
    discarded=$(jq -c --argjson r "$row" '. + [$r]' <<<"$discarded")
  fi
  if delete_slice "$name" "$ref"; then
    removed+=("$name")
  else
    skip_slice "$name" "removal failed"
  fi
}

count_left() {
  local n=0 dir
  if [ "$mode" != clone ]; then
    topic_worktrees "$root" | wc -l | tr -d ' '
    return 0
  fi
  for dir in "$root"/*/; do
    [ -d "$dir" ] && n=$((n + 1))
  done
  echo "$n"
}

finish() {
  local left
  git worktree prune
  left=$(count_left)
  if [ "$kept" = "[]" ] && [ "$skipped" = "[]" ] && [ "$left" -eq 0 ] && [ "$had_manifest" = 1 ]; then
    rm -f "$(manifest_path "$root")"
    rmdir "$root" 2>/dev/null || true
  fi
  jq -nc --argjson r "$(json_array ${removed[@]+"${removed[@]}"})" --argjson k "$kept" \
    --argjson d "$discarded" --argjson s "$skipped" --argjson n "$left" \
    '{removed: $r, kept: $k, discarded: $d, skipped: $s, worktrees_left: $n}'
  [ "$kept" = "[]" ] && [ "$skipped" = "[]" ] && [ "$left" -eq 0 ]
}

main() {
  local name names
  parse_args "$@"
  preflight
  registered=$(topic_worktrees "$root")
  names=$(slice_names)
  if [ -n "$names" ]; then
    [ -n "$into" ] || die 3 "feature branch unknown: pass --into"
    require_branch "$into"
  fi
  while IFS= read -r name; do
    [ -n "$name" ] && process_slice "$name"
  done <<<"$names"
  finish
}

main "$@"
