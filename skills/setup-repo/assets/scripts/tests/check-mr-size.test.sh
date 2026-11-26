#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/../../../../../scripts/tests/lib.sh"
new_tmp

check="$here/../check-mr-size.sh"
app_check="$here/../check-mr-size-app.sh"
support_check="$here/../check-mr-size-support.sh"
docs_check="$here/../check-mr-size-docs.sh"
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
  (cd "$repo" && MR_BASE=main MR_SIZE_HARD=10 MR_SIZE_SOFT=5 "$@")
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
out="$(run_size "$check")"; rc=$?
assert_rc "docs and support stay under their own budgets" 0 $rc
assert_contains "docs counted on their own" "$out" "mr-size docs: 60 changed lines"
assert_contains "support counted on its own" "$out" "mr-size support: 118 changed lines"
assert_contains "app total excludes docs and support" "$out" "mr-size app: 0 changed lines"
assert_not_contains "app hard limit does not fire" "$out" "BLOCKED app:"

add_file src/app.ts 6
out="$(run_size "$check")"; rc=$?
assert_rc "app lines under the hard limit pass" 0 $rc
assert_contains "app warning uses the app soft limit" "$out" "WARN app:"
assert_contains "app total is the product file" "$out" "mr-size app: 6 changed lines"

add_file src/more.ts 20
out="$(run_size "$check")"; rc=$?
assert_rc "app lines over the hard limit block" 1 $rc
assert_contains "block names the app bucket" "$out" "BLOCKED app:"
assert_contains "app total is only product lines" "$out" "mr-size app: 26 changed lines"
out="$(run_size "$support_check")"; rc=$?
assert_rc "support check ignores the app overflow" 0 $rc
out="$(run_size "$docs_check")"; rc=$?
assert_rc "docs check ignores the app overflow" 0 $rc

out="$(cd "$repo" && MR_BASE=main MR_SIZE_SUPPORT_HARD=10 "$support_check")"; rc=$?
assert_rc "support check blocks on the support limit" 1 $rc
assert_contains "support block names the bucket" "$out" "BLOCKED support:"
out="$(cd "$repo" && MR_BASE=main MR_SIZE_DOCS_HARD=10 "$docs_check")"; rc=$?
assert_rc "docs check blocks on the docs limit" 1 $rc
assert_contains "docs block names the bucket" "$out" "BLOCKED docs:"
out="$(run_size "$app_check")"; rc=$?
assert_rc "app check blocks on its own" 1 $rc

printf 'risk: low\n' > "$repo/.mr-size"
git -C "$repo" add -- .mr-size
git -C "$repo" commit -q -m risk
out="$(run_size "$check")"; rc=$?
assert_rc "low-risk app overflow is advisory" 0 $rc
assert_contains "low-risk line" "$out" "low-risk repo (.mr-size): size is advisory"
rm -f "$repo/.mr-size"
git -C "$repo" add -- .mr-size
git -C "$repo" commit -q -m unrisk

git -C "$repo" mv docs/guide.md src/from-doc.ts
printf '%s\n' "$(seq 1 30)" > "$repo/src/from-doc.ts"
git -C "$repo" add -- src/from-doc.ts
git -C "$repo" commit -q -m rename
out="$(run_size "$check")"; rc=$?
assert_rc "a doc renamed into product code counts as app" 1 $rc
assert_contains "renamed file is in the app total" "$out" "BLOCKED app:"

add_file src/hooks/useThing.ts 9
add_file src/rules/price.ts 4
out="$(run_size "$check")"; rc=$?
assert_rc "nested app hooks and rules still block as app" 1 $rc
assert_contains "app code under hooks/ stays on the app budget" "$out" "mr-size app: 69 changed lines"
assert_contains "support total ignores nested app dirs" "$out" "mr-size support: 118 changed lines"

finish
