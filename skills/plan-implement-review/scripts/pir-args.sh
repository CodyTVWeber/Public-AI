#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: pir-args.sh [--default PHASES] "<argstring>"
  Parses a plan-implement-review argument string into JSON on stdout:
  {phases[],ticket,plan_builder,no_plan,implementer,fix_comments,max_rounds,window,cadence,task}
Tokens:
  phases=<list|alias>   comma list of align,plan,implement,review,verify,watch,monitor
                        (contiguous, in order) or an alias. verify is inserted after
                        review (PIRV / PIRVW) when review is in a run that implements
                        or watches, and verify is not already listed
  ticket=X implementer=X plan-builder=X fix-comments=yes|no max-rounds=N
  window=<n>s|m|h|d cadence=<n>s|m|h|d   monitor phase window and tick spacing (null when absent)
  no-plan               skip the plan phase (checklist in the implementer prompt)
  plan-only | implement-only | review-only | verify-only   same as phases=plan | implement | review | verify
  anything else         joins the task text
Aliases: a align | ap align-plan | apir | apirv | apirw | apirvw | apirwm
         m monitor | pi plan-implement | ir implement-review | rw review-watch
         pir | pirv | pirw | pirvw | irw | verify
--default PHASES  phases when none given (default: plan,implement,review,verify,watch)
Exit: 0 ok, 2 usage / unknown phase / bad value
USAGE
}

die() { echo "pir-args: $*" >&2; exit 2; }

ALL="plan,implement,review,verify,watch"

alias_phases() {
  case "$1" in
    a) echo "align" ;;
    ap|align-plan) echo "align,plan" ;;
    apir|apirv|align-plan-implement-review) echo "align,plan,implement,review" ;;
    apirw|apirvw|align-plan-implement-review-watch) echo "align,$ALL" ;;
    m) echo "monitor" ;;
    apirwm|align-plan-implement-review-watch-monitor) echo "align,$ALL,monitor" ;;
    pi|plan-implement) echo "plan,implement" ;;
    ir|implement-review) echo "implement,review" ;;
    rw|review-watch) echo "review,watch" ;;
    pir|pirv|plan-implement-review) echo "plan,implement,review" ;;
    irw|implement-review-watch) echo "implement,review,watch" ;;
    pirw|pirvw|plan-implement-review-watch) echo "$ALL" ;;
    verify) echo "verify" ;;
    *) echo "$1" ;;
  esac
}

phase_index() {
  case "$1" in
    align) echo 0 ;;
    plan) echo 1 ;;
    implement) echo 2 ;;
    review) echo 3 ;;
    verify) echo 4 ;;
    watch) echo 5 ;;
    monitor) echo 6 ;;
    *) return 1 ;;
  esac
}

insert_verify() {
  local list="$1" out="" p
  needs_verify "$list" || { echo "$list"; return 0; }
  local IFS=,
  for p in $list; do
    out="${out:+$out,}$p"
    [[ "$p" == review ]] && out="$out,verify"
  done
  echo "$out"
}

needs_verify() {
  case ",$1," in
    *,verify,*) return 1 ;;
  esac
  case ",$1," in
    *,review,*watch*) return 0 ;;
    *,implement,*review*) return 0 ;;
  esac
  return 1
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

valid_duration() { [[ "$2" =~ ^[1-9][0-9]*[smhd]$ ]] || die "bad $1: $2"; }

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
window=""
cadence=""
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
    window=*) window="${tok#window=}"; valid_duration window "$window" ;;
    cadence=*) cadence="${tok#cadence=}"; valid_duration cadence "$cadence" ;;
    no-plan) no_plan=true ;;
    plan-only) phases="plan" ;;
    implement-only) phases="implement" ;;
    review-only) phases="review" ;;
    verify-only) phases="verify" ;;
    *) task="${task:+$task }$tok" ;;
  esac
done

[[ -n "$phases" ]] || phases="$(alias_phases "$default_phases")"
phases="$(insert_verify "$phases")"
validate_phases "$phases"
if [[ ( -n "$window" || -n "$cadence" ) && ",$phases," != *,monitor,* ]]; then
  die "window= and cadence= need the monitor phase"
fi

jq -n \
  --arg phases "$phases" \
  --arg ticket "$ticket" \
  --arg plan_builder "$plan_builder" \
  --argjson no_plan "$no_plan" \
  --arg implementer "$implementer" \
  --argjson fix_comments "$fix_comments" \
  --argjson max_rounds "$max_rounds" \
  --arg window "$window" \
  --arg cadence "$cadence" \
  --arg task "$task" \
  '{
    phases: ($phases | split(",")),
    ticket: (if $ticket == "" then null else $ticket end),
    plan_builder: $plan_builder,
    no_plan: $no_plan,
    implementer: (if $implementer == "" then null else $implementer end),
    fix_comments: $fix_comments,
    max_rounds: $max_rounds,
    window: (if $window == "" then null else $window end),
    cadence: (if $cadence == "" then null else $cadence end),
    task: $task
  }'
