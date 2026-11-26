#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"
split="$scripts/worktree-split.sh"
merge="$scripts/worktree-merge.sh"
clean="$scripts/worktree-clean.sh"

scenario() {
  repo="$tmp/$1/repo"
  root="$tmp/$1/wt"
  mk_repo "$repo"
  cd "$repo"
  run "$split" --base feat/topic --topic "$1" --slices a,b --root "$root" ${2:+--mode "$2"}
  commit_file "$root/a" src/a/new.txt "from a"
  commit_file "$root/b" src/b/new.txt "from b"
}

scenario wt
run "$merge" --into feat/topic --topic wt --slices a,b --root "$root"
check merge-exit 0 "$rc"
jcheck merge-merged .merged '["a","b"]'
jcheck merge-no-conflict .conflict null
check merge-files "from a from b" "$(cat src/a/new.txt src/b/new.txt | tr '\n' ' ' | sed 's/ $//')"
check merge-commits 2 "$(git log --merges --format=%s | grep -c '^Merge slice')"
check merge-clean-tree "" "$(git status --porcelain)"

run "$clean" --topic wt --root "$root"
check clean-exit 0 "$rc"
jcheck clean-removed .removed '["a","b"]'
jcheck clean-left .worktrees_left 0
check clean-one-entry 1 "$(wt_count "$repo")"
check clean-branches "" "$(git for-each-ref refs/heads/feat/topic--a refs/heads/feat/topic--b)"
check clean-root-gone "" "$(ls -d "$root" 2>/dev/null || true)"
run "$clean" --topic wt --root "$root"
check clean-idempotent 0 "$rc"

scenario conflict
commit_file "$root/a" shared.txt "a side"
commit_file "$root/b" shared.txt "b side"
run "$merge" --into feat/topic --topic conflict --slices a,b --root "$root"
check conflict-exit 1 "$rc"
jcheck conflict-merged .merged '["a"]'
jcheck conflict-slice .conflict.slice '"b"'
jcheck conflict-files .conflict.files '["shared.txt"]'
check conflict-state MERGE_HEAD "$(basename "$(ls .git/MERGE_HEAD)")"
run "$merge" --into feat/topic --topic conflict --slices b --root "$root"
check merge-refuses-dirty 3 "$rc"
run "$clean" --topic conflict --root "$root"
check clean-blocked-while-unmerged 1 "$rc"
git merge --abort

scenario order
run "$merge" --into main --topic order --slices a,b --root "$root"
check wrong-branch 3 "$rc"
run "$merge" --into feat/topic --topic order --slices a,nope --root "$root"
check missing-slice-branch 3 "$rc"
jcheck missing-slice-merged-before .merged '["a"]'
run "$merge" --into feat/topic --topic order --slices a,b --root "$root"
check rerun-skips-merged 0 "$rc"

scenario order2
run "$merge" --into feat/topic --topic order2 --slices b,a --root "$root"
check order2-exit 0 "$rc"
check merge-order "b a" "$(git log --merges --format=%s --reverse | sed 's/Merge slice \([a-z]*\) into.*/\1/' | tr '\n' ' ' | sed 's/ $//')"

scenario unmerged
run "$clean" --topic unmerged --root "$root"
check unmerged-exit 1 "$rc"
jcheck unmerged-kept '[.kept[] | [.slice, .commits]]' '[["a",1],["b",1]]'
jcheck unmerged-left .worktrees_left 2
check unmerged-worktrees-intact 3 "$(wt_count "$repo")"
check unmerged-branches-intact feat/topic--a "$(git for-each-ref --format='%(refname:short)' refs/heads/feat/topic--a)"
run "$merge" --into feat/topic --topic unmerged --slices a --root "$root"
run "$clean" --topic unmerged --root "$root"
check partial-exit 1 "$rc"
jcheck partial-removed .removed '["a"]'
jcheck partial-kept '[.kept[].slice]' '["b"]'
printf 'wip\n' >"$root/b/untracked.txt"
run "$clean" --topic unmerged --root "$root" --force
check force-exit 0 "$rc"
jcheck force-discarded '[.discarded[] | [.slice, .commits, .dirty]]' '[["b",1,true]]'
check force-one-entry 1 "$(wt_count "$repo")"
check force-branch-gone "" "$(git for-each-ref refs/heads/feat/topic--b)"

scenario dirty
git -C "$root/a" reset -q --hard HEAD~1
printf 'wip\n' >"$root/a/wip.txt"
run "$clean" --topic dirty --root "$root"
check dirty-slice-kept 1 "$rc"
jcheck dirty-flag '[.kept[] | select(.slice == "a") | .dirty]' '[true]'

scenario clone clone
run "$merge" --into feat/topic --topic clone --slices a,b --root "$root" --mode clone
check clone-merge-exit 0 "$rc"
check clone-merge-file "from a" "$(cat src/a/new.txt)"
check clone-merge-ref feat/topic--a "$(git -C "$root/a" branch --show-current)"
run "$clean" --topic clone --root "$root"
check clone-clean-exit 0 "$rc"
jcheck clone-clean-removed .removed '["a","b"]'
check clone-dirs-gone "" "$(ls -d "$root" 2>/dev/null || true)"
check clone-refs-gone "" "$(git for-each-ref refs/pir)"

scenario clonekeep clone
run "$clean" --topic clonekeep --root "$root"
check clone-unmerged-exit 1 "$rc"
jcheck clone-unmerged-kept '[.kept[].commits]' '[1,1]'
check clone-unmerged-dirs 2 "$(ls "$root" | grep -c '^[ab]$')"
run "$clean" --topic clonekeep --root "$root" --force
check clone-force-exit 0 "$rc"
check clone-force-gone "" "$(ls -d "$root" 2>/dev/null || true)"

scenario safe-unrelated
mkdir -p "$tmp/unrel/a"
printf 'keep\n' >"$tmp/unrel/a/f.txt"
run "$clean" --topic safe-unrelated --root "$tmp/unrel"
check unrelated-exit 0 "$rc"
check unrelated-intact keep "$(cat "$tmp/unrel/a/f.txt")"
run "$clean" --topic safe-unrelated --root "$tmp/unrel" --into feat/topic
check unrelated-into-exit 0 "$rc"
check unrelated-dir-kept 1 "$(ls -d "$tmp/unrel" | wc -l | tr -d ' ')"

run "$clean" --topic safe-unrelated --root "$repo"
check root-is-repo 3 "$rc"
check root-is-repo-intact feat/topic "$(git branch --show-current)"
run "$clean" --topic safe-unrelated --root "$tmp/safe-unrelated"
check root-parent-of-repo 3 "$rc"
check root-parent-intact "$repo/src/a/a.txt" "$(ls "$repo/src/a/a.txt")"

scenario xrepo
other="$tmp/xrepo/other"
mk_repo "$other"
cp "$root/manifest.json" "$tmp/xrepo/manifest.bak"
printf 'wip\n' >"$root/a/wip.txt"
cd "$other"
run "$clean" --topic xrepo --root "$root" --into feat/topic --force
check xrepo-exit 1 "$rc"
jcheck xrepo-skipped '[.skipped[] | [.slice, .reason]]' '[["a","not a worktree of this repository"],["b","not a worktree of this repository"]]'
jcheck xrepo-nothing-removed .removed '[]'
check xrepo-files wip "$(cat "$root/a/wip.txt")"
check xrepo-b-intact "from b" "$(cat "$root/b/src/b/new.txt")"
check xrepo-manifest-kept 1 "$(ls "$root/manifest.json" | wc -l | tr -d ' ')"
check xrepo-owner-intact 3 "$(wt_count "$repo")"
cd "$repo"

scenario xclone clone
other="$tmp/xclone/other"
mk_repo "$other"
cd "$other"
run "$clean" --topic xclone --root "$root" --mode clone --into feat/topic --force
check xclone-exit 1 "$rc"
jcheck xclone-skipped '[.skipped[].reason]' '["not a clone of this repository","not a clone of this repository"]'
check xclone-intact 2 "$(ls "$root" | grep -c '^[ab]$')"
check xclone-no-refs "" "$(git for-each-ref refs/pir)"
cd "$repo"

scenario badnames
jq -c '.slices += [{name: "..", path: "x", branch: "y"}, {name: "Bad", path: "x", branch: "y"}]' "$root/manifest.json" >"$tmp/m.json"
cp "$tmp/m.json" "$root/manifest.json"
mkdir -p "$tmp/badnames/Bad"
run "$clean" --topic badnames --root "$root" --force
check badnames-exit 1 "$rc"
jcheck badnames-skipped '[.skipped[] | [.slice, .reason]]' '[["..","invalid slice name"],["Bad","invalid slice name"]]'
jcheck badnames-removed .removed '["a","b"]'
check badnames-untouched 1 "$(ls -d "$tmp/badnames/Bad" | wc -l | tr -d ' ')"

scenario brokenptr
printf 'precious\n' >"$root/a/wip.txt"
printf 'gitdir: %s/nowhere\n' "$tmp" >"$root/a/.git"
run "$clean" --topic brokenptr --root "$root"
check broken-exit 1 "$rc"
jcheck broken-kept '[.kept[] | select(.slice == "a") | .dirty]' '[true]'
check broken-file precious "$(cat "$root/a/wip.txt")"
run "$clean" --topic brokenptr --root "$root" --force
jcheck broken-force-removed '[.skipped[]?.slice, .removed[]] | sort' '["a","b"]'

scenario amend clone
run "$merge" --into feat/topic --topic amend --slices a --root "$root" --mode clone
check amend-first 0 "$rc"
git reset -q --hard HEAD~1
git -C "$root/a" commit -q --amend -m "amended"
run "$merge" --into feat/topic --topic amend --slices a --root "$root" --mode clone
check amend-rerun-merge 0 "$rc"
git -C "$root/b" commit -q --amend -m "amended b"
run "$clean" --topic amend --root "$root" --mode clone --force
check amend-clean-fetch-forced 0 "$rc"

scenario resolve clone
rm -rf "$root/b"
run "$merge" --into feat/topic --topic resolve --slices a,b --root "$root" --mode clone
check resolve-exit 3 "$rc"
check resolve-own-error 1 "$(printf '%s' "$err" | grep -c 'fetch failed for slice: b')"
check resolve-not-conflict 0 "$(printf '%s' "$err" | grep -c 'without a conflict')"
jcheck resolve-merged .merged '["a"]'
jcheck resolve-pending .pending '["b"]'

scenario resolvewt
run "$merge" --into feat/topic --topic resolvewt --slices a,nope --root "$root"
check resolvewt-exit 3 "$rc"
check resolvewt-own-error 1 "$(printf '%s' "$err" | grep -c 'slice branch not found')"
check resolvewt-not-conflict 0 "$(printf '%s' "$err" | grep -c 'without a conflict')"
jcheck resolvewt-pending .pending '["nope"]'

repo="$tmp/defroot/repo"
mk_repo "$repo"
cd "$repo"
cache="$tmp/cache"
run env XDG_CACHE_HOME="$cache" "$split" --base feat/topic --topic defroot --slices a,b --mode clone
check defroot-split 0 "$rc"
jcheck defroot-root .root "\"$cache/pir-defroot/wt\""
run env XDG_CACHE_HOME="$cache" "$clean" --topic defroot --force
check defroot-clean 0 "$rc"
check defroot-gone "" "$(ls -d "$cache/pir-defroot/wt" 2>/dev/null || true)"

run "$clean" --help
check help 0 "$rc"
run "$clean"
check no-topic 2 "$rc"
run "$merge" --topic x
check merge-no-flags 2 "$rc"

finish
