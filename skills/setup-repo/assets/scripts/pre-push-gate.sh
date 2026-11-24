#!/usr/bin/env bash
set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: pre-push-gate.sh [base-ref] [-h|--help]
Git pre-push entry point: runs check-mr-size.sh and fails only when the branch is over the hard
limit (check-mr-size.sh exit 1). No changes, no base ref, or a warning all pass.
Exit: 0 pass, 1 over the hard size limit
USAGE
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$here/check-mr-size.sh" "$@"
[ "$?" -eq 1 ] && exit 1
exit 0
