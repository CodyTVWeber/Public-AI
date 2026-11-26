#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"
split="$scripts/worktree-split.sh"

repo="$tmp/repo"
mk_repo "$repo"
cd "$repo"
root="$tmp/out/wt"

run "$split" --base feat/topic --topic demo --slices a,b --root "$root"
check split-exit 0 "$rc"
jcheck split-names '[.slices[].name]' '["a","b"]'
jcheck split-branch '.slices[0].branch' '"feat/topic--a"'
jcheck split-path '.slices[0].path' "\"$root/a\""
check worktrees-created 3 "$(wt_count "$repo")"
check branch-a-exists feat/topic--a "$(git for-each-ref --format='%(refname:short)' refs/heads/feat/topic--a)"
check slice-head-is-base "$(git rev-parse feat/topic)" "$(git -C "$root/b" rev-parse HEAD)"
check slice-on-branch feat/topic--b "$(git -C "$root/b" branch --show-current)"
check manifest-written feat/topic "$(jq -r .base "$root/manifest.json")"
check repo-untouched "" "$(git status --porcelain)"

run "$split" --base feat/topic --topic demo --slices a,b --root "$root"
check resplit-refused 3 "$rc"

run "$split" --base feat/topic --topic demo3 --slices a --root "$tmp/out3"
check existing-branch-refused 3 "$rc"
check no-extra-worktree 3 "$(wt_count "$repo")"
check no-root-left "" "$(ls -d "$tmp/out3" 2>/dev/null || true)"

mkdir -p "$tmp/out4/c"
run "$split" --base feat/topic --topic demo4 --slices c --root "$tmp/out4"
check existing-path-refused 3 "$rc"

run "$split" --base feat/topic --topic demo5 --slices z --root "$repo/inside"
check root-inside-repo-refused 3 "$rc"
check inside-not-created "" "$(ls -d "$repo/inside" 2>/dev/null || true)"

printf 'dirt\n' >>"$repo/shared.txt"
run "$split" --base feat/topic --topic demo6 --slices y --root "$tmp/out6"
check dirty-refused 3 "$rc"
check dirty-no-branch "" "$(git branch --list 'feat/topic--y')"
git -C "$repo" checkout -q -- shared.txt

run "$split" --base nope --topic demo7 --slices y --root "$tmp/out7"
check missing-base 3 "$rc"

run "$split" --base feat/topic --topic demo8 --slices 'Bad_Name' --root "$tmp/out8"
check bad-name 2 "$rc"
run "$split" --base feat/topic --topic demo8 --slices a,a --root "$tmp/out8"
check duplicate-name 2 "$rc"
run "$split" --base feat/topic --topic demo8 --slices a --mode other --root "$tmp/out8"
check bad-mode 2 "$rc"
run "$split" --base feat/topic
check missing-flags 2 "$rc"
run "$split" --help
check help 0 "$rc"

git branch feat/topic--ok2/x
before=$(wt_count "$repo")
run "$split" --base feat/topic --topic demo9 --slices aa,ok2 --root "$tmp/out9"
check rollback-exit 3 "$rc"
check rollback-worktrees "$before" "$(wt_count "$repo")"
check rollback-branch "" "$(git branch --list 'feat/topic--aa')"
check rollback-dirs "" "$(ls -d "$tmp/out9" 2>/dev/null || true)"

repo2="$tmp/repo2"
mk_repo "$repo2"
cd "$repo2"
clone_root="$tmp/clones/wt"
run "$split" --base feat/topic --topic demo10 --slices a,b --root "$clone_root" --mode clone
check clone-exit 0 "$rc"
jcheck clone-mode .mode '"clone"'
check clone-is-repo true "$(git -C "$clone_root/a" rev-parse --is-inside-work-tree)"
check clone-branch feat/topic--a "$(git -C "$clone_root/a" branch --show-current)"
check clone-head "$(git rev-parse feat/topic)" "$(git -C "$clone_root/a" rev-parse HEAD)"
check clone-not-a-worktree 1 "$(wt_count "$repo2")"
check clone-no-branch-in-main "" "$(git for-each-ref refs/heads/feat/topic--a)"

cd "$repo"
git worktree add -q "$tmp/linked" -b linked-br
cd "$tmp/linked"
run "$split" --base feat/topic --topic demo11 --slices q --root "$tmp/out11"
check linked-worktree-refused 3 "$rc"

finish
