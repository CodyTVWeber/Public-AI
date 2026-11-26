#!/usr/bin/env bash
set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: pre-push-gate.sh [base-ref] [-h|--help]
Git pre-push entry point. Runs the app, support, and docs size checks and fails when any one is
over its hard limit (exit 1). No changes, no base ref, or a warning all pass.
Exit: 0 pass, 1 over a hard size limit
USAGE
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
ran=0
for name in app support docs; do
  script="$here/check-mr-size-$name.sh"
  [ -x "$script" ] || continue
  ran=1
  "$script" "$@"
  [ "$?" -eq 1 ] && fail=1
done
if [ "$ran" -eq 0 ]; then
  "$here/check-mr-size.sh" "$@"
  [ "$?" -eq 1 ] && fail=1
fi
exit "$fail"
