#!/usr/bin/env bash
set -euo pipefail

readonly MAX_TICKS=288
readonly SECONDS_PER_MINUTE=60
readonly SECONDS_PER_HOUR=3600
readonly SECONDS_PER_DAY=86400
readonly ISO_RE='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
readonly SPAN_RE='^([0-9]{1,7})([smhd])$'

usage() {
  cat <<'USAGE'
Usage: window.sh [--duration 1h] [--cadence 10m] [--start ISO] [-h|--help]

Plans the monitoring window: one tick at the start (baseline) and one per cadence until the end.
  --duration  <n>s|m|h|d, default 1h
  --cadence   <n>s|m|h|d, default 10m; must not exceed the duration
  --start     UTC ISO-8601 (YYYY-MM-DDTHH:MM:SSZ), default the current time
Ticks are capped at 288; a capped plan sets "capped": true.
Stdout: {start,end,ticks:[ISO...],cadence_seconds,tick_count,capped}
Exit: 0 ok, 2 usage
USAGE
}

die_usage() {
  printf 'window: %s\n' "$1" >&2
  exit 2
}

span_seconds() {
  [[ "$1" =~ $SPAN_RE ]] || die_usage "bad span '$1' (use 30m, 2h, 1d)"
  local count=$((10#${BASH_REMATCH[1]}))
  case "${BASH_REMATCH[2]}" in
    s) echo "$count" ;;
    m) echo $((count * SECONDS_PER_MINUTE)) ;;
    h) echo $((count * SECONDS_PER_HOUR)) ;;
    d) echo $((count * SECONDS_PER_DAY)) ;;
  esac
}

start_epoch() {
  local iso="$1"
  [[ "$iso" =~ $ISO_RE ]] || die_usage "bad --start '$iso'"
  jq -nr --arg iso "$iso" '$iso | fromdateiso8601 | select(todate == $iso)' || true
}

plan_json() {
  jq -nc --argjson start "$1" --argjson duration "$2" --argjson cadence "$3" --argjson max "$MAX_TICKS" '
    ([($duration / $cadence | floor) + 1, $max] | min) as $count
    | {
        start: ($start | todate),
        end: ($start + $duration | todate),
        ticks: [range(0; $count) | $start + . * $cadence | todate],
        cadence_seconds: $cadence,
        tick_count: $count,
        capped: (($duration / $cadence | floor) + 1 > $max)
      }'
}

main() {
  local duration=1h cadence=10m start=""
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --duration|--cadence|--start) [ $# -ge 2 ] || die_usage "$1 needs a value" ;;
    esac
    case "$1" in
      --duration) duration="$2" ;;
      --cadence) cadence="$2" ;;
      --start) start="$2" ;;
      *) die_usage "unknown argument '$1'" ;;
    esac
    shift 2
  done
  local duration_s cadence_s epoch
  duration_s="$(span_seconds "$duration")"
  cadence_s="$(span_seconds "$cadence")"
  [ "$duration_s" -gt 0 ] && [ "$cadence_s" -gt 0 ] || die_usage "duration and cadence must be positive"
  [ "$cadence_s" -le "$duration_s" ] || die_usage "cadence exceeds duration"
  epoch="$(start_epoch "${start:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}")"
  [ -n "$epoch" ] || die_usage "bad --start '$start'"
  plan_json "$epoch" "$duration_s" "$cadence_s"
}

main "$@"
