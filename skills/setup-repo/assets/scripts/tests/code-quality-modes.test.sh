#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/cc-lib.sh"
new_tmp

repo="$TMPROOT/repo"
new_repo "$repo"
cat > "$repo/legacy.py" <<'FIX'
# old note
def legacy(a, b, c, d, e):
    return 4242
FIX
git -C "$repo" add -- .
git -C "$repo" commit -qm base

run() { (cd "$repo" && "$CQ" "$@" 2>/dev/null); }
count() { jq '.findings | length' <<<"$1"; }
rules() { jq -r '[.findings[].rule] | unique | join(" ")' <<<"$1"; }

out="$(run --changed)"; rc=$?
assert_rc "untouched legacy debt is silent" 0 $rc
assert_eq "no findings for untouched file" "0" "$(count "$out")"

printf '\n\ndef fresh(x):\n    return x\n' >> "$repo/legacy.py"
out="$(run --changed)"; assert_rc "appended clean function passes" 0 $?
assert_eq "legacy findings stay silent" "0" "$(count "$out")"

printf '\n\ndef newer(x):\n    # note\n    return x\n' >> "$repo/legacy.py"
out="$(run --changed)"; rc=$?
assert_rc "added comment in changed lines fails" 1 $rc
assert_eq "only the added comment is reported" "added-comment" "$(rules "$out")"
assert_eq "finding line points at the comment" "11" "$(jq '.findings[0].line' <<<"$out")"
assert_eq "finding carries a fix hint" "true" "$(jq '.findings[0].fix_hint | length > 0' <<<"$out")"

git -C "$repo" checkout -q -- legacy.py
sed -i.bak 's/4242/4243/' "$repo/legacy.py"; rm -f "$repo/legacy.py.bak"
out="$(run --changed)"; rc=$?
assert_rc "touching a legacy function reports it" 1 $rc
assert_contains "legacy function now reported" "$(rules "$out")" "param-count"
assert_not_contains "untouched comment line stays silent" "$(rules "$out")" "added-comment"
git -C "$repo" checkout -q -- legacy.py

printf 'export function build(a, b, c, d) {\n  return a;\n}\n' > "$repo/fresh.ts"
out="$(run --changed)"; rc=$?
assert_rc "untracked file is checked whole" 1 $rc
assert_contains "untracked file named" "$out" "fresh.ts"
rm "$repo/fresh.ts"

printf 'export const a = 1;\n// staged note\n' > "$repo/staged.ts"
git -C "$repo" add -- staged.ts
printf 'export const a = 1;\n' > "$repo/staged.ts"
out="$(run --staged)"; rc=$?
assert_rc "staged mode reads the index, not the worktree" 1 $rc
assert_contains "staged finding" "$out" "added-comment"
git -C "$repo" reset -q; rm -f "$repo/staged.ts"

out="$(run --staged)"; assert_rc "nothing staged is clean" 0 $?

seq 1 30 | sed 's/^/export const v/; s/$/ = 1;/' > "$repo/big.ts"
git -C "$repo" add -- big.ts
out="$(cd "$repo" && CC_FILE_WARN=10 CC_FILE_ERROR=20 "$CQ" --staged 2>/dev/null)"; rc=$?
assert_rc "new file past CC_FILE_ERROR fails" 1 $rc
assert_eq "file size rule" "file-size" "$(rules "$out")"
git -C "$repo" commit -qm big
printf 'export const extra = 1;\n' >> "$repo/big.ts"
out="$(cd "$repo" && CC_FILE_ERROR=20 "$CQ" --changed 2>/dev/null)"; assert_rc "growing a big file fails" 1 $?
printf 'x\n' > /dev/null
head -n 29 "$repo/big.ts" > "$repo/big.tmp"; mv "$repo/big.tmp" "$repo/big.ts"
out="$(cd "$repo" && CC_FILE_ERROR=20 "$CQ" --changed 2>/dev/null)"; assert_rc "shrinking a big file passes" 0 $?
git -C "$repo" checkout -q -- big.ts

printf 'export function f(a, b, c) {\n  return a;\n}\n' > "$repo/t.ts"
out="$(cd "$repo" && "$CQ" --changed 2>/dev/null)"
assert_eq "three params default warns" "warn" "$(jq -r '.findings[0].severity' <<<"$out")"
out="$(cd "$repo" && CC_PARAMS_ERROR=3 "$CQ" --changed 2>/dev/null)"; rc=$?
assert_rc "CC_PARAMS_ERROR=3 makes three an error" 1 $rc
out="$(cd "$repo" && CC_DISABLE=param-count "$CQ" --changed 2>/dev/null)"
assert_eq "CC_DISABLE drops the rule" "0" "$(count "$out")"
printf 'export function f(a, b, c) {\n  return a; // x\n}\n' > "$repo/t.ts"
out="$(cd "$repo" && CC_DISABLE='added-comment@ts' "$CQ" --changed 2>/dev/null)"
assert_not_contains "scoped disable drops ts comments" "$out" "added-comment"
out="$(cd "$repo" && CC_DISABLE='added-comment@py' "$CQ" --changed 2>/dev/null)"
assert_contains "scoped disable keeps other extensions" "$out" "added-comment"

out="$(cd "$repo" && CC_SKIP=1 "$CQ" --changed 2>&1)"; rc=$?
assert_rc "CC_SKIP skips" 0 $rc
assert_contains "skip is announced" "$out" "skipped (CC_SKIP=1)"
out="$(cd "$repo" && CLEAN_CODE_SKIP=1 "$CQ" --changed 2>&1)"; rc=$?
assert_rc "CLEAN_CODE_SKIP skips" 0 $rc
assert_contains "skip is announced" "$out" "skipped (CLEAN_CODE_SKIP=1)"
assert_eq "skip JSON flags it" "true" "$(cd "$repo" && CC_SKIP=1 "$CQ" --changed 2>/dev/null | jq '.summary.skipped')"

(cd "$repo" && git add -- . >/dev/null; git commit -qm more)
out="$(cd "$repo" && "$CQ" --changed HEAD~1 2>/dev/null)"; rc=$?
assert_rc "--changed BASE compares against BASE" 1 $rc
assert_contains "BASE diff names the file" "$out" "t.ts"

"$CQ" >/dev/null 2>&1; assert_rc "no mode is a usage error" 2 $?
"$CQ" --bogus >/dev/null 2>&1; assert_rc "unknown flag is a usage error" 2 $?
(cd "$TMPROOT" && "$CQ" --staged >/dev/null 2>&1); assert_rc "outside a repo is a precondition error" 3 $?
(cd "$repo" && "$CQ" --changed no-such-ref >/dev/null 2>&1); assert_rc "bad BASE is a precondition error" 3 $?

assert_eq "list-rules is JSON with every rule" "15" "$("$CQ" --list-rules | jq 'length')"
assert_contains "help documents modes" "$("$CQ" -h)" "--stop-hook"
assert_contains "help documents range mode" "$("$CQ" -h)" "--range BASE..HEAD"
assert_contains "help documents thresholds" "$("$CQ" -h)" "CC_NEST_ERROR"

rng="$TMPROOT/range"
make_repo "$rng"
printf 'export const kept = 1;\n// legacy note\n' > "$rng/legacy.ts"
git -C "$rng" add -- legacy.ts
git -C "$rng" commit -qm legacy
printf 'export const kept = 1;\n// legacy note\nexport const added = 2;\n' > "$rng/legacy.ts"
printf 'export const fresh = 1;\n// committed note\n' > "$rng/fresh.ts"
git -C "$rng" add -- .
git -C "$rng" commit -qm change
printf 'export const dirty = 1;\n// dirty note\n' > "$rng/dirty.ts"
printf 'export const base = 1;\n// uncommitted note\n' > "$rng/base.ts"
runr() { (cd "$rng" && "$CQ" "$@" 2>/dev/null); }
out="$(runr --range HEAD~1..HEAD)"; rc=$?
assert_rc "--range reports committed errors" 1 $rc
assert_contains "--range names the committed file" "$out" "fresh.ts"
assert_not_contains "--range ignores untracked files" "$out" "dirty.ts"
assert_not_contains "--range ignores working-tree edits" "$out" "base.ts"
assert_not_contains "--range keeps untouched legacy lines silent" "$out" "legacy.ts"
assert_eq "--range reads the committed text" "2" "$(jq '.findings[0].line' <<<"$out")"
git -C "$rng" rm -q --cached -- fresh.ts
printf 'export const fresh = 1;\n' > "$rng/fresh.ts"
out="$(runr --range HEAD~1..HEAD)"; assert_rc "--range ignores the index and worktree" 1 $?
git -C "$rng" reset -q --hard HEAD
out="$(runr --range HEAD..HEAD)"; assert_rc "empty range is clean" 0 $?
out="$(runr --range 4b825dc642cb6eb9a060e54bf8d69288fbee4904..HEAD)"; assert_rc "--range accepts the empty tree as a base" 1 $?
out="$(runr --range HEAD~1...HEAD)"; assert_rc "three-dot range diffs from the merge base" 1 $?
runr --range no-such-ref..HEAD >/dev/null; assert_rc "--range unknown base is a precondition error" 3 $?
runr --range HEAD >/dev/null; assert_rc "--range without dots is a precondition error" 3 $?
(cd "$TMPROOT" && "$CQ" --range HEAD~1..HEAD >/dev/null 2>&1); assert_rc "--range outside a repo is a precondition error" 3 $?

empty="$TMPROOT/empty"
new_repo "$empty"
printf 'export function g(a, b, c, d) {\n  return a;\n}\n' > "$empty/g.ts"
git -C "$empty" add -- g.ts
(cd "$empty" && "$CQ" --staged >/dev/null 2>&1); assert_rc "unborn HEAD staged check works" 1 $?
finish
