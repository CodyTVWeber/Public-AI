#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/cc-lib.sh"
new_tmp
isolate_tmp

repo="$TMPROOT/repo"
make_repo "$repo"
printf 'export const note = 1;\n// leaves a note\n' > "$repo/dirty.ts"
printf 'export const note = 1;\n' > "$repo/clean.ts"
printf 'export function f(a, b, c) {\n  return a;\n}\n' > "$repo/warn.ts"
printf '// plain text\n' > "$repo/notes.txt"
printf 'ignored.ts\n' > "$repo/.gitignore"
printf '// leaves a note\nexport const x = 1;\n' > "$repo/ignored.ts"

post() { jq -nc --arg f "$1" --arg c "$repo" '{hook_event_name:"PostToolUse",tool_name:"Write",tool_input:{file_path:$f},cwd:$c}' | "$CQ" --hook; }

out="$(post "$repo/dirty.ts" 2>"$TMPROOT/err")"; rc=$?
assert_rc "violation exits 2" 2 $rc
assert_eq "violation leaves stdout empty" "" "$out"
assert_contains "stderr names the file and line" "$(cat "$TMPROOT/err")" "dirty.ts:2"
assert_contains "stderr names the rule" "$(cat "$TMPROOT/err")" "added-comment"
assert_contains "stderr carries the remedy" "$(cat "$TMPROOT/err")" "fix:"

out="$(post "$repo/clean.ts" 2>&1)"; rc=$?
assert_rc "clean file exits 0" 0 $rc
assert_eq "clean file is silent" "" "$out"

out="$(post "$repo/warn.ts" 2>"$TMPROOT/err")"; rc=$?
assert_rc "warnings alone exit 0" 0 $rc
assert_eq "warning event" "PostToolUse" "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$out")"
assert_contains "warnings go to additionalContext" "$(jq -r '.hookSpecificOutput.additionalContext' <<<"$out")" "param-count"

out="$(post "$repo/notes.txt" 2>&1)"; assert_rc "non-code file ignored" 0 $?
out="$(post "$repo/ignored.ts" 2>&1)"; assert_rc "gitignored file ignored" 0 $?
out="$(post "$repo/missing.ts" 2>&1)"; assert_rc "missing file ignored" 0 $?
out="$(printf 'not json' | "$CQ" --hook 2>&1)"; assert_rc "malformed payload ignored" 0 $?
out="$(printf '{"tool_input":{}}' | "$CQ" --hook 2>&1)"; assert_rc "payload without a path ignored" 0 $?

relative="$(jq -nc --arg c "$repo" '{tool_input:{file_path:"dirty.ts"},cwd:$c}' | "$CQ" --hook 2>&1)"; rc=$?
assert_rc "relative path resolves against cwd" 2 $rc

out="$(jq -nc --arg f "$repo/dirty.ts" --arg c "$repo" '{tool_input:{file_path:$f},cwd:$c}' | CC_SKIP=1 "$CQ" --hook 2>&1)"; rc=$?
assert_rc "CC_SKIP skips the hook" 0 $rc
assert_contains "skip announced on stderr" "$out" "skipped"

stop() { jq -nc --argjson a "$1" --arg c "$repo" '{hook_event_name:"Stop",stop_hook_active:$a,cwd:$c}' | "$CQ" --stop-hook; }

out="$(stop false 2>"$TMPROOT/err")"; rc=$?
assert_rc "stop hook blocks on changed files with errors" 2 $rc
assert_contains "stop stderr lists the file" "$(cat "$TMPROOT/err")" "dirty.ts"
assert_not_contains "stop checks only code files" "$(cat "$TMPROOT/err")" "notes.txt"

out="$(stop true 2>&1)"; rc=$?
assert_rc "stop_hook_active true exits 0" 0 $rc
assert_eq "loop guard prints nothing" "" "$out"

rm "$repo/dirty.ts"
out="$(stop false 2>&1)"; rc=$?
assert_rc "stop hook passes once errors are fixed" 0 $rc
assert_contains "stop surfaces warnings as a system message" "$(jq -r '.systemMessage' <<<"$out")" "param-count"

rm "$repo/warn.ts"
out="$(stop false 2>&1)"; assert_rc "stop hook clean" 0 $?
assert_eq "stop hook clean is silent" "" "$out"

out="$(printf '{"cwd":"%s"}' "$TMPROOT" | "$CQ" --stop-hook 2>&1)"; assert_rc "stop outside a repo exits 0" 0 $?
out="$(cd "$TMPROOT" && printf '' | "$CQ" --stop-hook 2>&1)"; assert_rc "empty stdin outside a repo exits 0" 0 $?
finish
