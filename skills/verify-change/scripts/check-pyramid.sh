#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKIP="No runtime change: pyramid skipped."
JQ="$here/lib/check-pyramid.jq"

main() {
  case "${1:-}" in -h|--help) usage; exit 0 ;; esac
  [ $# -eq 1 ] || { usage >&2; exit 2; }
  [ -f "$1" ] || { echo "check-pyramid: no such file: $1" >&2; exit 3; }
  local payload violations
  payload="$(input_json "$1")"
  violations="$(jq -f "$JQ" <<<"$payload")"
  jq -nc --argjson violations "$violations" '{violations:$violations}'
  [ "$(jq 'length' <<<"$violations")" -eq 0 ]
}

usage() {
  cat <<'USAGE'
Usage: check-pyramid.sh PLAN.md [-h|--help]
Validates the Verification section (system and api pyramid rows, not unit tests).
Columns: Layer, Cases, AC, Observable, Writer.
Violations:
  missing-heading, no-table     need ## Verification and a table, or the skip line
  unit-layer, bad-layer         Layer is not system or api (unit is forbidden)
  bad-cases                     Cases is not happy and/or critical
  bad-writer                    Writer is not test or script
  empty-cell, placeholder       Observable or AC empty or still a fill-in
  too-many-system|api|script    over the few-rows cap (4 / 8 / 6)
  uncovered-criterion           an AC-n in the file appears in no AC cell
Skip line (exact): No runtime change: pyramid skipped.
Stdout: {violations:[{rule,detail}]}
Exit: 0 clean, 1 violations, 2 usage, 3 file missing
USAGE
}

input_json() {
  local skip=false heading=false
  has_heading "$1" && heading=true
  skipped "$1" && skip=true
  jq -n \
    --argjson skip "$skip" \
    --argjson has_heading "$heading" \
    --argjson rows "$(rows_json "$1")" \
    --argjson criteria "$(criteria_json "$1")" \
    --argjson caps '{"system":4,"api":8,"script":6}' \
    '{skip:$skip,has_heading:$has_heading,rows:$rows,criteria:$criteria,caps:$caps}'
}

rows_json() {
  table_body "$1" | jq -Rs '
    split("\n")
    | map(select(length > 0))
    | map(split("|") | map(gsub("^ +| +$"; "")) | .[1:-1])
    | map(select(length >= 5) | {
        layer: .[0], cases: .[1], ac: .[2], observable: .[3], writer: .[4]
      })
  '
}

table_body() {
  section "$1" | awk '
    /^\|/ {
      if (!inside && tolower($0) ~ /^\| *layer *\|/) { inside = 1; next }
      if (inside && $0 !~ /[A-Za-z0-9]/) next
      if (inside) print
      next
    }
    inside { exit }
  '
}

criteria_json() {
  { grep -oE '\- AC-?[0-9]+:' "$1" || true; } \
    | grep -oE 'AC-?[0-9]+' \
    | sed -E 's/^AC([0-9]+)$/AC-\1/' \
    | sort -u \
    | jq -Rn '[inputs]'
}

skipped() { section "$1" | grep -qxF "$SKIP"; }

has_heading() { grep -qxF "## Verification" "$1"; }

section() {
  awk -v h="## Verification" '$0==h{f=1;next} /^## /{f=0} f' "$1"
}

main "$@"
