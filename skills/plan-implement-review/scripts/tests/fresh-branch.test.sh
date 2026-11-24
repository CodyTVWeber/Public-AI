#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/forge-helpers.sh"
fb="$scripts/fresh-branch.sh"

mk_repo "$tmp" "https://gitlab.example.test/grp/proj"
cd "$tmp/work"
git checkout -q -b feat/old
printf 'f\n' >f.txt
git add f.txt
git commit -q -m feature

push_from_other_clone "$tmp" newer.txt
remote_sha=$(git -C "$tmp/origin.git" rev-parse main)

run "$fb" plan/topic
check "success exit" 0 "$rc"
jcheck "branch" .branch '"plan/topic"'
jcheck "base" .base '"origin/main"'
jcheck "base sha is fetched remote head" .base_sha "\"$remote_sha\""
jcheck "previous" .previous_branch '"feat/old"'
check "checked out" plan/topic "$(git branch --show-current)"
check "head is base" "$remote_sha" "$(git rev-parse HEAD)"
check "no feature commit" "" "$(ls f.txt 2>/dev/null || true)"
if git rev-parse --abbrev-ref 'plan/topic@{u}' >/dev/null 2>&1; then
  check "no upstream" none set
else
  check "no upstream" none none
fi

run "$fb" plan/topic
check "existing branch exit" 3 "$rc"

git checkout -q feat/old
printf 'dirty\n' >>f.txt
run "$fb" plan/other
check "dirty exit" 3 "$rc"
check "dirty stays on branch" feat/old "$(git branch --show-current)"
check "dirty no branch created" "" "$(git branch --list plan/other)"
case "$err" in *f.txt*) check "dirty names file" ok ok ;; *) check "dirty names file" ok "$err" ;; esac
git checkout -q -- f.txt

run "$fb" plan/third origin/nope
check "missing base exit" 3 "$rc"
check "missing base no branch" "" "$(git branch --list plan/third)"

git tag marker "$remote_sha"
run "$fb" plan/fromtag marker
check "explicit local base exit" 0 "$rc"
jcheck "explicit base" .base '"marker"'

run "$fb" 'bad name'
check "invalid name exit" 2 "$rc"
run "$fb"
check "no args exit" 2 "$rc"
run "$fb" a b c
check "too many args exit" 2 "$rc"
run "$fb" --help
check "help exit" 0 "$rc"

finish
