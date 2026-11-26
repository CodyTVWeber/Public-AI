#!/usr/bin/env bash
set -uo pipefail

usage() {
  cat <<'EOF2'
Usage: check-duplicates.sh <other-repo>
Lists tracked, non-empty files in <other-repo> that are byte-identical to a tracked file of this repo
and absent from the install record (<other-repo>/.claude/ai-guardrails.json, `.files` keys).
Such files are hand-copied duplicates: install them through setup-repo or delete them. LICENSE is allowed.
Stdout: JSON {duplicates:[{path,matches}]}   Exit: 0 none, 1 duplicates, 2 usage
EOF2
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") usage >&2; exit 2 ;;
esac

other="$1"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
[ -d "$other/.git" ] || { echo "check-duplicates: $other is not a git repo" >&2; exit 2; }
other="$(cd "$other" && pwd)"

record="$other/.claude/ai-guardrails.json"
installed="[]"
[ -f "$record" ] && installed="$(jq -c '(.files // {}) | keys' "$record")"

index="$(mktemp)"
trap 'rm -f "$index"' EXIT
git -C "$root" ls-files -s -z | while IFS= read -r -d '' line; do
  printf '%s %s\n' "$(printf '%s' "$line" | cut -d' ' -f2 | cut -f1)" "${line#*$'\t'}"
done > "$index"

found=()
while IFS= read -r -d '' path; do
  [ -f "$other/$path" ] && [ -s "$other/$path" ] || continue
  [ "$(basename "$path")" = "LICENSE" ] && continue
  jq -e --arg p "$path" 'index($p) != null' <<<"$installed" >/dev/null && continue
  sha="$(git -C "$other" hash-object -- "$path")"
  matches="$(awk -v s="$sha" '$1 == s { sub(/^[^ ]+ /, ""); print }' "$index" | jq -R . | jq -sc .)"
  [ "$matches" = "[]" ] && continue
  found+=("$(jq -cn --arg p "$path" --argjson m "$matches" '{path:$p,matches:$m}')")
done < <(git -C "$other" ls-files -z)

if [ "${#found[@]}" -eq 0 ]; then
  echo '{"duplicates":[]}'
  exit 0
fi
printf '%s\n' "${found[@]}" | jq -sc '{duplicates:.}'
exit 1
