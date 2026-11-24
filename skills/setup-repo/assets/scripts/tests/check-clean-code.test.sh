#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/../../../../../scripts/tests/lib.sh"
new_tmp

checker="$here/../check-clean-code.sh"
repo="$TMPROOT/repo"
new_repo "$repo"
mkdir -p "$repo/src" "$repo/src/test" "$repo/src/generated"
for f in src/latest.ts src/app.ts src/app.test.ts src/test/helper.ts src/generated/api.ts src/AppTest.kt; do
  seq 1 450 | sed 's/^/export const v/; s/$/ = 1;/' > "$repo/$f"
done
git -C "$repo" add -- .
git -C "$repo" commit -q -m base

for f in src/latest.ts src/app.test.ts src/test/helper.ts src/generated/api.ts src/AppTest.kt; do
  printf 'export const extra = 2;\n' >> "$repo/$f"
done
git -C "$repo" add -- .

out="$(cd "$repo" && "$checker" 2>&1)"; rc=$?
assert_rc "growing a large source file named latest blocks" 1 $rc
assert_contains "latest.ts checked" "$out" "src/latest.ts"
assert_not_contains "test suffix skipped" "$out" "app.test.ts"
assert_not_contains "test dir skipped" "$out" "test/helper.ts"
assert_not_contains "generated dir skipped" "$out" "generated/api.ts"
assert_not_contains "Test suffix skipped" "$out" "AppTest.kt"

out="$(cd "$repo" && CLEAN_CODE_SKIP=1 "$checker" 2>&1)"; assert_rc "skip env honoured" 0 $?

git -C "$repo" reset -q
git -C "$repo" checkout -q -- .
c="$TMPROOT/comments"
new_repo "$c"
mkdir -p "$c/src"
printf 'export const a = 1;\n' > "$c/src/a.ts"
printf 'export const t = 1;\n' > "$c/src/a.test.ts"
git -C "$c" add -- .
git -C "$c" commit -q -m base
check() { (cd "$c" && git add -- . && "$checker" 2>&1); }

printf '// quirk: the clock can step backward\nexport const b = 2;\n' >> "$c/src/a.ts"
out="$(check)"; rc=$?
assert_rc "quirk comment is blocked" 1 $rc
assert_contains "quirk reported" "$out" "ban comments"
git -C "$c" reset -q; git -C "$c" checkout -q -- .

printf '// security: compare in constant time\nexport const b = 2;\n' >> "$c/src/a.ts"
out="$(check)"; assert_rc "security comment is blocked" 1 $?
git -C "$c" reset -q; git -C "$c" checkout -q -- .

printf '// does a thing\nexport const b = 2;\n' >> "$c/src/a.test.ts"
out="$(check)"; rc=$?
assert_rc "comment in a test file is blocked" 1 $rc
assert_contains "test file named" "$out" "a.test.ts"
git -C "$c" reset -q; git -C "$c" checkout -q -- .

printf '// eslint-disable-next-line no-empty -- empty probe is the signal\nexport const b = 2;\n' >> "$c/src/a.ts"
out="$(check)"; assert_rc "directive with reason allowed" 0 $?
git -C "$c" reset -q; git -C "$c" checkout -q -- .

printf '// SPDX-License-Identifier: MIT\nexport const b = 2;\n' >> "$c/src/a.ts"
out="$(check)"; assert_rc "license line allowed" 0 $?
git -C "$c" reset -q; git -C "$c" checkout -q -- .

printf '// eslint-disable-next-line no-empty\nexport const b = 2;\n' >> "$c/src/a.ts"
out="$(check)"; assert_rc "bare directive blocked" 1 $?
git -C "$c" reset -q; git -C "$c" checkout -q -- .

printf 'export function build(a, b, c, d) {\n  return a;\n}\n' > "$c/src/wide.ts"
out="$(check)"; rc=$?
assert_rc "analyzer blocks four params at pre-commit" 1 $rc
assert_contains "analyzer finding shown" "$out" "param-count"
git -C "$c" reset -q; rm -f "$c/src/wide.ts"

printf 'export const b = 2; // quirk\n' >> "$c/src/a.ts"
out="$(check)"; rc=$?
assert_rc "comment still blocked" 1 $rc
assert_eq "comment reported once, by the legacy check" "1" "$(printf '%s\n' "$out" | grep -c 'quirk\|ban comments')"
assert_not_contains "analyzer skips the legacy comment rule for ts" "$out" "added-comment"
git -C "$c" reset -q; git -C "$c" checkout -q -- .

printf '#!/usr/bin/env bash\n# explains\necho ok\n' > "$c/run.sh"
out="$(check)"; rc=$?
assert_rc "analyzer covers shell comments the legacy check ignores" 1 $rc
assert_contains "shell comment reported" "$out" "added-comment"
git -C "$c" reset -q; rm -f "$c/run.sh"

printf 'export const b = 2;\n' >> "$c/src/a.ts"
out="$(check)"; assert_rc "clean staged change passes with analyzer" 0 $?
git -C "$c" reset -q; git -C "$c" checkout -q -- .

standalone="$TMPROOT/standalone"
new_repo "$standalone"
cp "$checker" "$standalone/check-clean-code.sh"
printf 'export function build(a, b, c, d) {\n  return a;\n}\n' > "$standalone/w.ts"
git -C "$standalone" add -- .
out="$(cd "$standalone" && ./check-clean-code.sh 2>&1)"; assert_rc "without the analyzer only legacy checks run" 0 $?
finish
