#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/cc-lib.sh"
new_tmp
isolate_tmp

repo="$TMPROOT/repo"
make_repo "$repo"
printf 'export const note = 1;\n// human wip\n' > "$repo/wip.ts"

edit() { jq -nc --arg f "$1" --arg c "$repo" --arg s "${2-}" '{session_id:$s,tool_input:{file_path:$f},cwd:$c} | if .session_id == "" then del(.session_id) else . end' | "$CQ" --hook; }
stop() { jq -nc --arg c "$repo" --arg s "${1-}" '{session_id:$s,stop_hook_active:false,cwd:$c} | if .session_id == "" then del(.session_id) else . end' | "$CQ" --stop-hook; }
log_of() { printf '%s/cc-session-%s.edited' "$TMPDIR" "$1"; }

out="$(stop none 2>&1)"; rc=$?
assert_rc "human untracked wip never blocks the stop hook" 0 $rc
assert_eq "wip stop is silent" "" "$out"

printf 'export const base = 1;\n// tracked edit\n' > "$repo/base.ts"
out="$(stop none 2>&1)"; rc=$?
assert_rc "without a log, tracked changes are checked" 2 $rc
assert_contains "tracked file reported" "$out" "base.ts"
assert_not_contains "untracked wip stays out" "$out" "wip.ts"
git -C "$repo" checkout -q -- base.ts

printf 'export const clean = 1;\n' > "$repo/clean.ts"
edit "$repo/clean.ts" S1 >/dev/null 2>&1; assert_rc "clean edit passes" 0 $?
assert_contains "edit is logged" "$(cat "$(log_of S1)")" "clean.ts"
out="$(stop S1 2>&1)"; rc=$?
assert_rc "stop with a log ignores the human's untracked wip" 0 $rc
assert_eq "stop with a log is silent" "" "$out"

printf 'export const bad = 1;\n// agent note\n' > "$repo/bad.ts"
edit "$repo/bad.ts" S1 >/dev/null 2>&1; assert_rc "bad edit blocks" 2 $?
out="$(stop S1 2>&1)"; rc=$?
assert_rc "stop checks the agent's untracked file" 2 $rc
assert_contains "agent file reported" "$out" "bad.ts"
assert_not_contains "wip still excluded" "$out" "wip.ts"

out="$(stop S2 2>&1)"; rc=$?
assert_rc "another session has its own log" 0 $rc

rm "$repo/bad.ts"
out="$(stop S1 2>&1)"; assert_rc "logged files that no longer exist are skipped" 0 $?

mkdir -p "$TMPROOT/outside"
printf 'export const x = 1;\n// outside\n' > "$TMPROOT/outside/o.ts"
edit "$TMPROOT/outside/o.ts" S1 >/dev/null 2>&1; assert_rc "file outside any repo is skipped by the edit hook" 0 $?
assert_not_contains "outside file never logged" "$(cat "$(log_of S1)")" "o.ts"

edit "$repo/clean.ts" >/dev/null 2>&1
ls "$TMPDIR" | grep -q '^cc-session-cwd-' && ok || bad "missing session id falls back to a per-cwd log" "$(ls "$TMPDIR")"
out="$(stop 2>&1)"; assert_rc "per-cwd fallback log is read back" 0 $?

edit "$repo/clean.ts" '../evil/x' >/dev/null 2>&1
[ -f "$TMPDIR/cc-session-___evil_x.edited" ] && ok || bad "session id is sanitized into the log name" "$(ls "$TMPDIR")"

for n in 1 2 3 4 5; do
  printf 'export const v%s = 1;\n' "$n" > "$repo/f$n.ts"
  CC_SESSION_LOG_MAX=3 edit "$repo/f$n.ts" CAP >/dev/null 2>&1
done
assert_eq "log is capped" "3" "$(wc -l < "$(log_of CAP)" | tr -d ' ')"
assert_contains "cap keeps the newest entries" "$(cat "$(log_of CAP)")" "f5.ts"
assert_not_contains "cap drops the oldest entries" "$(cat "$(log_of CAP)")" "f1.ts"

printf '1\t%s\n' "$repo/f1.ts" > "$(log_of OLD)"
touch -t 202001010000 "$TMPDIR/cc-session-ancient.edited"
edit "$repo/f2.ts" OLD >/dev/null 2>&1
assert_not_contains "entries older than 7 days are dropped" "$(cat "$(log_of OLD)")" "f1.ts"
[ -e "$TMPDIR/cc-session-ancient.edited" ] && bad "log files older than 7 days are removed" || ok

out="$(cd "$repo" && "$CQ" --changed 2>/dev/null)"; rc=$?
assert_rc "--changed still scans untracked files" 1 $rc
assert_contains "--changed names the wip file" "$out" "wip.ts"
finish
