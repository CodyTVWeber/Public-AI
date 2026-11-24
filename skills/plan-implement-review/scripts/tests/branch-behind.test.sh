#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/forge-helpers.sh"
bb="$scripts/branch-behind.sh"

mk_repo "$tmp" "https://gitlab.example.test/grp/proj"
cd "$tmp/work"

git checkout -q -b feat/clean
printf 'f\n' >feature.txt
git add feature.txt
git commit -q -m feature
push_from_other_clone "$tmp" remote.txt
git fetch -q origin
head_before=$(git rev-parse HEAD)

run "$bb" origin/main
check "clean exit" 0 "$rc"
jcheck "behind" .behind 1
jcheck "ahead" .ahead 1
jcheck "no conflicts" .conflicts false
check "head unchanged" "$head_before" "$(git rev-parse HEAD)"
check "tree unchanged" "" "$(git status --porcelain)"

git push -q origin origin/main:refs/heads/rel
git fetch -q origin
run "$bb" rel
jcheck "bare name falls back to remote ref" .target '"origin/rel"'

git checkout -q -b feat/conflict origin/main~1
printf 'mine\n' >remote.txt
git add remote.txt
git commit -q -m mine
run "$bb" origin/main
jcheck "conflict detected" .conflicts true
check "tree unchanged after conflict check" "" "$(git status --porcelain)"

git checkout -q --orphan unrelated
git rm -rfq . >/dev/null
printf 'u\n' >u.txt
git add u.txt
git commit -q -m unrelated
run "$bb" origin/main
check "unrelated exit" 0 "$rc"
jcheck "unrelated conflicts null" .conflicts null

mkdir -p "$tmp/bin"
printf '#!/usr/bin/env bash\n[ "${1:-}" = merge-tree ] && exit 129\nexec %s "$@"\n' "$real_git" >"$tmp/bin/git"
chmod +x "$tmp/bin/git"
git checkout -q feat/clean
PATH="$tmp/bin:$PATH" run "$bb" origin/main
check "old git exit" 0 "$rc"
jcheck "old git conflicts null" .conflicts null
jcheck "old git behind still counted" .behind 1
rm "$tmp/bin/git"

run "$bb" nope
check "missing target exit" 3 "$rc"
run "$bb"
check "no args exit" 2 "$rc"
run "$bb" --help
check "help exit" 0 "$rc"

finish
