#!/usr/bin/env bash
set -uo pipefail
S="$(cd "$(dirname "$0")/.." && pwd)/commit-msg.sh"
pass=0
fail=0
eq() { if [[ "$2" == "$3" ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1: want [$3] got [$2]" >&2; fi; }

eq "two items" "$("$S" feat/demo "add parser" "wire config")" "feat/demo: 1. add parser 2. wire config"
eq "one item" "$("$S" fix/x "repair the cache")" "fix/x: 1. repair the cache"
eq "whitespace" "$("$S" b "  spaced    out  " "tab	here")" "b: 1. spaced out 2. tab here"
eq "newline collapsed" "$("$S" b "line one
line two")" "b: 1. line one line two"
eq "single output line" "$("$S" b a b c | wc -l | tr -d ' ')" 1

"$S" feat/demo >/dev/null 2>&1
eq "no items rc" "$?" 2
"$S" >/dev/null 2>&1
eq "no args rc" "$?" 2
"$S" feat/demo "ok" "   " >/dev/null 2>&1
eq "blank item rc" "$?" 2
"$S" "  " "item" >/dev/null 2>&1
eq "blank branch rc" "$?" 2

echo "commit-msg.test: pass=$pass fail=$fail"
[[ $fail -eq 0 ]]
