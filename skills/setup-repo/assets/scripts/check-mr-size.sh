#!/usr/bin/env bash

set -uo pipefail

case "${1:-}" in
  -h|--help)
    cat <<'EOF'
Usage: check-mr-size.sh [base-ref | --print-base]
  --print-base   print the detected base ref and exit (0, or 3 when none is found)
Measures the current branch against its base and enforces the small-MR budget.
Env:   MR_SIZE_SOFT (default 400) warn above; MR_SIZE_HARD (default 800) fail above;
       MR_BASE overrides base detection; CLEAN_CODE_SKIP=1 skips the check.
Both counts omit lockfiles, snapshots, minified and generated files.
The warning counts every other changed line. The hard block also omits documentation
       (Markdown, rst, adoc, and docs/, doc/, documentation/) and repo-support files
       (AI setup under .claude/ and .cursor/, scripts/lint, scripts/clean-code,
       scripts/guard, .githooks/, .husky/, and lint or format config).
Low-risk: a tracked .mr-size at repo root with the line "risk: low" makes the hard limit advisory
       (exit 0). Only for repos shipping nothing that runs for users (docs, AI config, personal tooling).
Exit:  0 ok, warn, or low-risk advisory; 1 over the hard limit; 2 no changes to measure; 3 cannot measure (not a repo, no base ref).
EOF
    exit 0 ;;
esac

SOFT="${MR_SIZE_SOFT:-400}"
HARD="${MR_SIZE_HARD:-800}"
EXCLUDES=(
  ':(exclude)*.lock' ':(exclude)*lock.json' ':(exclude)*lock.yaml' ':(exclude)*.snap'
  ':(exclude)*.min.js' ':(exclude)*/generated/*' ':(exclude)*.generated.*'
)

rename_dest() {
  local p="$1" pre mid suf
  case "$p" in
    *' => '*) ;;
    *) printf '%s' "$p"; return ;;
  esac
  case "$p" in
    *'{'*'}'*)
      pre="${p%%\{*}"
      suf="${p##*\}}"
      mid="${p#*\{}"
      mid="${mid%%\}*}"
      printf '%s%s%s' "$pre" "${mid#* => }" "$suf"
      ;;
    *) printf '%s' "${p#* => }" ;;
  esac
}

omit_from_hard() {
  local path base
  path="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  base="${path##*/}"
  case "/$path/" in
    */docs/*|*/doc/*|*/documentation/*) return 0 ;;
    */.claude/*|*/.cursor/*|*/.githooks/*|*/.husky/*) return 0 ;;
    */scripts/lint/*|*/scripts/clean-code/*|*/scripts/guard/*) return 0 ;;
  esac
  case "$base" in
    .cursorrules|*.md|*.mdx|*.rst|*.adoc|*.asciidoc) return 0 ;;
    eslint.config.*|.eslintrc*|prettier.config.*|.prettierrc*) return 0 ;;
    stylelint.config.*|.stylelintrc*|biome.json|.markdownlint*) return 0 ;;
    *lint*.sh|*lint*.mjs|*lint*.js|*lint*.cjs) return 0 ;;
  esac
  return 1
}

sum_stat() {
  local added deleted path
  ALL_LINES=0
  HARD_LINES=0
  FILE_COUNT=0
  [ -n "$1" ] || return 0
  while IFS=$'\t' read -r added deleted path; do
    [ -n "$path" ] || continue
    [ "$added" = "-" ] && continue
    FILE_COUNT=$((FILE_COUNT + 1))
    ALL_LINES=$((ALL_LINES + added + deleted))
    omit_from_hard "$(rename_dest "$path")" || HARD_LINES=$((HARD_LINES + added + deleted))
  done <<<"$1"
}

[ "${CLEAN_CODE_SKIP:-0}" = "1" ] && { echo "mr-size: skipped (CLEAN_CODE_SKIP=1)"; exit 0; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "mr-size: not a git repo"; exit 3; }

detect_base() {
  local ref
  for ref in "${1:-}" "${MR_BASE:-}" \
    "$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)" \
    origin/main origin/master main master; do
    [ -n "$ref" ] && git rev-parse --verify --quiet "$ref" >/dev/null && { echo "$ref"; return; }
  done
}

BASE_ARG="${1:-}"
[ "$BASE_ARG" = "--print-base" ] && BASE_ARG=""
BASE="$(detect_base "$BASE_ARG")"
if [ "${1:-}" = "--print-base" ]; then
  [ -n "$BASE" ] && { echo "$BASE"; exit 0; }
  exit 3
fi
[ -z "$BASE" ] && { echo "mr-size: no base ref found; pass one as an argument"; exit 3; }

RANGE="$BASE...HEAD"
if [ -z "$(git diff --numstat "$RANGE" -- . "${EXCLUDES[@]}")" ]; then
  echo "mr-size: no changes against $BASE"
  exit 2
fi

stat="$(git diff --numstat "$RANGE" -- . "${EXCLUDES[@]}")"
sum_stat "$stat"

echo "mr-size: $ALL_LINES changed lines in $FILE_COUNT files against $BASE (warn > $SOFT, block > $HARD)"
[ "$HARD_LINES" -eq "$ALL_LINES" ] || echo "hard limit counts $HARD_LINES lines; documentation and supporting files are omitted"
echo "by directory:"
printf '%s\n' "$stat" \
  | awk '$1!="-"{n=split($3,p,"/"); d=(n>1)?p[1]"/"((n>2)?p[2]:""):"."; t[d]+=$1+$2} END{for(d in t) printf "%6d  %s\n", t[d], d}' \
  | sort -rn | head -8

low_risk=0
if grep -Eqx 'risk:[[:space:]]*low[[:space:]]*' "$(git rev-parse --show-toplevel)/.mr-size" 2>/dev/null; then
  low_risk=1
fi

if [ "$HARD_LINES" -gt "$HARD" ] && [ "$low_risk" -eq 1 ]; then
  echo "low-risk repo (.mr-size): size is advisory"
  exit 0
elif [ "$HARD_LINES" -gt "$HARD" ]; then
  echo "BLOCKED: over $HARD lines counted toward the hard limit. Split by concern (refactor / behavior / deps / generated), stack the pieces."
  echo "See .claude/rules/small-mrs.md. Override once with CLEAN_CODE_SKIP=1 and say why in the MR."
  exit 1
elif [ "$ALL_LINES" -gt "$SOFT" ]; then
  echo "WARN: over $SOFT lines. Say why it cannot be split, or split it."
fi
exit 0
