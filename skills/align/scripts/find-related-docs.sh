#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: find-related-docs.sh <topic words...> [--root DIR]   (-h|--help)

Ranks existing docs that share terms with the topic. Stdout JSON:
  {terms[], results[{path, kind, score, title, date?}]}   (max 15, best first)

Searched (markdown only, skipping node_modules, .git, vendor):
  files under any docs/, doc/, adr/ or plans/ directory, README*, AGENTS.md at the root
Terms: topic words of 3+ letters, lowercased, stop words dropped.
Score per term: +1 in the body, +2 in the path, +2 in the title (first heading).
kind: glossary | adr | spec | plan | readme | other
date: from a YYYY-MM-DD filename prefix or a `Date:` line in the first 10 lines.
--root DIR  repo root (default: git top level, else the current directory)

Exit: 0 ok (results may be empty), 2 usage, 3 root is not a directory
USAGE
}

STOP_WORDS=' the and for with that this from into onto will should would could when what which where have has not are was were been add make use using new '
MAX_RESULTS=15
DOC_DIR_RE='(^|/)(docs?|adr|plans)/'

die() { echo "find-related-docs: $*" >&2; exit "${2:-2}"; }

normalize_terms() {
  local word
  printf '%s\n' "$@" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]-' '\n' | while IFS= read -r word; do
    if [[ ${#word} -ge 3 && "$STOP_WORDS" != *" $word "* ]]; then echo "$word"; fi
  done | sort -u
}

list_candidates() {
  local root="$1"
  (cd "$root" && find . \( -name node_modules -o -name .git -o -name vendor \) -prune -o \
    -type f \( -name '*.md' -o -name '*.mdx' \) -print) | sed 's|^\./||' | sort |
    while IFS= read -r rel; do
      case "$rel" in
        README*|AGENTS.md) echo "$rel" ;;
        *) if [[ "$rel" =~ $DOC_DIR_RE ]]; then echo "$rel"; fi ;;
      esac
    done
}

kind_of() {
  local path lower base
  path="$1"
  lower="$(tr '[:upper:]' '[:lower:]' <<<"$path")"
  base="${lower##*/}"
  case "$base" in
    glossary*) echo glossary; return ;;
    readme*) echo readme; return ;;
  esac
  case "$lower" in
    */adr/*|adr/*) echo adr ;;
    *spec*) echo spec ;;
    */plans/*|plans/*|*plan*) echo plan ;;
    *) echo other ;;
  esac
}

title_of() {
  local title
  title="$(grep -m1 -E '^# ' "$1" 2>/dev/null | sed 's/^# *//' || true)"
  echo "${title:-$(basename "$1")}"
}

date_of() {
  local base found
  base="$(basename "$1")"
  if [[ "$base" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then echo "${BASH_REMATCH[1]}"; return; fi
  found="$(head -n 10 "$1" | grep -m1 -E '^Date: *[0-9]{4}-[0-9]{2}-[0-9]{2}' | sed 's/^Date: *//' || true)"
  echo "$found"
}

score_file() {
  local rel="$1" title="$2" term score=0
  for term in $TERMS; do
    grep -qiF -- "$term" "$ROOT/$rel" && score=$((score + 1))
    grep -qiF -- "$term" <<<"$rel" && score=$((score + 2))
    grep -qiF -- "$term" <<<"$title" && score=$((score + 2))
  done
  echo "$score"
}

describe() {
  local rel="$1" title score
  title="$(title_of "$ROOT/$rel")"
  score="$(score_file "$rel" "$title")"
  (( score > 0 )) || return 0
  jq -nc --arg path "$rel" --arg kind "$(kind_of "$rel")" --argjson score "$score" \
    --arg title "$title" --arg date "$(date_of "$ROOT/$rel")" \
    '{path:$path, kind:$kind, score:$score, title:$title} + (if $date == "" then {} else {date:$date} end)'
}

ROOT=""
TERMS=""

main() {
  local words=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --root) [[ $# -ge 2 ]] || die "--root needs a directory"; ROOT="$2"; shift 2 ;;
      -*) die "unknown option: $1" ;;
      *) words+=("$1"); shift ;;
    esac
  done
  ROOT="${ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
  [[ -d "$ROOT" ]] || die "not a directory: $ROOT" 3
  TERMS="$(normalize_terms ${words[@]+"${words[@]}"} | tr '\n' ' ')"
  [[ -n "${TERMS// /}" ]] || die "no usable topic words"
  list_candidates "$ROOT" | while IFS= read -r rel; do describe "$rel"; done |
    jq -s --argjson max "$MAX_RESULTS" --arg terms "$TERMS" \
      '{terms: ($terms | split(" ") | map(select(. != ""))),
        results: (sort_by([-.score, .path]) | .[:$max])}'
}

main "$@"
