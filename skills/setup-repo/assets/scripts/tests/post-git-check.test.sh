#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/../../../../../scripts/tests/lib.sh"
new_tmp

scripts="$here/.."
repo="$TMPROOT/repo"
new_repo "$repo"
git -C "$repo" checkout -q -b main
mkdir -p "$repo/scripts/clean-code"
cp -R "$scripts"/*.sh "$scripts/cleancode" "$scripts/gitscan" "$repo/scripts/clean-code/"
printf 'scripts/\n' >> "$repo/.git/info/exclude"
hook="$repo/scripts/clean-code/post-git-check.sh"

run() {
  local out="${2:-}"
  jq -nc --arg c "$1" --arg o "$out" --arg d "$repo" \
    '{hook_event_name:"PostToolUse",tool_name:"Bash",tool_input:{command:$c},tool_response:{stdout:$o,stderr:""},cwd:$d}' \
    | MR_BASE=main "$hook" 2>"$TMPROOT/err" >"$TMPROOT/out"
}
context() { jq -r '.hookSpecificOutput.additionalContext // empty' "$TMPROOT/out" 2>/dev/null; }
commit_file() {
  printf '%b' "$2" > "$repo/$1"
  git -C "$repo" add -- "$1"
  git -C "$repo" commit -q -m "${3:-add $1}"
}

run 'ls -la'; assert_rc "non-git command passes" 0 $?
assert_eq "non-git command silent" "" "$(cat "$TMPROOT/out")"
run 'git status'; assert_rc "git status passes" 0 $?
assert_eq "git status silent" "" "$(cat "$TMPROOT/out")"
run 'echo "git commit -m x"'; assert_rc "quoted text passes" 0 $?
assert_eq "quoted text silent" "" "$(cat "$TMPROOT/out")"

commit_file base.ts 'export const base = 1;\n' 'init'
run 'git commit -m init'; assert_rc "root commit clean" 0 $?
assert_eq "root commit silent" "" "$(cat "$TMPROOT/out")"

git -C "$repo" checkout -q -b feature
commit_file ok.ts 'export const ok = 1;\n'
run 'git add -A && git commit -m ok'; assert_rc "clean commit passes" 0 $?
assert_eq "clean commit silent" "" "$(cat "$TMPROOT/out")"

commit_file bad.ts 'export const bad = 1;\n// note\n'
run 'git commit -m bad'; assert_rc "added comment in commit never exits 2" 0 $?
assert_contains "finding names file and rule" "$(context)" "bad.ts:2 [added-comment]"
assert_contains "finding says what to do" "$(context)" "clean-code errors"
assert_contains "finding says not to commit again" "$(context)" "instead of committing again"
assert_eq "no stderr feedback for a finished commit" "" "$(cat "$TMPROOT/err")"
assert_eq "event name is PostToolUse" "PostToolUse" "$(jq -r '.hookSpecificOutput.hookEventName' "$TMPROOT/out")"

printf 'export const dirty = 1;\n// uncommitted wip\n' > "$repo/wip.ts"
run 'git commit -m again'; assert_not_contains "working-tree wip is not the commit" "$(context)" "wip.ts"
rm "$repo/wip.ts"

printf 'export const bad = 1;\n' > "$repo/bad.ts"
git -C "$repo" commit -q -am 'fix: drop comment'
run 'git commit --amend -m x'; assert_rc "fixed follow-up passes" 0 $?

printf '// old\nexport const legacy = 1;\n' > "$repo/legacy.ts"
git -C "$repo" add -- legacy.ts
git -C "$repo" commit -q -m 'legacy'
git -C "$repo" checkout -q main
git -C "$repo" merge -q --ff-only feature
git -C "$repo" checkout -q -b more
printf '// old\nexport const legacy = 1;\nexport const extra = 2;\n' > "$repo/legacy.ts"
git -C "$repo" commit -q -am 'touch legacy'
run 'git commit -am x'; assert_rc "only the commit's own lines count" 0 $?
[ -s "$TMPROOT/err" ] && bad "legacy comment not reported" "$(cat "$TMPROOT/err")" || ok

long="$(printf 'x%.0s' $(seq 1 90))"
commit_file subj.ts 'export const s = 1;\n' "feat: $long"
run 'git commit -m long'; assert_rc "long subject does not block" 0 $?
assert_contains "long subject noted" "$(context)" "subject is"
assert_contains "long subject names the limit" "$(context)" "72"

commit_file wide.txt "$(seq 1 30)\n" 'add wide'
out="$(jq -nc --arg c 'git commit -m w' --arg d "$repo" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}' | MR_SIZE_SOFT=5 MR_SIZE_HARD=1000 MR_BASE=main "$hook" 2>&1)"
assert_contains "size over soft budget noted" "$out" "soft size budget"
out="$(jq -nc --arg c 'git commit -m w' --arg d "$repo" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}' | MR_SIZE_SOFT=2 MR_SIZE_HARD=5 MR_BASE=main "$hook" 2>&1)"; rc=$?
assert_rc "size over hard budget does not block a finished commit" 0 $rc
assert_contains "size over hard budget noted" "$out" "hard size budget"

run 'git push origin more'; assert_rc "push passes" 0 $?
assert_contains "push reminds one PR" "$(context)" "exactly one PR/MR"
assert_contains "push reminds watch" "$(context)" "watch skill"
assert_contains "push names the branch" "$(context)" "more"
mkdir -p "$repo/.claude/skills/plan-implement-review/scripts"
printf '#!/usr/bin/env bash\nexit 0\n' > "$repo/.claude/skills/plan-implement-review/scripts/pr-find.sh"
chmod +x "$repo/.claude/skills/plan-implement-review/scripts/pr-find.sh"
run 'git push'; assert_contains "push names pr-find when installed" "$(context)" "pr-find.sh more"
run 'git add . && git commit -m y && git push'; assert_contains "compound command still reaches push" "$(context)" "watch skill"

git -C "$repo" checkout -q main
printf 'one\n' > "$repo/clash.txt"; git -C "$repo" add -- clash.txt; git -C "$repo" commit -q -m clash1
git -C "$repo" checkout -q -b side
printf 'side\n' > "$repo/clash.txt"; git -C "$repo" commit -q -am side
git -C "$repo" checkout -q main
printf 'main\n' > "$repo/clash.txt"; git -C "$repo" commit -q -am main2
git -C "$repo" merge side >/dev/null 2>&1
run 'git merge side' 'CONFLICT (content): Merge conflict in clash.txt'; assert_rc "conflicted merge passes" 0 $?
assert_contains "conflicts listed" "$(context)" "clash.txt"
printf 'export const merged = 1;\n// resolved\n' > "$repo/resolved.ts"
printf 'both\n' > "$repo/clash.txt"
git -C "$repo" add -- clash.txt resolved.ts
git -C "$repo" commit -q -m 'merge side'
run 'git commit'; assert_rc "merge commit checks the merged files without blocking" 0 $?
assert_contains "merge finding" "$(context)" "resolved.ts"
git -C "$repo" reset -q --hard HEAD^

git -C "$repo" checkout -q -b ffbranch
commit_file ff.ts 'export const ff = 1;\n'
git -C "$repo" checkout -q main
git -C "$repo" merge -q --ff-only ffbranch
run 'git pull'; assert_rc "fast-forward pull passes" 0 $?
assert_eq "fast-forward pull silent" "" "$(cat "$TMPROOT/out")"

POST_GIT_SKIP=1 run 'git push'; assert_eq "skip env silences the hook" "" "$(cat "$TMPROOT/out")"

printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git push"},"cwd":"/nonexistent-dir"}' | "$hook" >/dev/null 2>&1; assert_rc "missing cwd passes" 0 $?
printf '%s' 'not json' | "$hook" >/dev/null 2>&1; assert_rc "malformed input passes" 0 $?
plain="$TMPROOT/plain"; mkdir -p "$plain"
jq -nc --arg d "$plain" '{tool_name:"Bash",tool_input:{command:"git commit -m x"},cwd:$d}' | "$hook" >/dev/null 2>&1; assert_rc "non-repo cwd passes" 0 $?
mv "$repo/scripts/clean-code/git-scan.sh" "$repo/scripts/clean-code/git-scan.off"
run 'git push'; assert_rc "missing scanner passes" 0 $?
assert_eq "missing scanner silent" "" "$(cat "$TMPROOT/out")"
assert_contains "help says errors never exit 2" "$("$hook" --help)" "never exits 2"
"$hook" --help >/dev/null; assert_rc "help" 0 $?
"$hook" --bogus >/dev/null 2>&1; assert_rc "bad flag" 2 $?
finish
