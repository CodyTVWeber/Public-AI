#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/../../../../scripts/tests/lib.sh"
new_tmp

tool="$here/../log-entry.sh"
log="$TMPROOT/docs/monitor/2026-03-04-gallery-rollout.md"

entry() { out="$(printf '%s' "$2" | "$tool" "$log" "$1" 2>&1)"; rc=$?; }

baseline='{"strength":"weak","at":"2026-03-04T10:00:00Z","values":{"errors":2,"sigs":["TimeoutError"]}}'
tick='{"at":"2026-03-04T10:10:00Z","verdict":"healthy","note":"quiet","signals":[{"name":"errors","status":"ok","value":2,"baseline":2,"rule":"max_ratio 2","reason":"within limit"},{"name":"p95","status":"warn","value":480,"baseline":400,"rule":"max_ratio 1.3","reason":"beyond warn bound 440"}]}'
final='{"at":"2026-03-04T11:00:00Z","verdict":"healthy","window":{"start":"2026-03-04T10:00:00Z","end":"2026-03-04T11:00:00Z"},"signals":[{"name":"errors","status":"ok","value":2,"baseline":2,"rule":"max_ratio 2","reason":"within limit"}],"evidence":["dashboard link"],"action":"none"}'

entry baseline "$baseline"
assert_rc "baseline appends" 0 "$rc"
assert_eq "creates the log" true "$(jq .created <<<"$out")"
body="$(cat "$log")"
assert_contains "title from slug" "$body" "# Monitoring log: gallery rollout"
assert_contains "dated header" "$body" "Date: 2026-03-04"
assert_contains "baseline strength" "$body" "### baseline · 2026-03-04T10:00:00Z · weak"
assert_contains "baseline value" "$body" "- errors = 2"

entry tick "$tick"
assert_eq "second write reuses the log" false "$(jq .created <<<"$out")"
body="$(cat "$log")"
assert_contains "tick header" "$body" "### tick 1 · 2026-03-04T10:10:00Z · healthy"
assert_contains "status counts" "$body" "ok 1 · warn 1 · fail 0 · unknown 0"
assert_contains "lists the non-ok signal" "$body" "- warn p95: 480 (baseline 400)"
assert_not_contains "omits ok signals" "$body" "- ok errors"
assert_contains "note" "$body" "note: quiet"

entry tick "$tick"
assert_contains "tick numbers advance" "$(cat "$log")" "### tick 2 "

entry final "$final"
assert_rc "final appends" 0 "$rc"
body="$(cat "$log")"
assert_contains "final header" "$body" "## Final · 2026-03-04T11:00:00Z · healthy"
assert_contains "final evidence" "$body" "evidence: dashboard link"
assert_contains "final action" "$body" "action: none"

before="$(cat "$log")"
entry tick "$tick"
assert_rc "frozen log refuses a tick" 3 "$rc"
entry final "$final"
assert_rc "frozen log refuses a second final" 3 "$rc"
assert_eq "frozen log unchanged" "$before" "$(cat "$log")"

fresh="$TMPROOT/2026-03-05-other.md"
out="$(echo '{"verdict":"unknown","signals":[]}' | "$tool" "$fresh" tick)"
assert_contains "clock stamps a tick without at" "$(cat "$fresh")" "### tick 1 · 20"

out="$(echo '{}' | "$tool" "$TMPROOT/2026-03-06-x.md" tick 2>&1)"
assert_rc "incomplete tick" 2 "$?"
out="$(echo '{}' | "$tool" "$TMPROOT/2026-03-06-x.md" bogus 2>&1)"
assert_rc "bad kind" 2 "$?"
out="$(echo 'nope' | "$tool" "$TMPROOT/2026-03-06-x.md" tick 2>&1)"
assert_rc "stdin not JSON" 2 "$?"
out="$(echo '{"verdict":"healthy","signals":[]}' | "$tool" "$TMPROOT/notes.md" tick 2>&1)"
assert_rc "undated name" 2 "$?"
assert_eq "no file for a refused write" no "$([ -e "$TMPROOT/notes.md" ] && echo yes || echo no)"
out="$("$tool" -h)"
assert_contains "help names the freeze" "$out" "frozen"

finish
