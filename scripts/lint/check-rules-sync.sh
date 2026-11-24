#!/usr/bin/env bash
set -uo pipefail

usage() {
  cat <<'EOF'
Usage: check-rules-sync.sh [--fix]
Compares rules/*.md with skills/setup-repo/assets/rules/*.md (the installable mirror).
  --fix   copy rules/ -> mirror and drop mirror files with no canonical source
Stdout: JSON {drift:[{file,issue}]}   Exit: 0 in sync, 1 drift, 2 usage
EOF
}

fix=0
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --fix) fix=1 ;;
  "") ;;
  *) usage >&2; exit 2 ;;
esac

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
src="$root/rules"
mirror="$root/skills/setup-repo/assets/rules"
mkdir -p "$mirror"

drift=()
note() { drift+=("$(jq -cn --arg f "$1" --arg i "$2" '{file:$f,issue:$i}')"); }

for f in "$src"/*.md; do
  name="$(basename "$f")"
  [[ "$name" == README.md ]] && continue
  if [[ ! -f "$mirror/$name" ]]; then
    note "$name" "missing in mirror"
    [[ $fix -eq 1 ]] && cp "$f" "$mirror/$name"
  elif ! cmp -s "$f" "$mirror/$name"; then
    note "$name" "differs from mirror"
    [[ $fix -eq 1 ]] && cp "$f" "$mirror/$name"
  fi
done

for f in "$mirror"/*.md; do
  name="$(basename "$f")"
  if [[ ! -f "$src/$name" ]]; then
    note "$name" "mirror file has no canonical source"
    [[ $fix -eq 1 ]] && rm "$f"
  fi
done

if [[ ${#drift[@]} -eq 0 ]]; then
  echo '{"drift":[]}'
  exit 0
fi

printf '%s\n' "${drift[@]}" | jq -sc '{drift: .}'
[[ $fix -eq 1 ]] && exit 0
exit 1
