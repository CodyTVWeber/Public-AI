#!/usr/bin/env bash
set -euo pipefail
root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
here="$(cd "$(dirname "$0")" && pwd)"
out="$here/out"
mkdir -p "$out"

args="$root/skills/plan-implement-review/scripts/pir-args.sh"
"$args" "x phases=pir" > "$out/pir.json"
"$args" "x phases=apir" > "$out/apir.json"
"$root/skills/verify-change/scripts/plan-dir.sh" \
  "$root/docs/plans/2026/11/2026-11-28_verify-phase.md" > "$out/plan-dir.json"
"$root/skills/verify-change/scripts/check-evidence-dir.sh" --allow-pending "$here" \
  > "$out/evidence-dir.json"

jq -e '.phases == ["plan","implement","verify","review"]' "$out/pir.json" >/dev/null
jq -e '.phases == ["align","plan","implement","verify","review"]' "$out/apir.json" >/dev/null
jq -e '.ok == true' "$out/evidence-dir.json" >/dev/null
echo ok
