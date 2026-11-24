#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/forge-helpers.sh"
ctx="$scripts/forge-ctx.sh"

mk_repo "$tmp" "https://gitlab.example.test/grp/proj"
cd "$tmp/work"

run "$ctx"
check "clean exit" 0 "$rc"
jcheck "host" .host '"gitlab"'
jcheck "cli" .cli '"glab"'
jcheck "project" .project '"grp/proj"'
jcheck "branch" .branch '"main"'
jcheck "base" .base '"origin/main"'
jcheck "default" .default_branch '"main"'
jcheck "clean" .clean true
jcheck "dirty empty" .dirty_files '[]'
jcheck "behind" .behind 0
jcheck "ahead" .ahead 0

printf 'two\n' >>a.txt
printf 'new\n' >b.txt
run "$ctx"
jcheck "dirty clean flag" .clean false
jcheck "dirty files" '.dirty_files | sort' '["a.txt","b.txt"]'
git checkout -q -- a.txt
rm b.txt

git checkout -q -b feat/x
printf 'c\n' >c.txt
git add c.txt
git commit -q -m local
push_from_other_clone "$tmp" other.txt
git fetch -q origin
run "$ctx"
jcheck "ahead 1" .ahead 1
jcheck "behind 1" .behind 1
jcheck "feature branch" .branch '"feat/x"'

git checkout -q --detach
run "$ctx"
jcheck "detached branch null" .branch null

rm -rf "$tmp/gh"
mkdir "$tmp/gh"
mk_repo "$tmp/gh" "ssh://github.example.test/grp/proj"
cd "$tmp/gh/work"
run "$ctx"
jcheck "github host" .host '"github"'
jcheck "github cli" .cli '"gh"'
jcheck "github project" .project '"grp/proj"'

h=github.example.test
git remote set-url origin "git@${h}:grp/proj"
run "$ctx"
jcheck "scp project" .project '"grp/proj"'
jcheck "scp host" .host '"github"'

git remote set-url origin "https://code.example.test/grp/sub/proj"
run "$ctx"
check "unknown forge exit" 3 "$rc"
run env PIR_FORGE=gitlab "$ctx"
check "override exit" 0 "$rc"
jcheck "override host" .host '"gitlab"'
jcheck "override project" .project '"grp/sub/proj"'

git remote remove origin
run "$ctx"
check "no origin exit" 3 "$rc"

cd "$tmp"
mkdir nogit
cd nogit
run "$ctx"
check "not a repo exit" 3 "$rc"

run "$ctx" --help
check "help exit" 0 "$rc"
run "$ctx" bogus
check "bad arg exit" 2 "$rc"

finish
