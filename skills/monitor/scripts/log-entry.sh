#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEMPLATE="$here/../assets/templates/monitoring-log.md"
readonly NAME_RE='^([0-9]{4}-[0-9]{2}-[0-9]{2})-(.+)\.md$'

usage() {
  cat <<'USAGE'
Usage: log-entry.sh LOGFILE tick|baseline|final [-h|--help]   (entry JSON on stdin)

Appends one compact entry to a dated monitoring log. LOGFILE is YYYY-MM-DD-<slug>.md; a missing
file is created from assets/templates/monitoring-log.md (Date: header). A log with a `## Final`
entry is frozen and refuses further entries.
Stdin by kind (optional "at" ISO timestamp overrides the clock):
  tick      compare.sh output plus optional "note"
  baseline  {"strength": "strong|weak", "values": {signal: value}}
  final     {"verdict", "window": {"start","end"}, "signals": [...], "evidence": [...], "action"}
Stdout: {file, entry, created}
Exit: 0 appended, 2 usage, 3 log is frozen
USAGE
}

die() {
  printf 'log-entry: %s\n' "$2" >&2
  exit "$1"
}

render_header() {
  local base slug text
  base="$(basename "$1")"
  [[ "$base" =~ $NAME_RE ]] || die 2 "log name must be YYYY-MM-DD-<slug>.md: $base"
  slug="${BASH_REMATCH[2]}"
  text="$(cat "$TEMPLATE")"
  text="${text//\{\{TITLE\}\}/${slug//-/ }}"
  echo "${text//\{\{DATE\}\}/${BASH_REMATCH[1]}}"
}

create_log() {
  local header
  header="$(render_header "$1")"
  mkdir -p "$(dirname "$1")"
  printf '%s\n' "$header" >"$1"
}

tick_number() {
  echo $(($(grep -c '^### tick ' "$1" || true) + 1))
}

render_entry() {
  local kind="$1" log="$2" payload="$3" at
  at="$(jq -r --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.at // $now' <<<"$payload")"
  jq -r --arg kind "$kind" --arg at "$at" --argjson n "$(tick_number "$log")" -f "$here/lib/log-entry.jq" <<<"$payload"
}

require_entry_shape() {
  jq -e 'type == "object"' <<<"$2" >/dev/null 2>&1 || die 2 "stdin must be a JSON object"
  case "$1" in
    tick) jq -e '.verdict and (.signals | type == "array")' <<<"$2" >/dev/null || die 2 "tick needs verdict and signals" ;;
    baseline) jq -e '.values | type == "object"' <<<"$2" >/dev/null || die 2 "baseline needs values" ;;
    final) jq -e '.verdict and .window.start and .window.end and (.signals | type == "array")' <<<"$2" >/dev/null || die 2 "final needs verdict, window, signals" ;;
  esac
}

main() {
  case "${1:-}" in -h|--help) usage; exit 0 ;; esac
  [ $# -eq 2 ] || { usage >&2; exit 2; }
  local log="$1" kind="$2" payload created=false
  case "$kind" in tick|baseline|final) ;; *) die 2 "kind must be tick, baseline or final" ;; esac
  payload="$(cat)"
  require_entry_shape "$kind" "$payload"
  if [ -f "$log" ] && grep -q '^## Final' "$log"; then die 3 "log is frozen: $log"; fi
  [ -f "$log" ] || { create_log "$log"; created=true; }
  printf '\n%s\n' "$(render_entry "$kind" "$log" "$payload")" >>"$log"
  jq -nc --arg file "$log" --arg entry "$kind" --argjson created "$created" '{file:$file,entry:$entry,created:$created}'
}

main "$@"
