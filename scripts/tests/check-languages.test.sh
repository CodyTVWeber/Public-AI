#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib.sh"
new_tmp

repo="$TMPROOT/repo"
new_repo "$repo"
mkdir -p "$repo/scripts/lint"
cp "$here/../lint/check-languages.sh" "$repo/scripts/lint/"
tool="$repo/scripts/lint/check-languages.sh"
printf 'x\n' > "$repo/seed.txt"
git -C "$repo" add -A
git -C "$repo" commit -q -m seed
base="$(git -C "$repo" rev-parse HEAD)"

printf 'echo\n' > "$repo/a.sh"
printf 'export {}\n' > "$repo/b.mjs"
git -C "$repo" add -A
out="$(cd "$repo" && "$tool" --staged 2>&1)"; assert_rc "bash and js pass" 0 $?

printf 'print(1)\n' > "$repo/tool.py"
mkdir -p "$repo/vendor"
printf 'print(2)\n' > "$repo/vendor/x.py"
git -C "$repo" add -A
out="$(cd "$repo" && "$tool" 2>&1)"; assert_rc "python fails" 1 $?
assert_contains "names file" "$out" "tool.py"
assert_contains "names vendor file" "$out" "vendor/x.py"

printf '^vendor/\n' > "$repo/.languageexempt"
git -C "$repo" add -A
out="$(cd "$repo" && "$tool" 2>&1)"; assert_rc "exempt skips only matches" 1 $?
assert_not_contains "exempt path skipped" "$out" "vendor/x.py"
assert_contains "other still flagged" "$out" "tool.py"

git -C "$repo" rm -q --cached tool.py
rm "$repo/tool.py"
out="$(cd "$repo" && "$tool" 2>&1)"; assert_rc "only exempt passes" 0 $?

printf 'puts 1\n' > "$repo/r.rb"
git -C "$repo" add -A
git -C "$repo" commit -q -m add
out="$(cd "$repo" && "$tool" --range "$base" 2>&1)"; assert_rc "range catches added ruby" 1 $?
assert_contains "range names file" "$out" "r.rb"
out="$(cd "$repo" && "$tool" --range HEAD 2>&1)"; assert_rc "empty range passes" 0 $?
out="$(cd "$repo" && "$tool" --bogus 2>&1)"; assert_rc "bad flag" 2 $?

finish
