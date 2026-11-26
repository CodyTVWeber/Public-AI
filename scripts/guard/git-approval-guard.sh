#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF2'
Usage: git-approval-guard.sh [--command STRING] [-h|--help]

Claude Code PreToolUse(Bash) hook. Reads hook JSON on stdin (.tool_input.command, .cwd).
  git commit / git push, any spelling (-C dir, --no-pager, env X=1, sh -c "...", chained, aliases)
  merge, cherry-pick, revert, am, rebase -x, commit-tree, update-ref, submodule foreach -> commit gate
  send-pack -> push gate
      -> permissionDecision "ask", naming the gate (commit or push)
  gh pr merge|create, glab mr merge|create, gh/glab api writes (-X POST|PUT|PATCH|DELETE, -f/-F/--input)
  an unknown git subcommand (possible alias), a command word built at runtime that names
  commit/push/merge, text piped into a shell, inline code in python/perl/ruby/node/awk, xargs
      -> permissionDecision "ask"
  --no-verify (also --no-v... abbreviations) on commit, push, merge, cherry-pick, revert, am, pull,
  rebase; -n on commit or am; any core.hooksPath write (git -c, git config, GIT_CONFIG_KEY_n,
  GIT_CONFIG_PARAMETERS, --config-env); CLEAN_CODE_SKIP=<non-0>, SKIP=..., HUSKY=0 on a gated command
      -> permissionDecision "deny"
  low-risk repo (top-level .mr-size has `risk: low`, cwd from hook JSON) and the command stays in it
  (no -C, --git-dir, --work-tree, cd) and parses cleanly -> commit, push, merge, forge writes
      -> permissionDecision "allow"; force/delete push there -> "deny"
  anything else -> exit 0, no output
--command STRING  analyse STRING instead of stdin (testing).
Known limit: a script, Makefile target, or package script that runs git inside (./push.sh, make push,
npm run release) cannot be analysed and passes unless its command line names commit or push.
Backstop for the AGENTS.md approval gate, not a substitute for it.
Exit: 0 decision (or none) emitted, 2 usage. Parse doubt on a commit/push -> ask.
EOF2
}

input=""
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --command)
    [ $# -ge 2 ] || { usage >&2; exit 2; }
    input="$(jq -nc --arg c "$2" '{tool_name:"Bash",tool_input:{command:$c}}' 2>/dev/null || printf '{"tool_input":{"command":"%s"}}' "$2")"
    ;;
  "") input="$(cat)" ;;
  *) usage >&2; exit 2 ;;
esac

shopt -s nocasematch
case "$input" in
  *git*|*commit*|*push*|*merge*|*cherry*|*revert*|*rebase*|*send-pack*|*update-ref*|*hookspath*|*SKIP*|*HUSKY*|*[[:space:]\;\&\|\(\`/\"\'\{]gh[[:space:]]*|*glab*|*" am "*) ;;
  *) exit 0 ;;
esac
shopt -u nocasematch

emit() {
  local decision="$1" reason="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -nc --arg d "$decision" --arg r "$reason" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}'
  else
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$decision" "$reason"
  fi
}

ASK_TAIL="Show git status and git diff --staged first, then wait for explicit approval. Approving a commit is not approving a push."

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
scan=""
for candidate in "$here/../clean-code/git-scan.sh" "$here/../../skills/setup-repo/assets/scripts/git-scan.sh"; do
  [ -x "$candidate" ] && { scan="$candidate"; break; }
done

tags=""
if [ -z "$scan" ] || ! tags="$("$scan" <<<"$input" 2>/dev/null)"; then
  case "$input" in
    *git*commit*|*git*push*|*git*merge*)
      emit ask "Approval gate: could not parse this git command; treated as commit/push. $ASK_TAIL"
      exit 0 ;;
    *) exit 0 ;;
  esac
fi

NL=$'\n'
tags="$NL$tags$NL"
has() { [[ "$tags" == *"$NL$1$NL"* ]]; }
has_any() { local t; for t in "$@"; do has "$t" && return 0; done; return 1; }

gate_names() {
  local gates=""
  has_any commit commit-like && gates="commit"
  has_any push push-like && gates="${gates:+$gates and }push"
  printf '%s' "$gates"
}

ask_reasons() {
  local gates="$1" out=""
  [ -n "$gates" ] && out="git $gates. AGENTS.md requires separate approval for each."
  has push-force && out="$out Force/delete push: say so explicitly."
  has_any mr-create forge-write && out="$out Forge write (merge request or pull request create/merge, or an API write)."
  has ask-unknown-git && out="$out Unknown git subcommand (an alias can hide a commit or push)."
  has ask-dynamic && out="$out The command word is built at runtime and its arguments name commit, push or merge."
  has ask-interpreter && out="$out Text piped into a shell or interpreter, or inline code, names a git commit or push."
  [ -n "$out" ] && has unparsed && out="$out (command only partly parsed)"
  printf '%s' "${out# }"
}

low_risk_repo() {
  local dir top
  dir="$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null || true)"
  [ -n "$dir" ] || dir="$PWD"
  top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || return 1
  grep -Eq '^[[:space:]]*risk:[[:space:]]*low[[:space:]]*$' "$top/.mr-size" 2>/dev/null
}
targets_elsewhere() { [[ "$input" =~ (-C[[:space:]]|--git-dir|--work-tree|(^|[^a-z])cd[[:space:]]) ]]; }
opaque() { has_any ask-unknown-git ask-dynamic ask-interpreter unparsed; }

gates="$(gate_names)"
reasons="$(ask_reasons "$gates")"

if has deny:no-verify; then
  emit deny "Blocked: --no-verify / -n skips the commit and push hooks. Ask the user to run it themselves."
elif has deny:hookspath; then
  emit deny "Blocked: writing core.hooksPath (git -c, git config, GIT_CONFIG_*, --config-env) bypasses the hooks. Ask the user to run it themselves."
elif has deny:skip || { [ -n "$gates" ] && has skip-soft; }; then
  emit deny "Blocked: CLEAN_CODE_SKIP / SKIP / HUSKY=0 bypasses the hooks. Ask the user to run it themselves."
elif has push-force && low_risk_repo; then
  emit deny "Blocked: force/delete push in a low-risk repo. Ask the user to run it themselves."
elif [ -n "$reasons" ] && low_risk_repo && ! targets_elsewhere && ! opaque; then
  emit allow "Low-risk repo (.mr-size risk: low): commit, push and merge allowed per rules/commit-and-ship.md."
elif [ -n "$reasons" ]; then
  emit ask "Approval gate: $reasons $ASK_TAIL"
fi
exit 0
