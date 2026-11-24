#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$here/lib-forge.sh"

usage() {
  cat <<'USAGE'
usage: ci-failure-tail.sh <number> [job] [--lines N]
Print the last N lines (default 80) of a failed CI job log for PR/MR <number>, read-only.
job: id or exact name from mr-state.sh failed_jobs; default is the first failed job.
Log is cleaned: ANSI codes, carriage returns, section markers, and blank lines removed.
stdout: log tail. stderr: which job was chosen.
exit: 0 ok, 1 no failed job or no log for it, 2 usage, 3 precondition (no CLI, not authenticated)
USAGE
}

n=""
job=""
lines=80
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --lines)
      [ "$#" -ge 2 ] || {
        usage >&2
        exit 2
      }
      lines=$2
      shift 2
      ;;
    -*)
      usage >&2
      exit 2
      ;;
    *)
      if [ -z "$n" ]; then
        n=$1
      elif [ -z "$job" ]; then
        job=$1
      else
        usage >&2
        exit 2
      fi
      shift
      ;;
  esac
done
[ -n "$n" ] || {
  usage >&2
  exit 2
}
case "$n$lines" in
  *[!0-9]*)
    usage >&2
    exit 2
    ;;
esac

forge_init
forge_need_cli
state=$("$here/mr-state.sh" "$n") || exit "$?"
picked=$(printf '%s' "$state" | jq -c --arg j "$job" '
  .pipeline.failed_jobs
  | if $j == "" then .[0] else map(select((.id | tostring) == $j or .name == $j)) | .[0] end // empty')
[ -n "$picked" ] || {
  echo "no matching failed job" >&2
  exit 1
}
id=$(printf '%s' "$picked" | jq -r '.id // empty')
name=$(printf '%s' "$picked" | jq -r .name)
[ -n "$id" ] || {
  echo "no log available for check: $name" >&2
  exit 1
}
printf 'job: %s (%s)\n' "$name" "$id" >&2

if [ "$FORGE" = gitlab ]; then
  raw=$(glab api "projects/:id/jobs/$id/trace") || die 3 "glab failed fetching job log"
else
  raw=$(gh run view --job "$id" --log-failed) || die 3 "gh failed fetching job log"
fi

esc=$(printf '\033')
printf '%s\n' "$raw" |
  tr '\r' '\n' |
  sed "s/$esc\[[0-9;?]*[A-Za-z]//g" |
  { grep -Ev '^(section_(start|end):[0-9]+:|[[:space:]]*$)' || true; } |
  tail -n "$lines"
