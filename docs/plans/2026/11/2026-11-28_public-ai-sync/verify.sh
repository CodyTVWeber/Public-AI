#!/usr/bin/env bash
set -euo pipefail
root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
here="$(cd "$(dirname "$0")" && pwd)"
out="$here/out"
mkdir -p "$out"

node --test "$root/scripts/tests/public-ai-sync.test.mjs" >"$out/unit.txt"
bash "$root/scripts/tests/public-ai-sync-consumer.test.sh" >"$out/consumer.txt"
node "$root/packages/public-ai-sync/scripts/bump.mjs" --dry-run >"$out/bump.txt"
grep -q "skip npm publish" "$out/bump.txt"
grep -q "passed" "$out/consumer.txt"
echo ok
