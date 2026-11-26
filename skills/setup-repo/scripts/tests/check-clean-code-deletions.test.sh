#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/fixtures.sh"
new_tmp

script="$here/../../assets/scripts/check-clean-code.sh"
repo="$TMPROOT/repo"
mkdir -p "$repo"
git -C "$repo" init -q -b main
git -C "$repo" config user.name t
git -C "$repo" config user.email t.example
printf 'a = 1\n' > "$repo/a.py"
git -C "$repo" add -- .
git -C "$repo" commit -q -m init

git -C "$repo" rm -q -- a.py
(cd "$repo" && bash "$script" >/dev/null 2>&1); assert_rc "deletion-only staged set passes" 0 $?

printf 'x = 1\n' > "$repo/b.py"
git -C "$repo" add -- b.py
(cd "$repo" && bash "$script" >/dev/null 2>&1); assert_rc "clean added file passes" 0 $?
finish
