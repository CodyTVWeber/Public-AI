#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 -I -B -c 'import sys; sys.path.insert(0, sys.argv[1]); from cleancode.cli import main; sys.exit(main(sys.argv[2:]))' "$here" "$@"
