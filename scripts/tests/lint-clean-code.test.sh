#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib.sh"
new_tmp

lint="$here/../lint/lint-clean-code.sh"
repo="$TMPROOT/repo"
new_repo "$repo"
mkdir -p "$repo/src"
printf 'export const a = 1;\n' > "$repo/src/a.ts"
git -C "$repo" add -- .
git -C "$repo" commit -qm base

run() { (cd "$repo" && "$lint" HEAD 2>&1); }
reset() { git -C "$repo" reset -q; git -C "$repo" checkout -q -- .; git -C "$repo" clean -fdq; }

out="$(run)"; rc=$?
assert_rc "clean tree passes" 0 $rc
assert_eq "clean tree json" '{"errors":[],"warnings":[]}' "$out"

printf '// adds one\nexport const b = 2;\n' >> "$repo/src/a.ts"
out="$(run)"; rc=$?
assert_rc "slash comment fails" 1 $rc
assert_contains "comment rule" "$out" '"rule":"comment"'
assert_contains "comment file" "$out" '"file":"src/a.ts"'
reset

printf 'export const b = 2; // trailing\n' >> "$repo/src/a.ts"
out="$(run)"; assert_rc "trailing comment fails" 1 $?
reset

printf '#!/usr/bin/env bash\necho hi\n' > "$repo/src/run.sh"
out="$(run)"; assert_rc "shebang allowed" 0 $?
reset

printf 'echo hi\n# explains it\n' > "$repo/src/run.sh"
out="$(run)"; rc=$?
assert_rc "hash comment in untracked file fails" 1 $rc
assert_contains "untracked file named" "$out" "src/run.sh"
reset

printf '// SPDX-License-Identifier: MIT\nexport const b = 2;\n' >> "$repo/src/a.ts"
out="$(run)"; assert_rc "license line allowed" 0 $?
reset

printf 'try { x(); } catch (e) {}\n' >> "$repo/src/a.ts"
out="$(run)"; rc=$?
assert_rc "empty catch fails" 1 $rc
assert_contains "empty catch rule" "$out" '"rule":"empty_catch"'
reset

printf 'The cache previously held ten minutes.\n' > "$repo/note.md"
out="$(run)"; rc=$?
assert_rc "banner in current doc fails" 1 $rc
assert_contains "banner rule" "$out" '"rule":"banner"'
reset

mkdir -p "$repo/docs/log"
printf 'Date: 2026-01-05\n\nThe cache previously held ten minutes.\n' > "$repo/docs/log/2026-01-05-cache.md"
out="$(run)"; assert_rc "banner in dated doc allowed" 0 $?
reset

seq 1 250 | sed 's/^/export const v/; s/$/ = 1;/' > "$repo/src/big.ts"
out="$(run)"; rc=$?
assert_rc "oversized file only warns" 0 $rc
assert_contains "size warning" "$out" '"rule":"file-size"'
reset

seq 1 400 | sed 's/^/export const v/; s/$/ = 1;/' > "$repo/src/huge.ts"
out="$(run)"; rc=$?
assert_rc "file at the hard stop fails" 1 $rc
assert_contains "hard file size" "$out" '"rule":"file-size"'
reset

printf 'function helper() {\n  return 1;\n}\nexport function api() {\n  return helper();\n}\n' > "$repo/src/order.ts"
out="$(run)"; rc=$?
assert_rc "function order only warns" 0 $rc
assert_contains "function order" "$out" '"rule":"function-order"'
reset

mkdir -p "$repo/src/controllers"
printf 'export const c = 3;\n' > "$repo/src/controllers/c.ts"
out="$(run)"; rc=$?
assert_rc "layer folder only warns" 0 $rc
assert_contains "layer warning" "$out" "layer_folder"
reset

(cd "$repo" && "$lint" >/dev/null 2>&1); assert_rc "no base is usage error" 2 $?
(cd "$repo" && "$lint" no-such-ref >/dev/null 2>&1); assert_rc "bad base exits 3" 3 $?
(cd "$TMPROOT" && "$lint" HEAD >/dev/null 2>&1); assert_rc "outside repo exits 3" 3 $?

finish
