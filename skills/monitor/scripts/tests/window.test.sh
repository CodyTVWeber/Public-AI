#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/../../../../scripts/tests/lib.sh"

tool="$here/../window.sh"
start=2026-01-01T00:00:00Z

run() { out="$("$tool" "$@" 2>&1)"; rc=$?; }

run --duration 2h --cadence 30m --start "$start"
assert_rc "hours and minutes" 0 "$rc"
assert_eq "tick count includes tick 0" 5 "$(jq .tick_count <<<"$out")"
assert_eq "first tick is the start" "$start" "$(jq -r '.ticks[0]' <<<"$out")"
assert_eq "last tick is the end" 2026-01-01T02:00:00Z "$(jq -r '.ticks[-1]' <<<"$out")"
assert_eq "end" 2026-01-01T02:00:00Z "$(jq -r .end <<<"$out")"
assert_eq "cadence seconds" 1800 "$(jq .cadence_seconds <<<"$out")"
assert_eq "not capped" false "$(jq .capped <<<"$out")"

run --duration 1d --cadence 6h --start "$start"
assert_eq "day form" 5 "$(jq .tick_count <<<"$out")"
assert_eq "day end" 2026-01-02T00:00:00Z "$(jq -r .end <<<"$out")"

run --duration 90s --cadence 30s --start "$start"
assert_eq "seconds form" 4 "$(jq .tick_count <<<"$out")"

run --duration 100m --cadence 30m --start "$start"
assert_eq "partial last interval drops" 4 "$(jq .tick_count <<<"$out")"

run --start "$start"
assert_eq "default 1h at 10m" 7 "$(jq .tick_count <<<"$out")"

run --duration 30d --cadence 1m --start "$start"
assert_rc "capped plan is ok" 0 "$rc"
assert_eq "capped at 288" 288 "$(jq '.ticks | length' <<<"$out")"
assert_eq "capped flag" true "$(jq .capped <<<"$out")"

run
assert_rc "defaults use the clock" 0 "$rc"
assert_eq "default tick count" 7 "$(jq .tick_count <<<"$out")"

for args in "--duration 2x" "--duration h" "--duration 0m" "--cadence 0s" "--duration 10m --cadence 1h" \
  "--start 2026-02-30T00:00:00Z" "--start yesterday" "--bogus" "--duration"; do
  run $args
  assert_rc "invalid: $args" 2 "$rc"
done

run -h
assert_rc "help" 0 "$rc"
assert_contains "help names the cap" "$out" "288"

finish
