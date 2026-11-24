#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: tracker-comment.sh <Plan|Implement rN|Review rN> <status> <url> [human-action]
  Prints the milestone comment (max 3 lines) per references/tracker-comments.md. Never posts.
  step      Plan, or Implement/Review with a round, as one argument ("Implement r1") or two
  status    done | blocked | needs review | done, needs review
  url       plan PR (Plan) or implement PR (Implement/Review); must start with http:// or https://
  action    what a human must do; required when status is blocked
Exit: 0 ok, 2 usage
USAGE
}

die() { echo "tracker-comment: $*" >&2; exit 2; }

case "${1:-}" in -h|--help) usage; exit 0 ;; esac
[[ $# -ge 3 ]] || { usage; exit 2; }

step="$1"
shift
case "$step" in
  Plan) label="Plan PR" ;;
  Implement|Review)
    round="$1"
    shift
    [[ "$round" =~ ^r[0-9]+$ ]] || die "round must look like r1: $round"
    step="$step $round"
    label="PR" ;;
  "Implement r"[0-9]*|"Review r"[0-9]*)
    [[ "$step" =~ ^(Implement|Review)\ r[0-9]+$ ]] || die "bad step: $step"
    label="PR" ;;
  *) die "step must be Plan, Implement rN or Review rN: $step" ;;
esac

[[ $# -ge 2 ]] || { usage; exit 2; }
status="$1"
url="$2"
action="${3:-}"
[[ $# -le 3 ]] || { usage; exit 2; }

case "$status" in
  done|blocked|"needs review"|"done, needs review") ;;
  *) die "bad status: $status" ;;
esac
[[ "$url" =~ ^https?://[^[:space:]]+$ ]] || die "url must be http(s) without spaces: $url"
action="$(printf '%s' "$action" | tr '\n\t' '  ' | sed -e 's/  */ /g' -e 's/^ //' -e 's/ $//')"
[[ "$status" != blocked || -n "$action" ]] || die "blocked needs a human action"

printf '%s — %s\n%s: %s\n' "$step" "$status" "$label" "$url"
[[ -z "$action" ]] || printf 'Human action: %s\n' "$action"
