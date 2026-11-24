#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: pir-args.sh [--default PHASES] "<argstring>"
  Parses a plan-implement-review argument string into JSON on stdout:
  {phases[],ticket,plan_builder,no_plan,implementer,fix_comments,max_rounds,task}
Tokens:
  phases=<list|alias>   comma list of plan,implement,review,watch (contiguous, in order) or an alias
  ticket=X implementer=X plan-builder=X fix-comments=yes|no max-rounds=N
  no-plan               skip the plan phase (checklist in the implementer prompt)
  plan-only | implement-only | review-only   same as phases=plan | implement | review
  anything else         joins the task text
Aliases: pi plan-implement | ir implement-review | rw review-watch | pir plan-implement-review
         irw implement-review-watch | pirw plan-implement-review-watch
--default PHASES  phases when none given (default: plan,implement,review,watch)
Exit: 0 ok, 2 usage / unknown phase / bad value
USAGE
}

die() { echo "pir-args: $*" >&2; exit 2; }

ALL="plan,implement,review,watch"

alias_phases() {
  case "$1" in
    pi|plan-implement) echo "plan,implement" ;;
    ir|implement-review) echo "implement,review" ;;
    rw|review-watch) echo "review,watch" ;;
    pir|plan-implement-review) echo "plan,implement,review" ;;
    irw|implement-review-watch) echo "implement,review,watch" ;;
    pirw|plan-implement-review-watch) echo "$ALL" ;;
    *) echo "$1" ;;
  esac
}

phase_index() {
  case "$1" in
    plan) echo 0 ;;
    implement) echo 1 ;;
    review) echo 2 ;;
    watch) echo 3 ;;
    *) return 1 ;;
  esac
}

validate_phases() {
  local list="$1" prev=-1 idx p
  [[ -n "$list" ]] || die "empty phases"
  local IFS=,
  for p in $list; do
    idx="$(phase_index "$p")" || die "unknown phase: $p"
    if (( prev >= 0 && idx != prev + 1 )); then
      die "phases must be contiguous and in order: $list"
    fi
    prev=$idx
  done
}

default_phases="$ALL"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --default) [[ $# -ge 2 ]] || { usage; exit 2; }; default_phases="$2"; shift 2 ;;
    --) shift; break ;;
    *) break ;;
  esac
done
[[ $# -le 1 ]] || { usage; exit 2; }
argstring="${1:-}"

phases=""
ticket=""
plan_builder="self"
no_plan=false
implementer=""
fix_comments=false
max_rounds=3
task=""

read -r -a toks <<<"$argstring" || true
for tok in ${toks[@]+"${toks[@]}"}; do
  case "$tok" in
    phases=*) phases="$(alias_phases "${tok#phases=}")" ;;
    ticket=*) ticket="${tok#ticket=}" ;;
    plan-builder=*) plan_builder="${tok#plan-builder=}" ;;
    implementer=*) implementer="${tok#implementer=}" ;;
    fix-comments=*)
      case "${tok#fix-comments=}" in
        yes|true|1|on) fix_comments=true ;;
        no|false|0|off) fix_comments=false ;;
        *) die "bad fix-comments value: ${tok#fix-comments=}" ;;
      esac ;;
    max-rounds=*)
      max_rounds="${tok#max-rounds=}"
      [[ "$max_rounds" =~ ^[1-9][0-9]*$ ]] || die "bad max-rounds: $max_rounds" ;;
    no-plan) no_plan=true ;;
    plan-only) phases="plan" ;;
    implement-only) phases="implement" ;;
    review-only) phases="review" ;;
    *) task="${task:+$task }$tok" ;;
  esac
done

[[ -n "$phases" ]] || phases="$(alias_phases "$default_phases")"
validate_phases "$phases"

jq -n \
  --arg phases "$phases" \
  --arg ticket "$ticket" \
  --arg plan_builder "$plan_builder" \
  --argjson no_plan "$no_plan" \
  --arg implementer "$implementer" \
  --argjson fix_comments "$fix_comments" \
  --argjson max_rounds "$max_rounds" \
  --arg task "$task" \
  '{
    phases: ($phases | split(",")),
    ticket: (if $ticket == "" then null else $ticket end),
    plan_builder: $plan_builder,
    no_plan: $no_plan,
    implementer: (if $implementer == "" then null else $implementer end),
    fix_comments: $fix_comments,
    max_rounds: $max_rounds,
    task: $task
  }'
