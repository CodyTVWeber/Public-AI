#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$here/lib-forge.sh"

usage() {
  cat <<'USAGE'
usage: forge-ctx.sh
Print repo context as JSON (no network, no writes):
  {host, cli, project, branch, base, default_branch, clean, dirty_files[], behind, ahead}
host: gitlab|github from origin url (override: PIR_FORGE=gitlab|github).
base: origin/<default_branch>, from cached refs. behind/ahead: HEAD vs base, null if base ref missing.
exit: 0 ok, 2 usage, 3 precondition (not a repo, no origin, forge or default branch unknown)
USAGE
}

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
  "") ;;
  *)
    usage >&2
    exit 2
    ;;
esac

forge_init
default=$(forge_default_branch) || die 3 "cannot determine default branch; run: git fetch origin"
base="origin/$default"
branch=$(git branch --show-current)
dirty=$(git status --porcelain)

behind=null
ahead=null
if git rev-parse --verify --quiet "$base^{commit}" >/dev/null; then
  counts=$(git rev-list --left-right --count "$base...HEAD")
  behind=${counts%%[[:space:]]*}
  ahead=${counts##*[[:space:]]}
fi

printf '%s' "$dirty" |
  jq -Rnc \
    --arg host "$FORGE" --arg cli "$CLI" --arg project "$PROJECT" \
    --arg branch "$branch" --arg base "$base" --arg default "$default" \
    --argjson behind "$behind" --argjson ahead "$ahead" '
    [inputs | select(length > 0) | .[3:]] as $files
    | {host: $host, cli: $cli, project: $project,
       branch: (if $branch == "" then null else $branch end),
       base: $base, default_branch: $default,
       clean: ($files | length == 0), dirty_files: $files,
       behind: $behind, ahead: $ahead}'
