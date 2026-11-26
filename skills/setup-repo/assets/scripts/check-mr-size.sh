#!/usr/bin/env bash

set -uo pipefail

APP_SOFT_DEFAULT=400
APP_HARD_DEFAULT=800
SUPPORT_SOFT_DEFAULT=800
SUPPORT_HARD_DEFAULT=1600
DOCS_SOFT_DEFAULT=2000
DOCS_HARD_DEFAULT=4000

usage() {
  cat <<'EOF'
Usage: check-mr-size.sh [base-ref] [--only app|support|docs] [--print-base]
  --print-base   print the detected base ref and exit (0, or 3 when none is found)
  --only NAME    run one budget: app, support, or docs. Default runs all three.
Measures the current branch against its base. Three budgets on the same MR, counted apart:
  app      product source and every other counted file. MR_SIZE_SOFT (400) / MR_SIZE_HARD (800)
  support  shell scripts anywhere; scripts/ anywhere; repo-root tools/, bin/, hooks/,
           skills/, rules/, ci/; CI dirs;
           .claude/, .cursor/, .cursorrules; .githooks/, .husky/; lint and format config;
           Makefile and Dockerfile.
           MR_SIZE_SUPPORT_SOFT (800) / MR_SIZE_SUPPORT_HARD (1600)
  docs     *.md *.mdx *.rst *.adoc *.asciidoc, and anything under docs/, doc/, documentation/.
           MR_SIZE_DOCS_SOFT (2000) / MR_SIZE_DOCS_HARD (4000)
A file lands in the first match: docs, then support, then app. A rename counts as its destination.
Both counts omit lockfiles, snapshots, minified and generated files.
MR_BASE overrides base detection. CLEAN_CODE_SKIP=1 skips the check.
Low-risk: a tracked .mr-size at repo root with the line "risk: low" makes every hard limit advisory
       (exit 0). Only for repos shipping nothing that runs for users (docs, AI config, personal tooling).
Exit:  0 ok, warn, or low-risk advisory; 1 over a hard limit; 2 no changes to measure; 3 cannot measure.
EOF
}

ONLY=""
PRINT_BASE=0
BASE_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --print-base) PRINT_BASE=1 ;;
    --only)
      ONLY="${2:-}"
      shift
      case "$ONLY" in
        app|support|docs) ;;
        *) echo "mr-size: --only needs app, support, or docs" >&2; exit 3 ;;
      esac
      ;;
    *) BASE_ARG="$1" ;;
  esac
  shift
done

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

bucket_of() {
  local path base
  path="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  base="${path##*/}"
  case "$base" in
    *.md|*.mdx|*.rst|*.adoc|*.asciidoc) printf docs; return ;;
  esac
  case "/$path/" in
    */docs/*|*/doc/*|*/documentation/*) printf docs; return ;;
  esac
  case "$base" in
    *.sh|*.bash|makefile|dockerfile|.cursorrules) printf support; return ;;
    eslint.config.*|.eslintrc*|prettier.config.*|.prettierrc*) printf support; return ;;
    stylelint.config.*|.stylelintrc*|biome.json|.markdownlint*) printf support; return ;;
    *lint*.mjs|*lint*.js|*lint*.cjs) printf support; return ;;
  esac
  case "/$path/" in
    /scripts/*|/script/*|*/scripts/*|*/script/*) printf support; return ;;
    /tools/*|/bin/*|/hooks/*|/skills/*|/rules/*|/ci/*) printf support; return ;;
    */.github/*|*/.gitlab/*|*/.circleci/*) printf support; return ;;
    */.claude/*|*/.cursor/*|*/.githooks/*|*/.husky/*) printf support; return ;;
  esac
  printf app
}

BASE="$(detect_base "$BASE_ARG")"
if [ "$PRINT_BASE" -eq 1 ]; then
  [ -n "$BASE" ] && { echo "$BASE"; exit 0; }
  exit 3
fi
[ -z "$BASE" ] && { echo "mr-size: no base ref found; pass one as an argument"; exit 3; }

EXCLUDES=(
  ':(exclude)*.lock' ':(exclude)*lock.json' ':(exclude)*lock.yaml' ':(exclude)*.snap'
  ':(exclude)*.min.js' ':(exclude)*/generated/*' ':(exclude)*.generated.*'
)
RANGE="$BASE...HEAD"
stat="$(git diff --numstat -M "$RANGE" -- . "${EXCLUDES[@]}")"
if [ -z "$stat" ]; then
  echo "mr-size: no changes against $BASE"
  exit 2
fi

app_lines=0; app_files=0
support_lines=0; support_files=0
docs_lines=0; docs_files=0
added="" deleted="" path="" dest="" kind="" n=0
while IFS=$'\t' read -r added deleted path; do
  [ -n "$path" ] || continue
  [ "$added" = "-" ] && continue
  dest="$(rename_dest "$path")"
  kind="$(bucket_of "$dest")"
  n=$((added + deleted))
  case "$kind" in
    app) app_lines=$((app_lines + n)); app_files=$((app_files + 1)) ;;
    support) support_lines=$((support_lines + n)); support_files=$((support_files + 1)) ;;
    docs) docs_lines=$((docs_lines + n)); docs_files=$((docs_files + 1)) ;;
  esac
done <<<"$stat"

app_soft="${MR_SIZE_SOFT:-$APP_SOFT_DEFAULT}"
app_hard="${MR_SIZE_HARD:-$APP_HARD_DEFAULT}"
support_soft="${MR_SIZE_SUPPORT_SOFT:-$SUPPORT_SOFT_DEFAULT}"
support_hard="${MR_SIZE_SUPPORT_HARD:-$SUPPORT_HARD_DEFAULT}"
docs_soft="${MR_SIZE_DOCS_SOFT:-$DOCS_SOFT_DEFAULT}"
docs_hard="${MR_SIZE_DOCS_HARD:-$DOCS_HARD_DEFAULT}"
blocked=0

limit_for() {
  case "$1:$2" in
    app:soft) printf '%s' "$app_soft" ;;
    app:hard) printf '%s' "$app_hard" ;;
    support:soft) printf '%s' "$support_soft" ;;
    support:hard) printf '%s' "$support_hard" ;;
    docs:soft) printf '%s' "$docs_soft" ;;
    docs:hard) printf '%s' "$docs_hard" ;;
  esac
}

report() {
  local name="$1" total="${2%% *}" files="${2##* }" soft hard
  [ -n "$ONLY" ] && [ "$ONLY" != "$name" ] && return 0
  soft="$(limit_for "$name" soft)"
  hard="$(limit_for "$name" hard)"
  echo "mr-size $name: $total changed lines in $files files against $BASE (warn > $soft, block > $hard)"
  if [ "$total" -gt "$hard" ]; then
    echo "BLOCKED $name: over $hard lines. Split this $name change. The other budgets stay on this MR and are counted on their own."
    blocked=1
  elif [ "$total" -gt "$soft" ]; then
    echo "WARN $name: over $soft lines. Say why it cannot be split, or split it."
  fi
}

report app "$app_lines $app_files"
report support "$support_lines $support_files"
report docs "$docs_lines $docs_files"

if [ -z "$ONLY" ]; then
  echo "by directory:"
  printf '%s\n' "$stat" \
    | awk '$1!="-"{n=split($3,p,"/"); d=(n>1)?p[1]"/"((n>2)?p[2]:""):"."; t[d]+=$1+$2} END{for(d in t) printf "%6d  %s\n", t[d], d}' \
    | sort -rn | head -8
fi

if [ "$blocked" -eq 1 ] && grep -Eqx 'risk:[[:space:]]*low[[:space:]]*' "$(git rev-parse --show-toplevel)/.mr-size" 2>/dev/null; then
  echo "low-risk repo (.mr-size): size is advisory"
  exit 0
fi
[ "$blocked" -eq 1 ] && exit 1
exit 0
