#!/usr/bin/env bash
set -uo pipefail

usage() {
  cat <<'EOF2'
Usage: run-all.sh [--fast] [-h|--help]
Runs every *.test.sh under scripts/ and skills/ (plain bash, no framework).
  (default)  full run: every test file
  --fast     smoke tier: skips the test files whose basename is listed in
             scripts/tests/slow.list (one basename per line, the slowest quarter by wall time)
Exit: 0 all passed, 1 at least one failed, 2 usage
EOF2
}

fast=0
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --fast) fast=1 ;;
  "") ;;
  *) usage >&2; exit 2 ;;
esac

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
slow_list="$root/scripts/tests/slow.list"
failed=0
count=0
skipped=0

is_slow() { [ -f "$slow_list" ] && grep -qxF -- "$(basename "$1")" "$slow_list"; }

while IFS= read -r -d '' t; do
  if [ "$fast" -eq 1 ] && is_slow "$t"; then
    skipped=$((skipped + 1))
    continue
  fi
  count=$((count + 1))
  bash "$t" || failed=$((failed + 1))
done < <(find "$root/scripts" "$root/skills" -type f -name '*.test.sh' -print0 2>/dev/null | sort -z)

echo "run-all: $count test files, $failed failed, $skipped skipped"
[ "$failed" -eq 0 ]
