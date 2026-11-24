#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: research-ref.sh [repo] [--hook] [-h|--help]

Fetches the default branch from origin and reports how far HEAD is from it.
Prints JSON: {"ref","sha","behind","ahead","fetched"}.
  repo    path inside a git repo (default: current directory; --hook: .cwd from stdin JSON)
  --hook  SessionStart hook: reads hook JSON on stdin, prints additionalContext only when
          behind > 0 (silent otherwise), always exits 0
Env: RESEARCH_REF_TIMEOUT seconds for the fetch (default 8).
Exit: 0 ok (even when behind), 2 usage, 3 precondition failed (no repo/origin/default branch,
      or fetch failed; JSON still printed with fetched=false when a ref exists)
EOF
}

hook=0
repo=""
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --hook) hook=1 ;;
    -*) usage >&2; exit 2 ;;
    *) repo="$arg" ;;
  esac
done

if [ "$hook" -eq 1 ]; then
  input="$(cat 2>/dev/null || true)"
  hook_cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)"
  repo="${repo:-${hook_cwd:-${CLAUDE_PROJECT_DIR:-.}}}"
fi
repo="${repo:-.}"

fail() {
  echo "research-ref: $1" >&2
  [ "$hook" -eq 1 ] && exit 0
  exit 3
}

git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not a git repo: $repo"
git -C "$repo" remote get-url origin >/dev/null 2>&1 || fail "no origin remote"

default="$(git -C "$repo" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
default="${default#origin/}"
if [ -z "$default" ]; then
  for cand in main master; do
    if git -C "$repo" rev-parse --verify --quiet "refs/remotes/origin/$cand" >/dev/null; then
      default="$cand"
      break
    fi
  done
fi
if [ -z "$default" ]; then
  default="$(git -C "$repo" ls-remote --symref origin HEAD 2>/dev/null | awk '/^ref:/{sub("refs/heads/","",$2); print $2; exit}' || true)"
fi
[ -n "$default" ] || fail "cannot determine default branch"

limit="${RESEARCH_REF_TIMEOUT:-8}"
run_limited() {
  if command -v timeout >/dev/null 2>&1; then timeout "$limit" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$limit" "$@"
  elif command -v perl >/dev/null 2>&1; then perl -e 'alarm shift; exec @ARGV' "$limit" "$@"
  else "$@"
  fi
}

fetched=true
if ! GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh} -o BatchMode=yes -o ConnectTimeout=5" \
  run_limited git -C "$repo" fetch --quiet origin "$default" >/dev/null 2>&1; then
  fetched=false
  echo "research-ref: fetch failed (offline?); using last known origin/$default" >&2
fi

ref="origin/$default"
sha="$(git -C "$repo" rev-parse --verify --quiet "$ref" 2>/dev/null || true)"
[ -n "$sha" ] || fail "$ref not found locally"
counts="$(git -C "$repo" rev-list --left-right --count "HEAD...$ref" 2>/dev/null || echo "0 0")"
ahead="${counts%%[[:space:]]*}"
behind="${counts##*[[:space:]]}"
short="${sha:0:9}"

json="$(jq -nc --arg ref "$ref" --arg sha "$sha" --argjson behind "$behind" --argjson ahead "$ahead" \
  --argjson fetched "$fetched" '{ref:$ref,sha:$sha,behind:$behind,ahead:$ahead,fetched:$fetched}')"

if [ "$hook" -eq 1 ]; then
  if [ "$behind" -gt 0 ]; then
    stale=""
    [ "$fetched" = false ] && stale=" (fetch failed; ref may be stale)"
    jq -nc --arg ctx "$ref @ $short, local behind $behind — research from origin ref per rules/research-latest-main.md$stale" \
      '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}'
  fi
  exit 0
fi

printf '%s\n' "$json"
[ "$fetched" = true ] || exit 3
exit 0
