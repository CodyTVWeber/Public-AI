#!/usr/bin/env bash
# Measure the size of the current branch against its base and enforce the small-MR budget.
#
# Usage: check-mr-size.sh [base-ref]
# Env:   MR_SIZE_SOFT (default 400) warn above; MR_SIZE_HARD (default 800) fail above;
#        MR_BASE overrides base detection; CLEAN_CODE_SKIP=1 skips the check.
# Exit:  0 ok or warn, 1 over the hard limit, 2 nothing to measure.

set -uo pipefail

SOFT="${MR_SIZE_SOFT:-400}"
HARD="${MR_SIZE_HARD:-800}"
EXCLUDES=(
  ':(exclude)*.lock' ':(exclude)*lock.json' ':(exclude)*lock.yaml' ':(exclude)*.snap'
  ':(exclude)*.min.js' ':(exclude)*/generated/*' ':(exclude)*.generated.*'
)

[ "${CLEAN_CODE_SKIP:-0}" = "1" ] && { echo "mr-size: skipped (CLEAN_CODE_SKIP=1)"; exit 0; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "mr-size: not a git repo"; exit 2; }

detect_base() {
  local ref
  for ref in "${1:-}" "${MR_BASE:-}" \
    "$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)" \
    origin/main origin/master main master; do
    [ -n "$ref" ] && git rev-parse --verify --quiet "$ref" >/dev/null && { echo "$ref"; return; }
  done
}

BASE="$(detect_base "${1:-}")"
[ -z "$BASE" ] && { echo "mr-size: no base ref found; pass one as an argument"; exit 2; }

RANGE="$BASE...HEAD"
if [ -z "$(git diff --numstat "$RANGE" -- . "${EXCLUDES[@]}")" ]; then
  echo "mr-size: no changes against $BASE"
  exit 2
fi

total=$(git diff --numstat "$RANGE" -- . "${EXCLUDES[@]}" | awk '$1!="-"{s+=$1+$2} END{print s+0}')
files=$(git diff --numstat "$RANGE" -- . "${EXCLUDES[@]}" | wc -l | tr -d ' ')

echo "mr-size: $total changed lines in $files files against $BASE (warn > $SOFT, block > $HARD)"
echo "by directory:"
git diff --numstat "$RANGE" -- . "${EXCLUDES[@]}" \
  | awk '$1!="-"{n=split($3,p,"/"); d=(n>1)?p[1]"/"((n>2)?p[2]:""):"."; t[d]+=$1+$2} END{for(d in t) printf "%6d  %s\n", t[d], d}' \
  | sort -rn | head -8

if [ "$total" -gt "$HARD" ]; then
  echo "BLOCKED: over $HARD lines. Split by concern (refactor / behavior / deps / generated), stack the pieces."
  echo "See .claude/rules/small-mrs.md. Override once with CLEAN_CODE_SKIP=1 and say why in the MR."
  exit 1
elif [ "$total" -gt "$SOFT" ]; then
  echo "WARN: over $SOFT lines. Say why it cannot be split, or split it."
fi
exit 0
