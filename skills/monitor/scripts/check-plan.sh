#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage: check-plan.sh PLAN.md [-h|--help]

Validates the Monitoring plan signals table (first table whose header starts with Signal).
Columns: Signal, Kind, Criteria, Source, Query or command, Baseline, Threshold rule, Cadence,
Failure means, Action or owner. Violations:
  no-table, missing-column, empty-cell, placeholder   table shape and filled cells
  bad-kind                                            Kind not in works|error|data|health|latency|queue|alert|flag|downstream|kpi|probe
  bad-threshold                                       rule does not start with max_ratio|max_abs|min_abs|equals|forbid_new_keys
  uncovered-criterion                                 an AC<n> or AC-<n> id in the plan appears in no Criteria cell
  no-error-signal                                     no signal of kind error
  no-data-signal                                      a `Touches data: yes` line and no signal of kind data
Stdout: {violations:[{rule,detail}]}
Exit: 0 clean, 1 violations, 2 usage, 3 plan file missing
USAGE
}

signals_table() {
  awk '
    /^\|/ { if (!inside && tolower($0) ~ /^\| *signal *\|/) inside = 1; if (inside) print; next }
    inside { exit }
  ' "$1"
}

criteria_ids() {
  { grep -v '^|' "$1" | grep -owE 'AC-?[0-9]+' || true; } | sort -u | jq -Rn '[inputs]'
}

touches_data() {
  if grep -Eiq '^[[:space:]]*(-[[:space:]]*)?Touches data:[[:space:]]*yes' "$1"; then echo true; else echo false; fi
}

main() {
  case "${1:-}" in -h|--help) usage; exit 0 ;; esac
  [ $# -eq 1 ] || { usage >&2; exit 2; }
  [ -f "$1" ] || { printf 'check-plan: no such file: %s\n' "$1" >&2; exit 3; }
  local violations
  violations="$(signals_table "$1" | jq -Rs --argjson criteria "$(criteria_ids "$1")" --argjson touches_data "$(touches_data "$1")" -f "$here/lib/check-plan.jq")"
  jq -nc --argjson violations "$violations" '{violations:$violations}'
  [ "$(jq 'length' <<<"$violations")" -eq 0 ]
}

main "$@"
