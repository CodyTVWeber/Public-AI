#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/../../../../../scripts/tests/lib.sh"
new_tmp

scripts="$here/.."
repo="$TMPROOT/repo"
new_repo "$repo"
git -C "$repo" checkout -q -b main
printf 'base\n' > "$repo/base.txt"
git -C "$repo" add -- base.txt
git -C "$repo" commit -q -m base
git -C "$repo" checkout -q -b feature
seq 1 50 > "$repo/big.txt"
git -C "$repo" add -- big.txt
git -C "$repo" commit -q -m big
mkdir -p "$repo/guard"
cp "$scripts/claude-pre-tool-guard.sh" "$scripts/check-mr-size.sh" "$scripts/git-scan.sh" "$repo/guard/"
cp -R "$scripts/gitscan" "$repo/guard/gitscan"
guard="$repo/guard/claude-pre-tool-guard.sh"

run() {
  printf '%s' "$(jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}')" \
    | (cd "$repo" && MR_BASE=main MR_SIZE_HARD=10 MR_SIZE_SOFT=5 "$guard" 2>"$TMPROOT/err")
}
blocked() { run "$1" > "$TMPROOT/out"; assert_rc "blocks: $1" 2 $?; }
allowed() { run "$1" > "$TMPROOT/out"; local rc=$?; assert_rc "allows: $1" 0 $rc; assert_eq "silent: $1" "" "$(cat "$TMPROOT/out")"; }

blocked 'git push'
blocked 'git push origin feature'
blocked 'git -C . push'
blocked 'git --no-pager push'
blocked 'env X=1 git push'
blocked 'sh -c "git push"'
blocked 'bash -lc "git add . && git push"'
blocked 'git add . && git push'
blocked 'FOO=bar git push --force'
blocked 'gh pr create --fill'
blocked 'glab mr create --fill'
assert_contains "block message on stderr" "$(cat "$TMPROOT/err")" "Split this work"

allowed 'git status'
allowed 'ls -la'
allowed 'git commit -m x'
allowed 'echo "git push"'
allowed 'gh pr view 1'

out="$(run 'CLEAN_CODE_SKIP=1 git push')"; rc=$?
assert_rc "skip prefix does not block" 0 $rc
assert_eq "skip prefix asks" ask "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision')"
out="$(run 'export CLEAN_CODE_SKIP=1; git push')"
assert_eq "exported skip asks" ask "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision')"
out="$(run 'CLEAN_CODE_SKIP=0 git push')"; rc=$?
assert_rc "skip=0 is not a bypass, size still enforced" 2 $rc

small="$TMPROOT/small"
new_repo "$small"
git -C "$small" checkout -q -b main
printf 'a\n' > "$small/a.txt"
git -C "$small" add -- a.txt
git -C "$small" commit -q -m a
git -C "$small" checkout -q -b feature
printf 'b\n' > "$small/b.txt"
git -C "$small" add -- b.txt
git -C "$small" commit -q -m b
out="$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git push"}}' | (cd "$small" && MR_BASE=main MR_SIZE_HARD=10 "$guard" 2>&1))"; rc=$?
assert_rc "small branch allowed" 0 $rc
assert_eq "small branch silent" "" "$out"

none="$TMPROOT/none"
new_repo "$none"
git -C "$none" checkout -q -b main
printf 'a\n' > "$none/a.txt"
git -C "$none" add -- a.txt
git -C "$none" commit -q -m a
out="$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git push"}}' | (cd "$none" && MR_BASE=main "$guard" 2>&1))"; rc=$?
assert_rc "no changes allowed" 0 $rc

nobase="$TMPROOT/nobase"
new_repo "$nobase"
git -C "$nobase" checkout -q -b trunk
printf 'a\n' > "$nobase/a.txt"
git -C "$nobase" add -- a.txt
git -C "$nobase" commit -q -m a
out="$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git push"}}' | (cd "$nobase" && env -u MR_BASE "$guard" 2>/dev/null))"; rc=$?
assert_rc "cannot measure does not fail open silently" 0 $rc
assert_eq "cannot measure asks" ask "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision')"

rm -f "$repo/guard/check-mr-size.sh"
out="$(run 'git push')"; rc=$?
assert_eq "missing checker asks" ask "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision')"

out="$("$guard" --help)"; assert_rc "help" 0 $?

dirty="$TMPROOT/dirty"
new_repo "$dirty"
git -C "$dirty" checkout -q -b main
printf 'a\n' > "$dirty/a.txt"
git -C "$dirty" add -- a.txt
git -C "$dirty" commit -q -m a
git -C "$dirty" checkout -q -b feature
mkdir -p "$dirty/guard"
printf 'guard/\n' >> "$dirty/.git/info/exclude"
cp -R "$scripts"/*.sh "$scripts/cleancode" "$scripts/gitscan" "$dirty/guard/"
printf 'export const b = 1;\n// note\n' > "$dirty/b.ts"
git -C "$dirty" add -- b.ts
git -C "$dirty" commit -q -m b
push_json='{"tool_name":"Bash","tool_input":{"command":"git push"}}'
out="$(printf '%s' "$push_json" | (cd "$dirty" && MR_BASE=main "$dirty/guard/claude-pre-tool-guard.sh" 2>&1))"; rc=$?
assert_rc "clean-code errors on the branch block a push" 2 $rc
assert_contains "clean-code block names the rule" "$out" "added-comment"
git -C "$dirty" rm -q -f b.ts
printf 'export const b = 1;\n' > "$dirty/b.ts"
git -C "$dirty" add -- b.ts
git -C "$dirty" commit -q -m b2
out="$(printf '%s' "$push_json" | (cd "$dirty" && MR_BASE=main "$dirty/guard/claude-pre-tool-guard.sh" 2>&1))"; rc=$?
assert_rc "clean branch push allowed" 0 $rc

printf 'const scratch = 1;\n// untracked note\n' > "$dirty/scratch.ts"
out="$(printf '%s' "$push_json" | (cd "$dirty" && MR_BASE=main "$dirty/guard/claude-pre-tool-guard.sh" 2>&1))"; rc=$?
assert_rc "untracked scratch file does not block a push" 0 $rc

remote="$TMPROOT/remote.git"
git init -q --bare "$remote"
up="$TMPROOT/up"
new_repo "$up"
git -C "$up" checkout -q -b main
printf 'a\n' > "$up/a.txt"
git -C "$up" add -- a.txt
git -C "$up" commit -q -m a
git -C "$up" checkout -q -b feature
printf 'export const b = 1;\n// old note\n' > "$up/b.ts"
git -C "$up" add -- b.ts
git -C "$up" commit -q -m bad
git -C "$up" remote add origin "$remote"
git -C "$up" push -q -u origin feature 2>/dev/null
printf 'x\n' > "$up/c.txt"
git -C "$up" add -- c.txt
git -C "$up" commit -q -m c
printf 'guard/\n' >> "$up/.git/info/exclude"
mkdir -p "$up/guard"
cp -R "$scripts"/*.sh "$scripts/cleancode" "$scripts/gitscan" "$up/guard/"
out="$(printf '%s' "$push_json" | (cd "$up" && MR_BASE=main "$up/guard/claude-pre-tool-guard.sh" 2>&1))"; rc=$?
assert_rc "only the commits being pushed are analysed" 0 $rc
git -C "$up" checkout -q -b fresh main
git -C "$up" checkout -q feature -- b.ts
git -C "$up" commit -q -m again
out="$(printf '%s' "$push_json" | (cd "$up" && MR_BASE=main "$up/guard/claude-pre-tool-guard.sh" 2>&1))"; rc=$?
assert_rc "a branch with no upstream is analysed against the base" 2 $rc

"$scripts/check-mr-size.sh" --help >/dev/null; assert_rc "mr-size help" 0 $?
out="$(cd "$small" && MR_BASE=main "$scripts/check-mr-size.sh" --print-base)"; assert_eq "print-base" main "$out"
finish
