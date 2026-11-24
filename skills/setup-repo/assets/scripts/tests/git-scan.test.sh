#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/../../../../../scripts/tests/lib.sh"
new_tmp

scan="$here/../git-scan.sh"
tags_of() { "$scan" "$1" | paste -sd' ' -; }
expect() { assert_eq "$2 :: $1" "$1" "$(tags_of "$2")"; }

expect "" 'ls -la'
expect "" 'git status'
expect "" 'echo "git push"'
expect "" 'git merge-base main HEAD'
expect "commit" 'git commit -m x'
expect "commit" 'git -C dir --no-pager commit -am x'
expect "push" 'env X=1 git push origin main'
expect "commit-like merge" 'git merge feature'
expect "commit-like merge" 'git merge --no-ff feature'
expect "pull" 'git pull --rebase'
expect "commit pull" 'git pull && git commit -m x'
expect "mr-create" 'glab mr create --fill'
expect "mr-create" 'gh pr create --fill'
expect "" 'gh pr view 1'
expect "push push-force" 'git push --force origin main'
expect "commit deny:no-verify" 'git commit --no-verify -m x'
expect "commit deny:no-verify" 'git commit -nm x'
expect "deny:hookspath push" 'git -c core.hooksPath=/dev/null push'
expect "commit deny:skip" 'CLEAN_CODE_SKIP=1 git commit -m x'
expect "push" 'sh -c "git push"'
expect "push" 'echo $(git push)'
expect "pull" 'bash -lc "cd d && git pull"'

expect "ask-interpreter" 'echo "git push" | sh'
expect "ask-interpreter" 'echo push | xargs git'
expect "ask-interpreter" 'python3 -c "import os; os.system(\"git push\")"'
expect "" 'python3 -m pytest tests/test_push.py'
expect "push" 'find . -exec git push \;'
expect "commit-like" 'git cherry-pick abc'
expect "commit-like" 'git revert HEAD'
expect "commit-like" 'git am x.patch'
expect "commit-like" 'git commit-tree HEAD^{tree}'
expect "commit-like" 'git update-ref refs/heads/x HEAD'
expect "commit-like" 'git rebase -x true main'
expect "" 'git rebase main'
expect "commit-like" 'git submodule foreach true'
expect "push-like" 'git send-pack origin'
expect "commit-like deny:no-verify merge" 'git merge --no-verify x'
expect "commit-like deny:no-verify" 'git am -n x.patch'
expect "ask-unknown-git" 'git config alias.zz push && git zz'
expect "ask-unknown-git" 'git foo'
expect "" 'git stash list'
expect "deny:hookspath" 'git config core.hooksPath /dev/null'
expect "deny:hookspath" 'git config --global core.hooksPath /x'
expect "deny:hookspath" 'git config --add core.hooksPath /x'
expect "" 'git config --get core.hooksPath'
expect "deny:hookspath" 'git -c core.hooksPath=x status'
expect "deny:hookspath" 'git --config-env=core.hooksPath=V status'
expect "deny:hookspath" 'GIT_CONFIG_KEY_0=core.hooksPath git status'
expect "deny:hookspath" 'GIT_CONFIG_PARAMETERS="core.hooksPath=x" git status'
expect "ask-dynamic" '$(echo git) commit'
expect "ask-dynamic" '"$G" push'
expect "ask-dynamic" "\$'\\x67it' commit"
expect "" '$HOME/bin/tool run'
expect "forge-write" 'gh pr merge 3'
expect "forge-write" 'glab mr merge 3'
expect "forge-write" 'gh api -X POST repos/o/r/issues'
expect "forge-write" 'glab api projects/1/issues -f title=x'
expect "" 'gh api repos/o/r/pulls'
expect "" 'gh api graphql -f query=query'

out="$("$scan" 'git commit -m "unterminated')"
assert_contains "unterminated quote falls back to commit" "$out" "commit"
assert_contains "unterminated quote is flagged" "$out" "unparsed"

json='{"tool_name":"Bash","tool_input":{"command":"git merge x"},"cwd":"."}'
assert_eq "hook JSON on stdin" "commit-like merge" "$(printf '%s' "$json" | "$scan" | paste -sd' ' -)"
assert_eq "non-Bash tool ignored" "" "$(printf '%s' '{"tool_name":"Edit","tool_input":{"command":"git push"}}' | "$scan")"
assert_contains "malformed JSON is treated as text" "$(printf 'git push' | "$scan")" "push"

repo="$TMPROOT/repo"
new_repo "$repo"
git -C "$repo" config alias.ship 'push origin'
git -C "$repo" config alias.sync '!git pull && git push'
assert_eq "git alias to push" "push" "$(printf '%s' '{"tool_input":{"command":"git ship"},"cwd":"'"$repo"'"}' | "$scan")"
assert_eq "shell alias" "pull push" "$(printf '%s' '{"tool_input":{"command":"git sync"},"cwd":"'"$repo"'"}' | "$scan" | paste -sd' ' -)"

"$scan" --help >/dev/null; assert_rc "help" 0 $?
"$scan" --bogus >/dev/null 2>&1; assert_rc "bad flag" 2 $?
finish
