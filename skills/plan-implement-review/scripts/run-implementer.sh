#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  run-implementer.sh launch <state-dir> <prompt-file> <profile-id> [worktree-name] [worktree-ref]
  run-implementer.sh resume <state-dir> <prompt-file> <profile-id> <session-id> [cwd]
CLI fallback implementer; prefer a connected background agent (see plan-implement-review.md).
Profiles: see references/implementers.md (default Grok at medium effort, low effort for mechanical plans, Grok, Composer, claude-haiku, claude-sonnet)
Order: validate args and profile, check the CLI exists, then count the round via pir-state.sh.
A bad profile or a missing CLI never burns a round. Each launch/resume is one implement attempt;
exit 3 when max_rounds is spent (no extra attempt, CLI not started).
State: <state-dir>/state.json via pir-state.sh (round, implementer_id, session_id, reasoning_effort).
Env: PIR_MAX_ROUNDS (init only, default 3), MAX_TURNS (default 80), GROK_EXTRA_ARGS.
Stdout: JSON {round, profile, model, session_id, exit_code, out, err}.
Exit: 0 ok, 1 implementer CLI failed, 2 usage/unknown profile, 3 rounds spent, 127 CLI missing
USAGE
}

case "${1:-}" in -h|--help) usage; exit 0 ;; esac

cmd="${1:-}"
state_dir="${2:-}"
prompt_file="${3:-}"
profile="${4:-}"

if [[ -z "$cmd" || -z "$state_dir" || -z "$prompt_file" || -z "$profile" ]]; then
  usage
  exit 2
fi
case "$cmd" in
  launch) ;;
  resume) [[ -n "${5:-}" ]] || { echo "session id required for resume" >&2; exit 2; } ;;
  *) echo "Unknown command: $cmd" >&2; exit 2 ;;
esac
if [[ ! -f "$prompt_file" ]]; then
  echo "Prompt file not found: $prompt_file" >&2
  exit 2
fi

CLI=""
MODEL=""
EFFORT=""
GROK_EXTRA_ARGS="${GROK_EXTRA_ARGS:-}"

case "$profile" in
  grok-medium)
    CLI=grok
    MODEL=grok-4.5
    EFFORT=medium
    GROK_EXTRA_ARGS="${GROK_EXTRA_ARGS:---reasoning-effort medium}"
    ;;
  grok-low|grok-4.5-low|grok-4.5-low-effort|grok45-low)
    CLI=grok
    MODEL=grok-4.5
    EFFORT=low
    GROK_EXTRA_ARGS="${GROK_EXTRA_ARGS:---reasoning-effort low}"
    ;;
  composer-2.5)
    CLI=grok
    MODEL=grok-composer-2.5-fast
    ;;
  grok-4.5)
    CLI=grok
    MODEL=grok-4.5
    ;;
  claude-sonnet)
    CLI=claude
    MODEL=sonnet
    ;;
  claude-haiku)
    CLI=claude
    MODEL=haiku
    ;;
  *)
    echo "Unknown profile: $profile (see references/implementers.md)" >&2
    exit 2
    ;;
esac

if ! command -v "$CLI" >/dev/null 2>&1; then
  echo "CLI not found for profile $profile: $CLI" >&2
  exit 127
fi

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
state="$here/pir-state.sh"

if [[ ! -f "$state_dir/state.json" ]]; then
  topic="$(basename "$state_dir")"
  topic="${topic#pir-}"
  "$state" init --topic "$topic" --state-root "$state_dir" --max-rounds "${PIR_MAX_ROUNDS:-3}" >/dev/null
fi

"$state" inc-round --state-root "$state_dir" >/dev/null
round="$("$state" get round --state-root "$state_dir")"
"$state" set --state-root "$state_dir" "implementer_id=$profile" "reasoning_effort=$EFFORT" >/dev/null

out_json="${state_dir}/implement-round${round}.json"
err_log="${state_dir}/implement-round${round}.stderr.log"
prompt_text="$(cat "$prompt_file")"

extract_session_id() {
  jq -r '.sessionId // .session_id // .uuid // empty' "$1" 2>/dev/null || true
}

save_session() {
  "$state" set --state-root "$state_dir" "session_id=$1" >/dev/null
}

run_grok() {
  local model="$1" extra=()
  shift
  read -r -a extra <<<"$GROK_EXTRA_ARGS" || true
  grok --model "$model" --always-approve --max-turns "${MAX_TURNS:-80}" \
    ${extra[@]+"${extra[@]}"} \
    --output-format json "$@" >"$out_json" 2>"$err_log"
}

run_claude() {
  local model="$1"
  shift
  claude -p --model "$model" --dangerously-skip-permissions \
    --output-format json "$@" >"$out_json" 2>"$err_log"
}

rc=0
if [[ "$cmd" == "launch" ]]; then
  worktree_name="${5:-}"
  worktree_ref="${6:-}"
  sid="$("$state" get session_id --state-root "$state_dir")"
  [[ "$CLI" == grok && -n "$sid" ]] || sid="$(uuidgen | tr '[:upper:]' '[:lower:]')"
  save_session "$sid"
  case "$CLI" in
    grok)
      args=(--session-id "$sid" --prompt-file "$prompt_file")
      [[ -z "$worktree_name" ]] || args+=("--worktree=$worktree_name")
      [[ -z "$worktree_ref" ]] || args+=("--worktree-ref=$worktree_ref")
      run_grok "$MODEL" "${args[@]}" || rc=$?
      ;;
    claude)
      run_claude "$MODEL" --session-id "$sid" "$prompt_text" || rc=$?
      ;;
  esac
else
  session_id="$5"
  cwd="${6:-.}"
  save_session "$session_id"
  case "$CLI" in
    grok)
      run_grok "$MODEL" --resume "$session_id" --cwd "$cwd" --prompt-file "$prompt_file" || rc=$?
      ;;
    claude)
      (cd "$cwd" && run_claude "$MODEL" --resume "$session_id" "$prompt_text") || rc=$?
      ;;
  esac
fi

sid="$(extract_session_id "$out_json")"
[[ -z "$sid" ]] || save_session "$sid"

jq -n \
  --argjson round "$round" \
  --arg profile "$profile" \
  --arg model "$MODEL" \
  --arg session_id "$("$state" get session_id --state-root "$state_dir")" \
  --argjson exit_code "$rc" \
  --arg out "$out_json" \
  --arg err "$err_log" \
  '{round: $round, profile: $profile, model: $model, session_id: $session_id, exit_code: $exit_code, out: $out, err: $err}'

if [[ $rc -ne 0 ]]; then
  echo "implementer CLI exited $rc; see $err_log" >&2
  exit 1
fi
