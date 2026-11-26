#!/usr/bin/env bash
set -uo pipefail

usage() {
  cat <<'EOF2'
Usage: check-languages.sh [--staged | --range REV]
Fails when staged files (default) or the commit range REV ADD a source file in a language other than
Bash or JavaScript (rules/scripting-languages.md). Paths matching a regex line in <repo>/.languageexempt are skipped.
Extensions: py pyw rb pl pm php lua go rs java kt swift r jl ps1 bat cmd groovy scala tcl
Exit: 0 clean, 1 violations, 2 usage
EOF2
}

mode="staged"
rev=""
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  ""|--staged) ;;
  --range) mode="range"; rev="${2:-}"; [ -n "$rev" ] || { usage >&2; exit 2; } ;;
  *) usage >&2; exit 2 ;;
esac

root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "check-languages: not a git repo" >&2; exit 2; }
cd "$root"

if [ "$mode" = staged ]; then
  added="$(git diff --cached --name-only --diff-filter=A)"
else
  added="$(git diff --name-only --diff-filter=A "$rev")" || exit 2
fi

exempt=()
if [ -f .languageexempt ]; then
  while IFS= read -r line; do
    [ -n "$line" ] && exempt+=("$line")
  done < .languageexempt
fi

is_exempt() {
  local re
  for re in "${exempt[@]+"${exempt[@]}"}"; do
    [[ "$1" =~ $re ]] && return 0
  done
  return 1
}

bad=0
while IFS= read -r path; do
  [ -n "$path" ] || continue
  case "${path##*.}" in
    py|pyw|rb|pl|pm|php|lua|go|rs|java|kt|swift|r|jl|ps1|bat|cmd|groovy|scala|tcl) ;;
    *) continue ;;
  esac
  is_exempt "$path" && continue
  echo "check-languages: $path: write Bash or JavaScript (.mjs), or list it in .languageexempt" >&2
  bad=1
done <<<"$added"
exit "$bad"
