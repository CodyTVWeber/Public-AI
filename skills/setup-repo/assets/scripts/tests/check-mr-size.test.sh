#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/../../../../../scripts/tests/lib.sh"
new_tmp

check="$here/../check-mr-size.sh"
repo="$TMPROOT/repo"
new_repo "$repo"
git -C "$repo" checkout -q -b main
printf 'base\n' > "$repo/base.txt"
git -C "$repo" add -- base.txt
git -C "$repo" commit -q -m base
git -C "$repo" checkout -q -b feature

add_file() {
  local path="$1" lines="$2"
  mkdir -p "$(dirname "$repo/$path")"
  seq 1 "$lines" > "$repo/$path"
  git -C "$repo" add -- "$path"
  git -C "$repo" commit -q -m "$path"
}

run_size() {
  (cd "$repo" && MR_BASE=main MR_SIZE_HARD=10 MR_SIZE_SOFT=5 "$check")
}

add_file docs/guide.md 40
add_file README.md 20
add_file .claude/settings.json 30
add_file .cursor/rules/style.mdc 15
add_file scripts/clean-code/check.sh 25
add_file scripts/lint/run-lint.sh 12
add_file scripts/guard/privacy.sh 12
add_file .githooks/pre-commit 8
add_file eslint.config.js 16
out="$(run_size)"; rc=$?
assert_rc "docs and supporting files do not hit the hard limit" 0 $rc
assert_contains "names the omitted lines" "$out" "hard limit counts 0 lines"
assert_contains "warning still counts them" "$out" "WARN:"
assert_not_contains "does not block" "$out" "BLOCKED:"

add_file src/app.ts 6
out="$(run_size)"; rc=$?
assert_rc "product lines under the hard limit pass" 0 $rc
assert_contains "hard count is the product lines" "$out" "hard limit counts 6 lines"
assert_not_contains "under the limit is not blocked" "$out" "BLOCKED:"

add_file src/more.ts 20
out="$(run_size)"; rc=$?
assert_rc "product lines over the hard limit block" 1 $rc
assert_contains "block names the hard limit" "$out" "BLOCKED:"
assert_contains "hard count includes only product lines" "$out" "hard limit counts 26 lines"

printf 'risk: low\n' > "$repo/.mr-size"
git -C "$repo" add -- .mr-size
git -C "$repo" commit -q -m risk
out="$(run_size)"; rc=$?
assert_rc "low-risk product overflow is advisory" 0 $rc
assert_contains "low-risk line" "$out" "low-risk repo (.mr-size): size is advisory"
rm -f "$repo/.mr-size"
git -C "$repo" add -- .mr-size
git -C "$repo" commit -q -m unrisk

git -C "$repo" mv docs/guide.md src/from-doc.ts
printf '%s\n' "$(seq 1 30)" > "$repo/src/from-doc.ts"
git -C "$repo" add -- src/from-doc.ts
git -C "$repo" commit -q -m rename
out="$(run_size)"; rc=$?
assert_rc "a doc renamed into product code counts" 1 $rc
assert_contains "renamed product file is in the hard count" "$out" "hard limit counts"

finish
