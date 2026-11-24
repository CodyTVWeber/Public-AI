#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
module="$1"
shift
exec python3 -I -B -c 'import importlib, sys; sys.path.insert(0, sys.argv[1]); sys.exit(importlib.import_module(sys.argv[2]).main(sys.argv[3:]))' "$here" "$module" "$@"
