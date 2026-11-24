#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: verdict-parse.sh <file|-> [-h|--help]

Finds the last "VERDICT: PASS" or "VERDICT: FAIL" line in check-work verifier output (file or
stdin). Leading whitespace, ** and backticks are tolerated; text after the word is ignored.
Prints JSON: {"verdict","line","text"}  (line = 1-based line number).
Exit: 0 PASS, 1 FAIL, 2 none found or usage
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") usage >&2; exit 2 ;;
esac
src="$1"
if [ "$src" != "-" ] && [ ! -f "$src" ]; then
  echo "verdict-parse: no such file: $src" >&2
  exit 2
fi

hit="$(awk '
  /^[[:space:]]*[*`]*VERDICT:[[:space:]]*[*`]*(PASS|FAIL)([[:space:]*`.,;:]|$)/ { n = NR; t = $0 }
  END { if (n) printf "%d\t%s\n", n, t }
' "$([ "$src" = "-" ] && echo /dev/stdin || echo "$src")")"

if [ -z "$hit" ]; then
  jq -nc '{verdict:"NONE",line:null,text:null}'
  exit 2
fi
num="${hit%%$'\t'*}"
text="${hit#*$'\t'}"
verdict="$(printf '%s' "$text" | sed -E 's/^[^V]*VERDICT:[[:space:]]*[*`]*(PASS|FAIL).*$/\1/')"
jq -nc --arg v "$verdict" --argjson n "$num" --arg t "$text" '{verdict:$v,line:$n,text:$t}'
[ "$verdict" = PASS ] && exit 0
exit 1
