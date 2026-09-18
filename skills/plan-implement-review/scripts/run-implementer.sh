#!/usr/bin/env bash
# CLI FALLBACK implementer launcher / resume helper.
#
# Preferred path (plan-implement-review skill): host BACKGROUND AGENT
#   (Grok spawn_subagent background:true + resume_from) — orchestrator stays connected.
# Use this script only when background agents are unavailable.
#
# Usage:
#   run-implementer.sh launch <state-dir> <prompt-file> <profile-id> [worktree-name] [worktree-ref]
#   run-implementer.sh resume <state-dir> <prompt-file> <profile-id> <session-id> [cwd]
#
# Profiles: grok-4.5-low (default Grok), grok-4.5, composer-2.5, claude-haiku, claude-sonnet
# Always persists session_id to <state-dir>/session_id for reuse.
set -euo pipefail

cmd="${1:-}"
state_dir="${2:-}"
prompt_file="${3:-}"
profile="${4:-}"

if [[ -z "$cmd" || -z "$state_dir" || -z "$prompt_file" || -z "$profile" ]]; then
  echo "Usage: $0 launch|resume <state-dir> <prompt-file> <profile-id> ..." >&2
  exit 2
fi

if [[ ! -f "$prompt_file" ]]; then
  echo "Prompt file not found: $prompt_file" >&2
  exit 2
fi

mkdir -p "$state_dir"
round_file="${state_dir}/round"
round="$(cat "$round_file" 2>/dev/null || echo 0)"
round=$((round + 1))
echo "$round" >"$round_file"

out_json="${state_dir}/implement-round${round}.json"
err_log="${state_dir}/implement-round${round}.stderr.log"
echo "$profile" >"${state_dir}/implementer_id"

prompt_text="$(cat "$prompt_file")"

extract_session_id() {
  local f="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r '
      .sessionId // .session_id // .uuid // empty
    ' "$f" 2>/dev/null || true
  fi
}

# Extra grok args (e.g. --reasoning-effort low) from GROK_EXTRA_ARGS or profile.
run_grok() {
  local model="$1"
  shift
  # shellcheck disable=SC2086
  grok --model "$model" --always-approve --max-turns "${MAX_TURNS:-80}" \
    ${GROK_EXTRA_ARGS:-} \
    --output-format json "$@" >"$out_json" 2>"$err_log"
}

run_claude() {
  local model="$1"
  shift
  claude -p --model "$model" --dangerously-skip-permissions \
    --output-format json "$@" >"$out_json" 2>"$err_log"
}

CLI=""
MODEL=""
GROK_EXTRA_ARGS="${GROK_EXTRA_ARGS:-}"

case "$profile" in
  grok-4.5-low|grok-4.5-low-effort|grok45-low)
    CLI=grok
    MODEL=grok-4.5
    # Cheap/fast default for Grok orchestrators
    GROK_EXTRA_ARGS="${GROK_EXTRA_ARGS:---reasoning-effort low}"
    ;;
  composer-2.5)
    CLI=grok
    MODEL=grok-composer-2.5-fast
    ;;
  grok-4.5)
    CLI=grok
    MODEL=grok-4.5
    # full/default effort — only when forced
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

# Persist effort hint for state.json consumers
if [[ "$profile" == grok-4.5-low* || "$profile" == grok45-low ]]; then
  echo "low" >"${state_dir}/reasoning_effort"
fi

if [[ "$cmd" == "launch" ]]; then
  worktree_name="${5:-}"
  worktree_ref="${6:-}"
  case "$CLI" in
    grok)
      # Stable session id for resume rounds (write immediately)
      if [[ -f "${state_dir}/session_id" && -s "${state_dir}/session_id" ]]; then
        sid="$(cat "${state_dir}/session_id")"
      else
        sid="$(uuidgen | tr '[:upper:]' '[:lower:]')"
        echo "$sid" >"${state_dir}/session_id"
      fi
      args=(--session-id "$sid" --prompt-file "$prompt_file")
      # Only pass worktree if caller requested (many repos forbid worktrees)
      if [[ -n "$worktree_name" ]]; then
        args+=(--worktree="$worktree_name")
      fi
      if [[ -n "$worktree_ref" ]]; then
        args+=(--worktree-ref="$worktree_ref")
      fi
      echo "session_id=$sid"
      run_grok "$MODEL" "${args[@]}"
      ;;
    claude)
      sid="$(uuidgen | tr '[:upper:]' '[:lower:]')"
      echo "$sid" >"${state_dir}/session_id"
      echo "session_id=$sid"
      run_claude "$MODEL" --session-id "$sid" "$prompt_text"
      ;;
  esac
elif [[ "$cmd" == "resume" ]]; then
  session_id="${5:?session id required}"
  cwd="${6:-.}"
  echo "$session_id" >"${state_dir}/session_id"
  case "$CLI" in
    grok)
      # Same model + same effort as launch
      run_grok "$MODEL" --resume "$session_id" --cwd "$cwd" --prompt-file "$prompt_file"
      ;;
    claude)
      (
        cd "$cwd"
        run_claude "$MODEL" --resume "$session_id" "$prompt_text"
      )
      ;;
  esac
else
  echo "Unknown command: $cmd" >&2
  exit 2
fi

sid="$(extract_session_id "$out_json")"
if [[ -n "${sid:-}" ]]; then
  echo "$sid" >"${state_dir}/session_id"
  echo "session_id=$sid"
elif [[ -f "${state_dir}/session_id" ]]; then
  echo "session_id=$(cat "${state_dir}/session_id")"
fi

echo "round=$round"
echo "profile=$profile"
echo "model=$MODEL"
echo "out=$out_json"
echo "err=$err_log"
