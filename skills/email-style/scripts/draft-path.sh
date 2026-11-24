#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: draft-path.sh [--dir DIR] TOPIC
Prints {"path": "<DIR>/draft-<topic>.md"} for a draft file.
Topic words become lowercase-with-hyphens; an existing file gets a -2, -3 suffix.
Exit: 0 ok, 2 usage.
USAGE
}

dir="."
topic=""

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --dir) [ $# -ge 2 ] || { usage >&2; exit 2; }; dir="$2"; shift 2 ;;
    -*) echo "unknown flag: $1" >&2; usage >&2; exit 2 ;;
    *) topic="${topic:+$topic }$1"; shift ;;
  esac
done

[ -n "$topic" ] || { usage >&2; exit 2; }
slug=$(printf '%s' "$topic" | tr -cs 'A-Za-z0-9' '-' | tr 'A-Z' 'a-z' | sed 's/^-//; s/-$//')
[ -n "$slug" ] || { echo "topic has no usable characters" >&2; exit 2; }

base="${dir%/}/draft-${slug}"
path="${base}.md"
n=2
while [ -e "$path" ]; do
  path="${base}-${n}.md"
  n=$((n + 1))
done

escaped=${path//\\/\\\\}
escaped=${escaped//\"/\\\"}
printf '{"path": "%s"}\n' "$escaped"
