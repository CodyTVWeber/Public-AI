#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib.sh"
new_tmp

guard="$here/../guard/git-approval-guard.sh"

decision() {
  local out
  out="$("$guard" --command "$1" 2>/dev/null)" || { echo "error"; return; }
  [ -z "$out" ] && { echo "none"; return; }
  printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision'
}
reason() { "$guard" --command "$1" 2>/dev/null | jq -r '.hookSpecificOutput.permissionDecisionReason'; }
expect() { assert_eq "$2 :: $1" "$1" "$(decision "$2")"; }

expect none 'ls -la'
expect none 'git status'
expect none 'git log --oneline | head -5'
expect none 'git diff --staged'
expect none 'echo "git push is next"'

expect ask 'git commit -m "x"'
expect ask 'git push'
expect ask 'git push origin main'
expect ask 'git -C some/dir push'
expect ask 'git --no-pager commit -am msg'
expect ask 'git -c user.name=x commit -m y'
expect ask 'env X=1 git push'
expect ask 'FOO=bar git commit -m x'
expect ask 'sh -c "git push"'
expect ask 'bash -lc "cd d && git commit -m y"'
expect ask 'git add -A && git commit -m x'
expect ask 'git add . ; git push'
expect ask 'ls | git push'
expect ask 'echo `git push`'
expect ask 'echo $(git commit -m x)'
expect ask 'sudo -u someone git push'
expect ask 'timeout 5 git push'
expect ask 'git push --force origin main'
expect ask 'git commit -m "unterminated'
expect ask '/usr/bin/git commit -m x'
expect ask 'if true; then git push; fi'
expect ask 'git commit -m "$(cat <<'"'"'EOF'"'"'
note with git push inside the message
EOF
)"'
expect ask 'bash <<EOF
git push
EOF'

assert_contains "reason names commit" "$(reason 'git commit -m x')" "git commit"
assert_contains "reason names push" "$(reason 'git push')" "git push"
assert_contains "reason names both" "$(reason 'git commit -m x && git push')" "commit and push"
assert_contains "reason reminds status" "$(reason 'git push')" "git status"
assert_contains "reason reminds staged diff" "$(reason 'git push')" "git diff --staged"
assert_not_contains "commit alone does not name push gate" "$(reason 'git commit -m x')" "git commit and push"

expect deny 'git commit --no-verify -m x'
expect deny 'git commit -n -m x'
expect deny 'git commit -nm x'
expect deny 'git commit -anm x'
expect deny 'git push --no-verify'
expect deny 'git push --no-ver origin main'
expect deny 'git -c core.hooksPath=/dev/null commit -m x'
expect deny 'CLEAN_CODE_SKIP=1 git push'
expect deny 'CLEAN_CODE_SKIP=yes git commit -m x'
expect deny 'SKIP=lint git commit -m x'
expect deny 'HUSKY=0 git commit -m x'
expect deny 'export CLEAN_CODE_SKIP=1; git push'
expect deny 'env CLEAN_CODE_SKIP=1 git push'
expect deny 'sh -c "CLEAN_CODE_SKIP=1 git push"'
expect ask 'CLEAN_CODE_SKIP=0 git push'
expect ask 'git commit -m "fix -n handling"'
expect ask 'git push -n'
expect ask 'git commit -am "x --no-verify"'

repo="$TMPROOT/repo"
new_repo "$repo"
git -C "$repo" config alias.ci commit
git -C "$repo" config alias.sendit '!git push'
out="$(printf '%s' "{\"tool_name\":\"Bash\",\"cwd\":\"$repo\",\"tool_input\":{\"command\":\"git ci -m x\"}}" | "$guard")"
assert_eq "alias to commit asks" ask "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision')"
out="$(printf '%s' "{\"tool_name\":\"Bash\",\"cwd\":\"$repo\",\"tool_input\":{\"command\":\"git sendit\"}}" | "$guard")"
assert_eq "shell alias to push asks" ask "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision')"

out="$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git push"}}' | "$guard")"
assert_eq "hook event name" PreToolUse "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName')"
out="$(printf '%s' '{"tool_name":"Edit","tool_input":{"command":"git push"}}' | "$guard")"
assert_eq "non-Bash tool ignored" "" "$out"
out="$(printf '%s' 'not json but git push here' | "$guard")"
assert_eq "unparseable input with git push asks" ask "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision')"
out="$(printf '' | "$guard")"; assert_rc "empty stdin ok" 0 $?
out="$("$guard" --bogus 2>&1)"; assert_rc "bad flag" 2 $?
out="$("$guard" --help)"; assert_rc "help" 0 $?
assert_contains "help documents the script limit" "$out" "Makefile"

finish
