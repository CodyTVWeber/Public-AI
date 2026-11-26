#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage: compare.sh BASELINE.json CURRENT.json RULES.json [-h|--help]

BASELINE and CURRENT are flat objects {signal: value}; an error-signature signal holds an array
(or object) of signatures. RULES is an array of
  {name, kind, limit|value, warn?, allow_noise_abs?}
Kinds:
  max_ratio        current <= baseline * limit            (warn: softer ratio)
  max_abs          current <= limit                       (warn: softer bound)
  min_abs          current >= limit                       (warn: softer bound)
  equals           current == value
  forbid_new_keys  signatures present now and absent in the baseline fail
allow_noise_abs N  ignores a breach when |current - baseline| < N
A missing current value, a missing baseline a rule needs, or an empty rule list is unknown.
Stdout: {verdict: healthy|degraded|unknown, signals:[{name,status,value,baseline,rule,reason}]}
        status is ok|warn|fail|unknown
Exit: 0 healthy, 1 degraded, 2 usage, 3 unknown
USAGE
}

die_usage() {
  printf 'compare: %s\n' "$1" >&2
  exit 2
}

require_json() {
  [ -f "$1" ] || die_usage "no such file: $1"
  jq -e . "$1" >/dev/null 2>&1 || die_usage "not valid JSON: $1"
}

require_shapes() {
  jq -e 'type == "object"' "$1" "$2" >/dev/null || die_usage "baseline and current must be JSON objects"
  jq -e 'type == "array" and all(.[]; type == "object")' "$3" >/dev/null || die_usage "rules must be an array of objects"
}

exit_for() {
  case "$1" in
    healthy) return 0 ;;
    degraded) return 1 ;;
    *) return 3 ;;
  esac
}

main() {
  case "${1:-}" in -h|--help) usage; exit 0 ;; esac
  [ $# -eq 3 ] || { usage >&2; exit 2; }
  local file
  for file in "$@"; do require_json "$file"; done
  require_shapes "$1" "$2" "$3"
  local out
  out="$(jq -n -c --slurpfile baseline "$1" --slurpfile current "$2" --slurpfile rules "$3" -f "$here/lib/compare.jq")"
  printf '%s\n' "$out"
  exit_for "$(jq -r .verdict <<<"$out")"
}

main "$@"
