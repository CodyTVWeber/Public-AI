#!/usr/bin/env bash
set -uo pipefail
S="$(cd "$(dirname "$0")/.." && pwd)/pir-state.sh"
root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
pass=0
fail=0
eq() { if [[ "$2" == "$3" ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1: want [$3] got [$2]" >&2; fi; }
st() { "$S" "$@" --state-root "$root/a"; }

st get >/dev/null 2>&1
eq "get before init rc" "$?" 3
st inc-round >/dev/null 2>&1
eq "inc before init rc" "$?" 3

"$S" init --state-root "$root/a" >/dev/null 2>&1
eq "init without topic rc" "$?" 2
st init --topic demo-topic >/dev/null 2>&1
eq "init rc" "$?" 0
eq "topic" "$(st get topic)" demo-topic
eq "round starts 0" "$(st get round)" 0
eq "max default" "$(st get max_rounds)" 3
eq "verify_round starts 0" "$(st get verify_round)" 0
eq "max_verify_rounds default" "$(st get max_verify_rounds)" 3
eq "atdd id empty" "$(st get atdd_subagent_id)" ""
eq "script id empty" "$(st get script_subagent_id)" ""
eq "regression pending" "$(st get regression_status)" pending
st init --topic demo-topic >/dev/null 2>&1
eq "re-init rc" "$?" 3
st set round=2 >/dev/null
st init --topic demo-topic --force >/dev/null 2>&1
eq "force re-init" "$(st get round)" 0

st set session_id=abc-123 implementer_id=cheap regression_command="make test && make lint" >/dev/null
eq "set string" "$(st get session_id)" abc-123
st set atdd_subagent_id=tid-1 script_subagent_id=sid-1 >/dev/null
eq "atdd id" "$(st get atdd_subagent_id)" tid-1
eq "script id" "$(st get script_subagent_id)" sid-1
eq "set spaced" "$(st get regression_command)" "make test && make lint"
eq "round stays int" "$(st get | jq -c '.round | type')" '"number"'
st set session_id= >/dev/null
eq "empty clears" "$(st get | jq -c '.session_id')" null

st set nope=1 >/dev/null 2>&1
eq "unknown key rc" "$?" 2
st set round=abc >/dev/null 2>&1
eq "non-int rc" "$?" 2
st set regression_status=great >/dev/null 2>&1
eq "bad enum rc" "$?" 2
st set noequals >/dev/null 2>&1
eq "bad pair rc" "$?" 2
st get nope >/dev/null 2>&1
eq "get unknown rc" "$?" 2

eq "inc 1" "$(st inc-round | jq -c .round)" 1
eq "inc 2" "$(st inc-round | jq -c .round)" 2
eq "inc 3" "$(st inc-round | jq -c .round)" 3
st inc-round >/dev/null 2>&1
eq "no 4th round rc" "$?" 3
eq "round stays 3" "$(st get round)" 3
eq "status exhausted" "$(st status | jq -c .exhausted)" true
eq "status left" "$(st status | jq -c .rounds_left)" 0
eq "verify status not exhausted" "$(st status | jq -c .verify_exhausted)" false
eq "inc-verify 1" "$(st inc-verify-round | jq -c .verify_round)" 1
eq "inc-verify 2" "$(st inc-verify-round | jq -c .verify_round)" 2
eq "inc-verify 3" "$(st inc-verify-round | jq -c .verify_round)" 3
st inc-verify-round >/dev/null 2>&1
eq "no 4th verify round rc" "$?" 3
eq "verify_round stays 3" "$(st get verify_round)" 3
eq "verify status exhausted" "$(st status | jq -c .verify_exhausted)" true
eq "verify status left" "$(st status | jq -c .verify_rounds_left)" 0
eq "implement round untouched" "$(st get round)" 3

"$S" init --topic custom --state-root "$root/b" --max-rounds 1 >/dev/null 2>&1
"$S" inc-round --state-root "$root/b" >/dev/null 2>&1
eq "max-rounds 1 first ok" "$?" 0
"$S" inc-round --state-root "$root/b" >/dev/null 2>&1
eq "max-rounds 1 second blocked" "$?" 3

"$S" init --topic "../bad" --state-root "$root/c" >/dev/null 2>&1
eq "bad topic rc" "$?" 2

eq "no temp or lock left" "$(ls -A "$root/a")" "state.json"
eq "valid json" "$(jq -e . "$root/a/state.json" >/dev/null && echo yes)" yes

echo "pir-state.test: pass=$pass fail=$fail"
[[ $fail -eq 0 ]]
