#!/usr/bin/env bash
set -uo pipefail
S="$(cd "$(dirname "$0")/.." && pwd)/pir-args.sh"
pass=0
fail=0
eq() { if [[ "$2" == "$3" ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1: want [$3] got [$2]" >&2; fi; }
run() { out="$("$S" "$@" 2>/dev/null)"; rc=$?; }
field() { jq -c "$1" <<<"$out"; }

run ""
eq "empty rc" "$rc" 0
eq "default phases" "$(field .phases)" '["plan","implement","review","watch"]'
eq "default max" "$(field .max_rounds)" 3
eq "default ticket" "$(field .ticket)" null
eq "default task" "$(field .task)" '""'

run "add a retry to the client phases=ir ticket=tkt_7 no-plan implementer=cheap-model fix-comments=yes max-rounds=2"
eq "full rc" "$rc" 0
eq "alias phases" "$(field .phases)" '["implement","review"]'
eq "ticket" "$(field .ticket)" '"tkt_7"'
eq "no_plan" "$(field .no_plan)" true
eq "implementer" "$(field .implementer)" '"cheap-model"'
eq "fix_comments" "$(field .fix_comments)" true
eq "max_rounds" "$(field .max_rounds)" 2
eq "task" "$(field .task)" '"add a retry to the client"'

for pair in "pi:plan,implement" "plan-implement:plan,implement" "implement-review:implement,review" \
  "rw:review,watch" "review-watch:review,watch" "pir:plan,implement,review" \
  "plan-implement-review:plan,implement,review" "irw:implement,review,watch" \
  "implement-review-watch:implement,review,watch" "pirw:plan,implement,review,watch" \
  "plan-implement-review-watch:plan,implement,review,watch"; do
  run "x phases=${pair%%:*}"
  eq "alias ${pair%%:*}" "$(jq -r '.phases | join(",")' <<<"$out")" "${pair#*:}"
done

for pair in "a:align" "ap:align,plan" "align-plan:align,plan" "apirw:align,plan,implement,review,watch" \
  "align-plan-implement-review-watch:align,plan,implement,review,watch" "align,plan,implement:align,plan,implement"; do
  run "x phases=${pair%%:*}"
  eq "align alias ${pair%%:*}" "$(jq -r '.phases | join(",")' <<<"$out")" "${pair#*:}"
done
run "tidy the template gallery phases=a"
eq "align-only task" "$(field .task)" '"tidy the template gallery"'
run "x phases=align,implement"
eq "align skip plan rc" "$rc" 2
run "x phases=plan,align"
eq "align after plan rc" "$rc" 2
run "x phases=watch,align"
eq "align after watch rc" "$rc" 2
run ""
eq "default stays without align" "$(field .phases)" '["plan","implement","review","watch"]'

run "x phases=m"
eq "monitor alone rc" "$rc" 0
eq "monitor alone" "$(field .phases)" '["monitor"]'
run "x phases=monitor"
eq "monitor long" "$(field .phases)" '["monitor"]'
for pair in "apirwm:align,plan,implement,review,watch,monitor" \
  "align-plan-implement-review-watch-monitor:align,plan,implement,review,watch,monitor" \
  "watch,monitor:watch,monitor" "review,watch,monitor:review,watch,monitor"; do
  run "x phases=${pair%%:*}"
  eq "monitor alias ${pair%%:*}" "$(jq -r '.phases | join(",")' <<<"$out")" "${pair#*:}"
done
run "x phases=plan,monitor"
eq "monitor skips phases rc" "$rc" 2
run "x phases=review,monitor"
eq "monitor skips watch rc" "$rc" 2
run "x phases=monitor,watch"
eq "monitor first order rc" "$rc" 2
run "x"
eq "default excludes monitor" "$(field .phases)" '["plan","implement","review","watch"]'
run "ship it phases=apirwm window=2h cadence=5m"
eq "window" "$(field .window)" '"2h"'
eq "cadence" "$(field .cadence)" '"5m"'
eq "monitor task" "$(field .task)" '"ship it"'
run "x phases=monitor window=90s"
eq "window seconds" "$(field .window)" '"90s"'
run "x phases=monitor window=1d cadence=30m"
eq "window days" "$(field .window)" '"1d"'
run "x"
eq "window default null" "$(field .window)" null
eq "cadence default null" "$(field .cadence)" null
run "x window=2h"
eq "window without monitor rc" "$rc" 2
run "x cadence=5m"
eq "cadence without monitor rc" "$rc" 2
for bad in "window=1w" "window=h" "window=0m" "window=1.5h" "window=" "cadence=ten" "cadence=-5m"; do
  run "x phases=monitor $bad"
  eq "bad $bad rc" "$rc" 2
done

run "x phases=plan,implement"
eq "list" "$(field .phases)" '["plan","implement"]'
run "x phases=review"
eq "single" "$(field .phases)" '["review"]'
run "x plan-only"
eq "plan-only" "$(field .phases)" '["plan"]'
run "x review-only"
eq "review-only" "$(field .phases)" '["review"]'
run "x implement-only"
eq "implement-only" "$(field .phases)" '["implement"]'
run "x fix-comments=no"
eq "fix-comments no" "$(field .fix_comments)" false

run "x phases=deploy"
eq "unknown phase rc" "$rc" 2
run "x phases=plan,review"
eq "gap rc" "$rc" 2
run "x phases=review,implement"
eq "order rc" "$rc" 2
run "x max-rounds=0"
eq "bad max rc" "$rc" 2
run "x max-rounds=abc"
eq "nan max rc" "$rc" 2
run "x fix-comments=maybe"
eq "bad fix rc" "$rc" 2

out="$("$S" --default plan,implement,review "task only" 2>/dev/null)"
eq "default flag" "$(field .phases)" '["plan","implement","review"]'
out="$("$S" --default plan,implement,review "x phases=rw" 2>/dev/null)"
eq "explicit beats default" "$(field .phases)" '["review","watch"]'

"$S" a b >/dev/null 2>&1
eq "two args rc" "$?" 2

echo "pir-args.test: pass=$pass fail=$fail"
[[ $fail -eq 0 ]]
