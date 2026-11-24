#!/usr/bin/env bash
set -uo pipefail
S="$(cd "$(dirname "$0")/.." && pwd)/tracker-comment.sh"
pass=0
fail=0
eq() { if [[ "$2" == "$3" ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1: want [$3] got [$2]" >&2; fi; }
U=https://example.test/pull/1

eq "implement one-arg step" "$("$S" "Implement r1" "done, needs review" $U "confirm the copy")" "Implement r1 — done, needs review
PR: $U
Human action: confirm the copy"
eq "implement two-arg step" "$("$S" Implement r2 done $U)" "Implement r2 — done
PR: $U"
eq "review" "$("$S" "Review r3" done $U)" "Review r3 — done
PR: $U"
eq "plan" "$("$S" Plan done $U)" "Plan — done
Plan PR: $U"
eq "blocked with action" "$("$S" Plan blocked $U "pick a store")" "Plan — blocked
Plan PR: $U
Human action: pick a store"
eq "needs review" "$("$S" "Review r1" "needs review" $U | head -1)" "Review r1 — needs review"
eq "max 3 lines" "$("$S" "Implement r1" blocked $U "do the thing" | wc -l | tr -d ' ')" 3
eq "action collapsed" "$("$S" Plan done $U "a
b" | tail -1)" "Human action: a b"

"$S" Plan blocked $U >/dev/null 2>&1
eq "blocked needs action rc" "$?" 2
"$S" Plan finished $U >/dev/null 2>&1
eq "bad status rc" "$?" 2
"$S" Deploy done $U >/dev/null 2>&1
eq "bad step rc" "$?" 2
"$S" Implement done $U >/dev/null 2>&1
eq "missing round rc" "$?" 2
"$S" "Implement r1x" done $U >/dev/null 2>&1
eq "bad round rc" "$?" 2
"$S" Plan done not-a-url >/dev/null 2>&1
eq "bad url rc" "$?" 2
"$S" Plan done >/dev/null 2>&1
eq "missing url rc" "$?" 2
"$S" Plan done $U action extra >/dev/null 2>&1
eq "too many args rc" "$?" 2

echo "tracker-comment.test: pass=$pass fail=$fail"
[[ $fail -eq 0 ]]
