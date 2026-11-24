#!/usr/bin/env bash
set -uo pipefail
S="$(cd "$(dirname "$0")/.." && pwd)/verdict.sh"
pass=0
fail=0
eq() { if [[ "$2" == "$3" ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1: want [$3] got [$2]" >&2; fi; }
next() { "$S" "$@" 2>/dev/null | jq -r .next; }

eq "round 0 waits" "$(next --round 0 --max 3 --blocking 0)" wait
eq "approve -> gate" "$(next --round 1 --max 3 --blocking 0)" gate
eq "approve late round -> gate" "$(next --round 3 --max 3 --blocking 0)" gate
eq "findings, rounds left -> fix" "$(next --round 1 --max 3 --blocking 2)" fix
eq "findings, last-but-one -> fix" "$(next --round 2 --max 3 --blocking 1)" fix
eq "findings, rounds spent -> hand_off" "$(next --round 3 --max 3 --blocking 1)" hand_off
eq "round beyond max -> hand_off" "$(next --round 4 --max 3 --blocking 1)" hand_off
eq "gate passed -> done" "$(next --round 2 --max 3 --blocking 0 --phase gate --regression passed)" done
eq "gate skipped -> done" "$(next --round 1 --max 3 --blocking 0 --phase gate --regression skipped)" done
eq "gate failed, rounds left -> fix" "$(next --round 2 --max 3 --blocking 0 --phase gate --regression failed)" fix
eq "gate failed, rounds spent -> hand_off" "$(next --round 3 --max 3 --blocking 0 --phase gate --regression failed)" hand_off
eq "gate pending -> wait" "$(next --round 1 --max 3 --blocking 0 --phase gate --regression pending)" wait
eq "blocking beats passed gate" "$(next --round 1 --max 3 --blocking 1 --phase gate --regression passed)" fix
eq "max 1 findings -> hand_off" "$(next --round 1 --max 1 --blocking 1)" hand_off
eq "reason present" "$("$S" --round 1 --max 3 --blocking 1 | jq -r '.reason | length > 0')" true
eq "single-line json" "$("$S" --round 1 --max 3 --blocking 0 | wc -l | tr -d ' ')" 1

"$S" --round 1 --max 3 >/dev/null 2>&1
eq "missing blocking rc" "$?" 2
"$S" --round x --max 3 --blocking 0 >/dev/null 2>&1
eq "bad round rc" "$?" 2
"$S" --round 1 --max 0 --blocking 0 >/dev/null 2>&1
eq "bad max rc" "$?" 2
"$S" --round 1 --max 3 --blocking 0 --regression maybe >/dev/null 2>&1
eq "bad regression rc" "$?" 2
"$S" --round 1 --max 3 --blocking 0 --phase final >/dev/null 2>&1
eq "bad phase rc" "$?" 2
"$S" --nope >/dev/null 2>&1
eq "unknown flag rc" "$?" 2

echo "verdict.test: pass=$pass fail=$fail"
[[ $fail -eq 0 ]]
