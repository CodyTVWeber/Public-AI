#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: merge-policy.sh [file] [-h|--help]

Resolves the repo's merge policy (rules/merge-policy.md). file defaults to
docs/rules/ai-merge-policy.md under the git top level (or the current directory).
HTML comments and fenced code blocks are ignored. Parses "Merge policy: <profile>" and,
for balanced only, "Auto-merge low: on".
Prints JSON: {"profile","auto_merge_low","source"}
  profile   conservative | balanced | yolo ; missing file, unknown value, or several
            disagreeing lines resolve to the most conservative
  source    the file path, or "default" when the file is missing or has no valid line
Exit: 0 always (2 on bad usage)
EOF
}

file=""
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    -*) usage >&2; exit 2 ;;
    *) file="$arg" ;;
  esac
done

if [ -z "$file" ]; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  file="$root/docs/rules/ai-merge-policy.md"
fi

emit() { jq -nc --arg p "$1" --argjson a "$2" --arg s "$3" '{profile:$p,auto_merge_low:$a,source:$s}'; }

if [ ! -f "$file" ]; then
  emit conservative false default
  exit 0
fi

cleaned="$(awk '
  BEGIN { incomment = 0; infence = 0 }
  {
    line = $0
    out = ""
    while (length(line) > 0) {
      if (incomment) {
        i = index(line, "-->")
        if (i == 0) { line = ""; break }
        line = substr(line, i + 3); incomment = 0
      } else {
        i = index(line, "<!--")
        if (i == 0) { out = out line; line = ""; break }
        out = out substr(line, 1, i - 1); line = substr(line, i + 4); incomment = 1
      }
    }
    if (out ~ /^[[:space:]]*(```|~~~)/) { infence = !infence; next }
    if (!infence) print out
  }
' "$file")"

rank() { case "$1" in conservative) echo 0 ;; balanced) echo 1 ;; yolo) echo 2 ;; esac; }

profile=""
valid=0
while IFS= read -r value; do
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | tr -d '`*[:space:]')"
  case "$value" in
    conservative|balanced|yolo) cand="$value" ;;
    *) cand=conservative ;;
  esac
  valid=1
  if [ -z "$profile" ] || [ "$(rank "$cand")" -lt "$(rank "$profile")" ]; then profile="$cand"; fi
done < <(printf '%s\n' "$cleaned" | sed -nE 's/^[[:space:]]*([-*][[:space:]]+)?[`*]*[Mm]erge [Pp]olicy[`*]*:[[:space:]]*(.*)$/\2/p')

if [ "$valid" -eq 0 ]; then
  emit conservative false default
  exit 0
fi

auto=false
if [ "$profile" = balanced ] && printf '%s\n' "$cleaned" | grep -Eiq '^[[:space:]]*([-*][[:space:]]+)?[`*]*auto-merge low[`*]*:[[:space:]]*`?on`?[[:space:]]*$'; then
  auto=true
fi
emit "$profile" "$auto" "$file"
