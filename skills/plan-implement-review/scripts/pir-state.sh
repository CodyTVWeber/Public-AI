#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: pir-state.sh <cmd> [--topic T] [--state-root DIR] [args]
  init [--max-rounds N] [--force]   create state.json (round 0); exit 3 if it exists
  get [KEY]                         whole JSON, or one raw value
  set KEY=VALUE...                  update keys (atomic)
  inc-round                         round += 1; exit 3 when round == max_rounds (no extra round)
  inc-verify-round                  verify_round += 1; exit 3 when verify_round == max_verify_rounds
  status                            compact JSON summary with rounds_left
Keys: topic plan_path plan_branch plan_pr feat_branch implement_pr implementer_id session_id
      subagent_id reasoning_effort test_implementer_id test_session_id test_subagent_id
      script_implementer_id script_session_id script_subagent_id
      round max_rounds verify_round max_verify_rounds regression_command regression_status
      regression_status: pending|passed|failed|skipped; round keys: integers
      max_verify_rounds defaults to 3 (extra implement/review cycles after verify fails)
State root defaults to /tmp/pir-<topic>; state file is <root>/state.json.
--topic is required for init and for any command without --state-root.
Exit: 0 ok, 2 usage, 3 precondition (missing state, exists, rounds exhausted)
USAGE
}

die() { echo "pir-state: $1" >&2; exit "${2:-2}"; }

STRING_KEYS="topic plan_path plan_branch plan_pr feat_branch implement_pr implementer_id session_id subagent_id reasoning_effort test_implementer_id test_session_id test_subagent_id script_implementer_id script_session_id script_subagent_id regression_command regression_status"
INT_KEYS="round max_rounds verify_round max_verify_rounds"

is_key() {
  local k
  for k in $STRING_KEYS $INT_KEYS; do [[ "$k" == "$1" ]] && return 0; done
  return 1
}

is_int_key() {
  local k
  for k in $INT_KEYS; do [[ "$k" == "$1" ]] && return 0; done
  return 1
}

cmd="${1:-}"
case "$cmd" in
  -h|--help|"") usage; [[ -n "$cmd" ]] && exit 0 || exit 2 ;;
  init|get|set|inc-round|inc-verify-round|status) shift ;;
  *) usage; exit 2 ;;
esac

topic=""
root=""
max_rounds=3
force=false
rest=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --topic) [[ $# -ge 2 ]] || die "--topic needs a value"; topic="$2"; shift 2 ;;
    --state-root) [[ $# -ge 2 ]] || die "--state-root needs a value"; root="$2"; shift 2 ;;
    --max-rounds) [[ $# -ge 2 ]] || die "--max-rounds needs a value"; max_rounds="$2"; shift 2 ;;
    --force) force=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) rest+=("$1"); shift ;;
  esac
done

if [[ -n "$topic" && ! "$topic" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  die "invalid topic: $topic"
fi
if [[ -z "$root" ]]; then
  [[ -n "$topic" ]] || die "--topic or --state-root required"
  root="/tmp/pir-$topic"
fi
file="$root/state.json"
lock="$root/.lock"

bump_round() {
  local key="$1" maxkey="$2" n max
  require_state
  acquire_lock
  n="$(jq -r --arg k "$key" '.[$k] // 0' "$file")"
  max="$(jq -r --arg k "$maxkey" '.[$k] // 3' "$file")"
  if (( n >= max )); then
    echo "pir-state: $key exhausted ($n/$max); hand off, no extra round" >&2
    exit 3
  fi
  write_state "$(jq --arg k "$key" --arg m "$maxkey" --argjson max "$max" \
    '.[$k] = ((.[$k] // 0) + 1) | .[$m] = $max' "$file")"
  jq --arg k "$key" --arg m "$maxkey" '{($k): .[$k], ($m): .[$m]}' "$file"
}

acquire_lock() {
  local i=0
  until mkdir "$lock" 2>/dev/null; do
    i=$((i + 1))
    [[ $i -le 100 ]] || die "state locked: $lock" 3
    sleep 0.1
  done
  trap 'rmdir "$lock" 2>/dev/null || true' EXIT
}

require_state() {
  [[ -f "$file" ]] || die "no state at $file (run init)" 3
}

write_state() {
  local tmp
  tmp="$(mktemp "$root/.state.XXXXXX")"
  if ! printf '%s\n' "$1" >"$tmp"; then rm -f "$tmp"; die "write failed" 3; fi
  mv "$tmp" "$file"
}

case "$cmd" in
  init)
    [[ -n "$topic" ]] || die "init needs --topic"
    [[ "$max_rounds" =~ ^[1-9][0-9]*$ ]] || die "bad --max-rounds: $max_rounds"
    mkdir -p "$root"
    acquire_lock
    if [[ -f "$file" && "$force" != true ]]; then
      die "state exists: $file (use get, or --force to reset)" 3
    fi
    write_state "$(jq -n --arg topic "$topic" --argjson max "$max_rounds" '{
      topic: $topic, plan_path: null, plan_branch: null, plan_pr: null,
      feat_branch: null, implement_pr: null, implementer_id: null,
      session_id: null, subagent_id: null, reasoning_effort: null,
      test_implementer_id: null, test_session_id: null, test_subagent_id: null,
      script_implementer_id: null, script_session_id: null, script_subagent_id: null,
      round: 0, max_rounds: $max, verify_round: 0, max_verify_rounds: 3,
      regression_command: null, regression_status: "pending"
    }')"
    jq . "$file"
    ;;
  get)
    require_state
    if [[ ${#rest[@]} -eq 0 ]]; then
      jq . "$file"
    else
      is_key "${rest[0]}" || die "unknown key: ${rest[0]}"
      jq -r --arg k "${rest[0]}" '.[$k] // empty' "$file"
    fi
    ;;
  set)
    [[ ${#rest[@]} -gt 0 ]] || die "set needs KEY=VALUE"
    require_state
    acquire_lock
    state="$(cat "$file")"
    for kv in "${rest[@]}"; do
      [[ "$kv" == *=* ]] || die "bad pair (want KEY=VALUE): $kv"
      k="${kv%%=*}"
      v="${kv#*=}"
      is_key "$k" || die "unknown key: $k"
      if is_int_key "$k"; then
        [[ "$v" =~ ^[0-9]+$ ]] || die "$k must be an integer: $v"
        state="$(jq --arg k "$k" --argjson v "$v" '.[$k] = $v' <<<"$state")"
      else
        if [[ "$k" == "regression_status" ]]; then
          case "$v" in pending|passed|failed|skipped) ;; *) die "bad regression_status: $v" ;; esac
        fi
        state="$(jq --arg k "$k" --arg v "$v" '.[$k] = (if $v == "" then null else $v end)' <<<"$state")"
      fi
    done
    write_state "$state"
    jq . "$file"
    ;;
  inc-round)
    bump_round round max_rounds round
    ;;
  inc-verify-round)
    bump_round verify_round max_verify_rounds verify_round
    ;;
  status)
    require_state
    jq '{
      topic, round, max_rounds,
      rounds_left: (.max_rounds - .round),
      exhausted: (.round >= .max_rounds),
      verify_round, max_verify_rounds,
      verify_rounds_left: ((.max_verify_rounds // 3) - (.verify_round // 0)),
      verify_exhausted: ((.verify_round // 0) >= (.max_verify_rounds // 3)),
      implementer_id, session_id, subagent_id,
      test_implementer_id, test_subagent_id, script_implementer_id, script_subagent_id,
      plan_pr, implement_pr, regression_status
    }' "$file"
    ;;
esac
