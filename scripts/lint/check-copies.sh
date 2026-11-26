#!/usr/bin/env bash
set -uo pipefail

usage() {
  cat <<'EOF2'
Usage: check-copies.sh [--fix]
Keeps byte-identical copies equal to their canonical files. The manifest scripts/lint/copies.list holds one
line per rule: `canonical<TAB>copy`, or `!canonical` to exclude a path from a glob.
  canonical may be a glob (rules/*.md); then copy is a directory ending in `/`, and files in that
  directory with no canonical source count as drift.
  --fix   copy canonical over the copy and delete copies with no canonical source
Stdout: JSON {drift:[{file,issue}]}   Exit: 0 in sync, 1 drift, 2 usage
EOF2
}

fix=0
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --fix) fix=1 ;;
  "") ;;
  *) usage >&2; exit 2 ;;
esac

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
list="$root/scripts/lint/copies.list"
[ -f "$list" ] || { echo "check-copies: missing $list" >&2; exit 2; }

drift=()
wanted=()
note() { drift+=("$(jq -cn --arg f "$1" --arg i "$2" '{file:$f,issue:$i}')"); }

excluded() {
  grep -qxF -- "!$1" "$list"
}

sync_pair() {
  local from="$1" to="$2"
  wanted+=("$to")
  if [ ! -f "$root/$from" ]; then
    note "$from" "canonical file missing"
  elif [ ! -f "$root/$to" ]; then
    note "$to" "missing copy of $from"
  elif ! cmp -s "$root/$from" "$root/$to"; then
    note "$to" "differs from $from"
  else
    return 0
  fi
  [ "$fix" -eq 1 ] && [ -f "$root/$from" ] && { mkdir -p "$(dirname "$root/$to")"; cp "$root/$from" "$root/$to"; }
  return 0
}

expand_glob() {
  local pattern="$1" dir="$2" f
  for f in "$root"/$pattern; do
    [ -f "$f" ] || continue
    excluded "${f#"$root"/}" || sync_pair "${f#"$root"/}" "$dir$(basename "$f")"
  done
}

find_orphans() {
  local dir="$1" f rel
  for f in "$root/$dir"*; do
    [ -f "$f" ] || continue
    rel="${f#"$root"/}"
    printf '%s\n' "${wanted[@]+"${wanted[@]}"}" | grep -qxF -- "$rel" && continue
    note "$rel" "copy has no canonical source"
    [ "$fix" -eq 1 ] && rm "$f"
  done
}

dirs=()
while IFS=$'\t' read -r canonical copy; do
  case "$canonical" in ""|'!'*) continue ;; esac
  case "$canonical" in
    *'*'*) expand_glob "$canonical" "$copy"; dirs+=("$copy") ;;
    *) sync_pair "$canonical" "$copy" ;;
  esac
done < "$list"
for d in "${dirs[@]+"${dirs[@]}"}"; do find_orphans "$d"; done

if [ ${#drift[@]} -eq 0 ]; then
  echo '{"drift":[]}'
  exit 0
fi
printf '%s\n' "${drift[@]}" | jq -sc '{drift: .}'
[ "$fix" -eq 1 ] && exit 0
exit 1
