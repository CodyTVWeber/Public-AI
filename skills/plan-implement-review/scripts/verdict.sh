#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: verdict.sh --round N --max M --blocking K [--regression passed|failed|skipped|pending] [--phase review|gate|verify]
  Pure routing function; prints {"next": ..., "reason": ...} on stdout.
  --round N        implement attempts used so far (0 = implementer not finished yet).
                   Phase verify: extra implement/review rounds already used (0 = none yet)
  --max M          max implement attempts. Phase verify: max extra rounds (default 3)
  --blocking K     blocking findings from the review. Phase verify: product-wrong findings
  --regression S   gate result (phase gate only; pending = still running)
  --phase P        review (default): just reviewed. gate: regression gate just ran.
                   verify: proof failed or passed after review
Routes:
  wait      round 0 (not verify), or gate still pending
  gate      review phase, no blocking findings: run regression-gate.sh
  fix       blocking findings or failed gate, round < max: write review-roundN.md, resume implementer.
            Phase verify: product wrong, extra rounds left: implement → review → verify again
  hand_off  blocking findings or failed gate, round >= max: stop, give findings + ids to the user, skip gate
  done      gate passed or skipped (note skipped in the report). Phase verify: proof passed
Exit: 0 routed, 2 usage
USAGE
}

die() { echo "verdict: $*" >&2; usage; exit 2; }

round=""
max=""
blocking=""
regression="pending"
phase="review"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --round) [[ $# -ge 2 ]] || die "--round needs a value"; round="$2"; shift 2 ;;
    --max) [[ $# -ge 2 ]] || die "--max needs a value"; max="$2"; shift 2 ;;
    --blocking) [[ $# -ge 2 ]] || die "--blocking needs a value"; blocking="$2"; shift 2 ;;
    --regression) [[ $# -ge 2 ]] || die "--regression needs a value"; regression="$2"; shift 2 ;;
    --phase) [[ $# -ge 2 ]] || die "--phase needs a value"; phase="$2"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ "$round" =~ ^[0-9]+$ ]] || die "--round must be a non-negative integer"
[[ "$max" =~ ^[1-9][0-9]*$ ]] || die "--max must be a positive integer"
[[ "$blocking" =~ ^[0-9]+$ ]] || die "--blocking must be a non-negative integer"
case "$regression" in passed|failed|skipped|pending) ;; *) die "bad --regression: $regression" ;; esac
case "$phase" in review|gate|verify) ;; *) die "bad --phase: $phase" ;; esac

emit() {
  jq -nc --arg next "$1" --arg reason "$2" '{next: $next, reason: $reason}'
}

if [[ "$phase" == verify ]]; then
  if (( blocking > 0 )); then
    if (( round < max )); then
      emit fix "verify failed, extra implement/review round $round of $max"
    else
      emit hand_off "verify failed, extra rounds spent ($round of $max)"
    fi
  else
    emit done "verify passed"
  fi
elif (( round == 0 )); then
  emit wait "no implement attempt finished yet"
elif (( blocking > 0 )); then
  if (( round < max )); then
    emit fix "$blocking blocking finding(s), round $round of $max"
  else
    emit hand_off "$blocking blocking finding(s), rounds spent ($round of $max); skip gate"
  fi
elif [[ "$phase" == review ]]; then
  emit gate "approved; run the regression gate"
else
  case "$regression" in
    pending) emit wait "regression gate still running" ;;
    passed) emit done "regression passed" ;;
    skipped) emit done "regression skipped; state the reason in the report" ;;
    failed)
      if (( round < max )); then
        emit fix "regression failed, round $round of $max; log tail is the fix list"
      else
        emit hand_off "regression failed, rounds spent ($round of $max)"
      fi ;;
  esac
fi
