#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: slices-check.sh SLICES.json [--max-slices N]
Input: {"slices":[{"name":"a","paths":["src/a/**","docs/a.md"]}, ...]}
Checks: names match [a-z0-9]+(-[a-z0-9]+)* and are unique; count <= N (--max-slices, env
PIR_MAX_SLICES, default 4); every slice has at least one path; paths are relative, no "..".
Disjointness, per pair of paths from different slices:
  literal prefix = the path up to its first of * ? [ {; a path without them is an exact path
  exact vs exact          overlap when equal
  exact vs pattern        overlap when the exact path starts with the pattern's prefix, or the
                          pattern's prefix starts with the exact path plus "/"
  pattern vs pattern      overlap when either prefix starts with the other (conservative)
  a trailing "/" makes a directory pattern: "src/a/" is the same as "src/a/**"
stdout: {ok, errors:[string], overlaps:[{a, b, pattern}]}; pattern is the pair "pathA | pathB"
Exit: 0 ok, 1 invalid or overlapping, 2 usage, 3 unreadable input
USAGE
}

file="" max=${PIR_MAX_SLICES:-4}

while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help) usage; exit 0 ;;
    --max-slices) [ $# -ge 2 ] || { usage >&2; exit 2; }; max=$2; shift 2 ;;
    -*) usage >&2; exit 2 ;;
    *) [ -z "$file" ] || { usage >&2; exit 2; }; file=$1; shift ;;
  esac
done
[ -n "$file" ] || { usage >&2; exit 2; }
case "$max" in '' | *[!0-9]*) echo "max slices must be an integer" >&2; exit 2 ;; esac
[ -f "$file" ] || { echo "no such file: $file" >&2; exit 3 ; }

exec node "$(dirname "${BASH_SOURCE[0]}")/slices-check.mjs" "$file" "$max"
