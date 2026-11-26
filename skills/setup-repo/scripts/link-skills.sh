#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
exec node "$here/lib/setuplib/skills_link.mjs" "$@"
