#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/../../../../scripts/tests/lib.sh"
new_tmp

tool="$here/../check-pr-body.sh"
template="$here/../../assets/pr-body.md"

body="$TMPROOT/ok.md"
cat > "$body" <<'EOF'
## What changed

Adds a retry so a transient failure no longer drops the export. Task linked in the description.

## Risk

`medium`: changes how failures are reported. Merge policy: `conservative` (docs/rules/ai-merge-policy.md); one approval.

## Review guide

- **Size:** 40 changed lines in 3 files, 2 commits
- **Start here:** src/export.ts
- **Look hard:** src/export.ts:30 retry bound
- **Skim:** snapshots
- **Not in this change:** backoff tuning
- **Stack:** stands alone
- **Decisions to check:** is three retries enough?

## Build

- Command: `npm test`
- CI: https://example.test/ci/1
- Result: 120 passed

## Proof

| Claim | Kind | Evidence |
| --- | --- | --- |
| retries then succeeds | log | `attempt 2 ok` |

## Try it

1. Run `npm run export` and see `attempt 2 ok`
EOF

out="$("$tool" "$body")"; rc=$?
assert_rc "valid body passes" 0 $rc
assert_eq "tier parsed" medium "$(printf '%s' "$out" | jq -r .tier)"
assert_eq "ok true" true "$(printf '%s' "$out" | jq -r .ok)"

out="$("$tool" "$template")"; rc=$?
assert_rc "unfilled template fails" 1 $rc
assert_eq "template missing list not empty" true "$(printf '%s' "$out" | jq '.missing | length > 0')"

variant() { sed "$1" "$body" > "$TMPROOT/v.md"; "$tool" "$TMPROOT/v.md"; }
miss() { printf '%s' "$1" | jq -r '.missing | join(" | ")'; }

out="$(variant '/^## Build/,/^- Result/d')"; rc=$?
assert_rc "missing Build fails" 1 $rc
assert_contains "names Build header" "$(miss "$out")" "## Build"

out="$(variant 's/^- Result:.*/- Result:/')"; assert_contains "empty Build label" "$(miss "$out")" "Build label: Result:"
out="$(variant 's/\*\*Skim:\*\*/Skim:/')"; assert_contains "missing review label" "$(miss "$out")" "**Skim:**"
out="$(variant 's/`medium`: //')"; assert_contains "no tier" "$(miss "$out")" "risk tier"
out="$(variant 's/`medium`:/`low`, `medium`, or `high`:/')"; assert_contains "unfilled tier choice" "$(miss "$out")" "risk tier"
out="$(variant 's/Merge policy: `conservative`/Merge policy: `<profile>`/')"; assert_contains "merge policy placeholder" "$(miss "$out")" "Merge policy"
out="$(variant 's/^- Command:.*/- Command: `<the project check>`/')"; assert_contains "placeholder flagged" "$(miss "$out")" "leftover placeholder"
out="$(variant 's/^1\. .*/Run it/')"; assert_contains "Try it needs numbered step" "$(miss "$out")" "Try it"

out="$(variant 's/`medium`:/`high`:/')"; rc=$?
assert_rc "high without rollback fails" 1 $rc
assert_contains "rollback required" "$(miss "$out")" "Rollback"
{ cat "$TMPROOT/v.md"; printf '\n## Rollback\n\nRevert this merge.\n'; } > "$TMPROOT/v2.md"
out="$("$tool" "$TMPROOT/v2.md")"; assert_rc "high with rollback passes" 0 $?
{ cat "$TMPROOT/v.md"; printf '\n## Rollback\n\nFor a high-tier change this section is required.\n'; } > "$TMPROOT/v3.md"
out="$("$tool" "$TMPROOT/v3.md")"; assert_rc "template rollback text fails" 1 $?

{ sed -n '1,/^## Risk/p' "$body" | sed '$d'; for i in $(seq 1 30); do echo "filler line $i"; done; sed -n '/^## Risk/,$p' "$body"; } > "$TMPROOT/long.md"
out="$("$tool" "$TMPROOT/long.md")"; rc=$?
assert_rc "too long before Proof fails" 1 $rc
assert_contains "length reported" "$(miss "$out")" "length"

printf '%s\n' "$(cat "$body")" | "$tool" - > /dev/null; assert_rc "stdin works" 0 $?
out="$("$tool" "$TMPROOT/none.md" 2>&1)"; assert_rc "missing file" 2 $?
out="$("$tool" 2>&1)"; assert_rc "usage" 2 $?
finish
