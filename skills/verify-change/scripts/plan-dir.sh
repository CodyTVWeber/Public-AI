#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: plan-dir.sh PLAN.md
Prints JSON {plan, stem, dir} for the sibling evidence folder next to a dated plan.
Basename must be YYYY-MM-DD_slug.md or YYYY-MM-DD-slug.md. dir is dirname/stem/.
The plan file does not need to exist yet. Exit: 0 ok, 2 usage.
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  ""|-*) usage >&2; exit 2 ;;
esac
[ $# -eq 1 ] || { usage >&2; exit 2; }

base="$(basename "$1")"
[[ "$base" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}[_-][A-Za-z0-9][A-Za-z0-9._-]*\.md$ ]] || {
  echo "plan-dir: basename must be YYYY-MM-DD_slug.md: $base" >&2
  exit 2
}

parent="$(cd "$(dirname "$1")" 2>/dev/null && pwd || true)"
if [ -z "$parent" ]; then
  echo "plan-dir: parent directory not found: $1" >&2
  exit 2
fi
stem="${base%.md}"
plan="$parent/$base"
dir="$parent/$stem"
jq -nc --arg plan "$plan" --arg stem "$stem" --arg dir "$dir" '{plan:$plan,stem:$stem,dir:$dir}'
