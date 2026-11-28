#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: proof-check.sh PR_BODY_FILE SCOPE_JSON_FILE
Checks the deterministic rows of the proof check against a PR/MR description.
Scope JSON (diff-scope.sh output; extra keys ignored), booleans, absent = false: docs_only, ui_changed, backend_changed, db_changed,
test_only. Optional: behavior_changed (needs a video), deep_change (needs a mermaid diagram).
Optional kinds[] (from plan-folder kinds.json) replaces those flags: image, video, curl, query,
diagram, script, log, build. Checks: headings Build, Proof, Try it, Review guide; Build command
and CI link; Proof rows; numbered Try it steps; Review guide labels; tier, merge policy, rollback
for high tier; counts vs flags or vs kinds[]; leftover template text.
docs_only or test_only alone needs only Build, Review guide and a "no behavior change" line.
Whether media is blank or wrong stays a human judgment.
Stdout: {"ok", "missing": [...], "counts": {...}}. Exit: 0 ok, 1 something missing, 2 usage.
USAGE
}

case "${1:-}" in -h|--help) usage; exit 0 ;; esac
[ $# -eq 2 ] || { usage >&2; exit 2; }
[ -f "$1" ] || { echo "no such file: $1" >&2; exit 2; }
[ -f "$2" ] || { echo "no such file: $2" >&2; exit 2; }
jq -e 'type == "object"' "$2" >/dev/null 2>&1 || { echo "scope is not a JSON object: $2" >&2; exit 2; }

exec node "$(dirname "${BASH_SOURCE[0]}")/proof-check.mjs" "$1" "$2"
