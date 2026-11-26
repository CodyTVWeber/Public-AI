#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: check-align.sh [DIR]   (-h|--help)
Validates an align topic dir (default: the current directory). Stdout JSON:
  {dir, violations[{rule, file, line, detail}]}
Checks
  missing-file, missing-heading   spec.md, glossary.md, alignment.md and their required headings
  placeholder         no {{...}} fill-in left
  ac-number           spec acceptance criteria are `- AC-N: text`, numbered 1..n in order, at least one
  question-unmarked   open questions start `- (blocking)` or `- (non-blocking)`
  design-authority    design source rows use exact | partial | reference
  task-too-long       alignment Task is at most 5 lines
  aligned-line        alignment has one `Aligned: yes|no` line and a `Confirmed by:` line
  blocking-open       `Aligned: yes` with a blocking question open, or nobody named in Confirmed by
  unknown-term        every [[term]] in spec.md has a row in glossary.md
  adr-name, adr-field YYYY-MM-DD-<slug>.md; Date equals the file name date; Status
                      proposed|accepted|superseded; Supersedes present and resolving; required headings
  broken-link         relative markdown links resolve
Adrs checked: DIR/adr/*.md plus adr files linked from spec.md or alignment.md.
Exit: 0 clean, 1 violations, 2 usage, 3 DIR missing
USAGE
}

OPEN_Q="Open questions"
SPEC_HEADINGS=("Goal" "Users" "Scope" "Non-goals" "Acceptance criteria" "Constraints" "Design sources" "Decisions" "$OPEN_Q")
GLOSSARY_HEADINGS=("Terms")
ALIGNMENT_HEADINGS=("Task" "Agreed" "Assumptions" "$OPEN_Q" "Status")
ADR_HEADINGS=("Context" "Decision" "Alternatives" "Consequences")
TASK_MAX_LINES=5
ADR_NAME_RE='^[0-9]{4}-[0-9]{2}-[0-9]{2}-.+\.md$'
TAB=$'\t'

v() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }

prose() { awk '/^```/{f=!f; print ""; next} f{print ""; next} {print}' "$1"; }

section() { prose "$1" | awk -v h="## $2" '$0==h{f=1;next} /^## /{f=0} f&&NF{print NR "\t" $0}'; }

cell() { awk -F'|' -v n="$2" '{gsub(/^ +| +$/, "", $n); print $n}' <<<"$1"; }

table_rows() { grep -E '^\|' "$1" | grep -vE '^\|[ -]*---|^\| *(Term|Source) ' || true; }

check_headings() {
  local file="$1" h
  shift
  for h in "$@"; do
    prose "$DIR/$file" | grep -qxF "## $h" || v missing-heading "$file" 0 "## $h"
  done
}

check_placeholders() {
  local file="$1" n
  grep -n '{{' "$file" | while IFS=: read -r n _; do v placeholder "${file#"$DIR"/}" "$n" "fill-in left"; done || true
}

check_acceptance() {
  local n text expect=1 num
  while IFS="$TAB" read -r n text; do
    if [[ "$text" =~ ^-\ AC-([0-9]+):\ .+ ]]; then
      num="${BASH_REMATCH[1]}"
      (( num == expect )) || v ac-number spec.md "$n" "expected AC-$expect, found AC-$num"
      expect=$((num + 1))
    else
      v ac-number spec.md "$n" "not in the form '- AC-N: text'"
    fi
  done < <(section "$DIR/spec.md" "Acceptance criteria")
  (( expect > 1 )) || v ac-number spec.md 0 "no acceptance criteria"
}

blocking_count() {
  local total=0 f c
  for f in spec.md alignment.md; do
    c="$(section "$DIR/$f" "$OPEN_Q" | grep -c '^[0-9]*'"$TAB"'- (blocking)' || true)"
    total=$((total + c))
  done
  echo "$total"
}

check_questions() {
  local file="$1" n text
  while IFS="$TAB" read -r n text; do
    [[ "$text" =~ ^-\ \((blocking|non-blocking)\)\  ]] || v question-unmarked "$file" "$n" "mark as (blocking) or (non-blocking)"
  done < <(section "$DIR/$file" "$OPEN_Q")
}

check_design() {
  local row authority
  while IFS= read -r row; do
    authority="$(cell "$row" 3)"
    [[ "$authority" == *"{{"* || "$authority" =~ ^(exact|partial|reference)$ ]] ||
      v design-authority spec.md 0 "authority '$authority' is not exact, partial or reference"
  done < <(section "$DIR/spec.md" "Design sources" | cut -f2- | grep -E '^\|' | grep -vE '^\|[ -]*---|^\| *Source ' || true)
}

check_alignment() {
  local file="$DIR/alignment.md" aligned who lines
  lines="$(section "$file" Task | wc -l | tr -d ' ')"
  (( lines <= TASK_MAX_LINES )) || v task-too-long alignment.md 0 "$lines lines"
  aligned="$(grep -E '^Aligned: (yes|no)$' "$file" | head -n 1 | cut -d' ' -f2 || true)"
  who="$(grep -m1 '^Confirmed by:' "$file" | sed 's/^Confirmed by: *//' || true)"
  [[ -n "$aligned" && "$(grep -c '^Aligned:' "$file")" -eq 1 ]] || v aligned-line alignment.md 0 "need one 'Aligned: yes|no' line"
  grep -q '^Confirmed by:' "$file" || v aligned-line alignment.md 0 "need a 'Confirmed by:' line"
  [[ "$aligned" == yes ]] || return 0
  (( $(blocking_count) == 0 )) || v blocking-open alignment.md 0 "Aligned: yes with a blocking question open"
  [[ -n "$who" && "$who" != none && "$who" != *"{{"* ]] || v blocking-open alignment.md 0 "Aligned: yes without a name in Confirmed by"
}

glossary_terms() {
  table_rows "$DIR/glossary.md" | while IFS= read -r row; do cell "$row" 2; done | tr '[:upper:]' '[:lower:]'
}

check_terms() {
  local terms ref n
  terms="$(glossary_terms)"
  prose "$DIR/spec.md" | grep -noE '\[\[[^]]+\]\]' | while IFS=: read -r n ref; do
    ref="$(tr '[:upper:]' '[:lower:]' <<<"${ref#\[\[}")"
    ref="${ref%\]\]}"
    grep -qxF -- "$ref" <<<"$terms" || v unknown-term spec.md "$n" "[[${ref}]] is not in glossary.md"
  done || true
}

link_targets() {
  prose "$1" | grep -noE '\]\([^)]+\)' | sed -E 's/^([0-9]+):\]\((.*)\)$/\1\t\2/' || true
}

check_links() {
  local file="$1" n target path
  while IFS="$TAB" read -r n target; do
    path="${target%%#*}"
    case "$path" in ""|http://*|https://*|mailto:*|*"{{"*) continue ;; esac
    [[ -e "$(dirname "$file")/$path" ]] || v broken-link "${file#"$DIR"/}" "$n" "$target"
  done < <(link_targets "$file")
}

linked_adrs() {
  local f target
  for f in spec.md alignment.md; do
    [[ -f "$DIR/$f" ]] || continue
    link_targets "$DIR/$f" | cut -f2 | sed 's/#.*//' | while IFS= read -r target; do
      [[ "$(basename "$target")" =~ $ADR_NAME_RE && -f "$DIR/$target" ]] && echo "$DIR/$target"
    done || true
  done
}

adr_files() {
  { find "$DIR/adr" -maxdepth 1 -name '*.md' 2>/dev/null || true; linked_adrs; } | sort -u
}

adr_header() { head -n 10 "$1" | grep -m1 "^$2:" | sed "s/^$2: *//" || true; }

check_adr_fields() {
  local file="$1" rel base date status supersedes
  rel="${file#"$DIR"/}"
  base="$(basename "$file")"
  [[ "$base" =~ $ADR_NAME_RE ]] || { v adr-name "$rel" 0 "expected YYYY-MM-DD-<slug>.md"; return 0; }
  date="$(adr_header "$file" Date)"
  status="$(adr_header "$file" Status)"
  supersedes="$(adr_header "$file" Supersedes)"
  [[ "$date" == "${base:0:10}" ]] || v adr-field "$rel" 0 "Date '$date' differs from the file name date"
  [[ "$status" =~ ^(proposed|accepted|superseded)$ ]] || v adr-field "$rel" 0 "Status '$status' is not proposed, accepted or superseded"
  [[ -n "$supersedes" ]] || v adr-field "$rel" 0 "Supersedes line missing (use none)"
  check_supersedes "$file" "$supersedes"
  check_headings "$rel" "${ADR_HEADINGS[@]}"
}

check_supersedes() {
  local file="$1" value="$2" path
  [[ -n "$value" && "$value" != none ]] || return 0
  path="$(sed -E 's/^\[[^]]*\]\(([^)]*)\)$/\1/' <<<"$value")"
  [[ -e "$(dirname "$file")/$path" ]] || v adr-field "${file#"$DIR"/}" 0 "Supersedes target '$path' not found"
}

run_checks() {
  local f
  for f in spec.md glossary.md alignment.md; do [[ -f "$DIR/$f" ]] || v missing-file "$f" 0 "required file is absent"; done
  [[ -f "$DIR/spec.md" ]] && { check_headings spec.md "${SPEC_HEADINGS[@]}"; check_acceptance; check_questions spec.md; check_design; }
  [[ -f "$DIR/glossary.md" ]] && check_headings glossary.md "${GLOSSARY_HEADINGS[@]}"
  [[ -f "$DIR/alignment.md" ]] && { check_headings alignment.md "${ALIGNMENT_HEADINGS[@]}"; check_questions alignment.md; check_alignment; }
  [[ -f "$DIR/spec.md" && -f "$DIR/glossary.md" ]] && check_terms
  while IFS= read -r f; do check_adr_fields "$f"; done < <(adr_files)
  while IFS= read -r f; do check_placeholders "$f"; check_links "$f"; done < <(find "$DIR" -name '*.md' | sort)
}

main() {
  case "${1:-}" in -h|--help) usage; exit 0 ;; esac
  [[ $# -le 1 ]] || { usage >&2; exit 2; }
  DIR="${1:-.}"
  [[ -d "$DIR" ]] || { echo "check-align: not a directory: $DIR" >&2; exit 3; }
  DIR="$(cd "$DIR" && pwd)"
  local out
  out="$(run_checks)"
  jq -Rn --arg dir "$DIR" '{dir:$dir, violations:[inputs | select(length > 0) | split("\t") | {rule:.[0], file:.[1], line:(.[2]|tonumber), detail:.[3]}]}' <<<"$out"
  [[ -z "$out" ]]
}

main "$@"
