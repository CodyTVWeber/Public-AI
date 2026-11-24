#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
exec "$here/lib/pyrun.sh" setuplib.verify_cli "$@"
