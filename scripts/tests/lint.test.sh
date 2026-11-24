#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib.sh"
new_tmp

lint="$here/../lint/lint-explainer.sh"
cross="$here/../lint/check-1k-cross.sh"
verdict="$here/../lint/verdict-parse.sh"

good="$TMPROOT/good.html"
cat > "$good" <<'EOF'
<html><body>
<div id="before-list"></div><div id="after-list"></div>
<script>
const ITEMS = []; const FAIL_INDEX = 1;
function runAnimation() { document.getElementById('before-list').innerHTML = ''; document.getElementById("after-list"); }
</script>
</body></html>
EOF
out="$("$lint" "$good" 2>&1)"; assert_rc "good explainer passes" 0 $?

sed 's/<html>/<html>{{TITLE}}/' "$good" > "$TMPROOT/ph.html"
out="$("$lint" "$TMPROOT/ph.html" 2>&1)"; rc=$?
assert_rc "placeholder fails" 1 $rc
assert_contains "placeholder named" "$out" "{{TITLE}}"

sed 's/id="after-list"/id="after-lst"/' "$good" > "$TMPROOT/id.html"
out="$("$lint" "$TMPROOT/id.html" 2>&1)"; rc=$?
assert_rc "missing id fails" 1 $rc
assert_contains "missing id named" "$out" "after-list"

sed 's|</script>||' "$good" > "$TMPROOT/sc.html"
out="$("$lint" "$TMPROOT/sc.html" 2>&1)"; rc=$?
assert_rc "unbalanced script fails" 1 $rc
assert_contains "script reported" "$out" "unbalanced script tags"

printf '<html>{{NOT_AN_EXPLAINER}}</html>\n' > "$TMPROOT/other.html"
out="$("$lint" "$TMPROOT/other.html" 2>&1)"; assert_rc "non-explainer html ignored" 0 $?

hook() { printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$1" | "$lint" --hook 2>&1; }
out="$(hook "$TMPROOT/id.html")"; rc=$?
assert_rc "hook exits 2 on failure" 2 $rc
assert_contains "hook feedback on stderr text" "$out" "after-list"
out="$(hook "$good")"; assert_rc "hook ok on good file" 0 $?
out="$(hook "$TMPROOT/notes.txt")"; assert_rc "hook ignores non-html" 0 $?
out="$(hook "$TMPROOT/missing.html")"; assert_rc "hook ignores missing file" 0 $?
mkdir -p "$TMPROOT/templates"
cp "$TMPROOT/ph.html" "$TMPROOT/templates/t.html"
out="$(hook "$TMPROOT/templates/t.html")"; assert_rc "hook skips templates dir" 0 $?
out="$("$lint" 2>&1)"; assert_rc "usage" 2 $?

repo="$TMPROOT/repo"
new_repo "$repo"
git -C "$repo" checkout -q -b main
seq 1 999 > "$repo/small.txt"
seq 1 1005 > "$repo/big.txt"
seq 1 5 > "$repo/tiny.txt"
git -C "$repo" add -- .
git -C "$repo" commit -q -m base
git -C "$repo" checkout -q -b feature
seq 1 1001 > "$repo/small.txt"
seq 1 1100 > "$repo/big.txt"
seq 1 1500 > "$repo/new.txt"
seq 1 2000 > "$repo/pkg.lock"
seq 1 6 > "$repo/tiny.txt"
git -C "$repo" add -- .
git -C "$repo" commit -q -m change
out="$(cd "$repo" && "$cross" main 2>&1)"; rc=$?
assert_rc "crossing detected" 1 $rc
assert_contains "small crossed" "$out" "small.txt: 999 -> 1001"
assert_contains "new file counted" "$out" "new.txt: 0 -> 1500"
assert_not_contains "already-big file not flagged" "$out" "big.txt"
assert_not_contains "lock ignored" "$out" "pkg.lock"
assert_not_contains "tiny ignored" "$out" "tiny.txt"
out="$(cd "$repo" && "$cross" main --json)"
assert_eq "json count" 2 "$(printf '%s' "$out" | jq length)"
git -C "$repo" checkout -q main
out="$(cd "$repo" && "$cross" main 2>&1)"; assert_rc "no diff passes" 0 $?
git -C "$repo" checkout -q feature
seq 1 1050 > "$repo/tiny.txt"
out="$(cd "$repo" && "$cross" main --worktree 2>&1)"
assert_contains "worktree mode sees uncommitted" "$out" "tiny.txt: 5 -> 1050"
out="$(cd "$repo" && "$cross" no-such-ref 2>&1)"; assert_rc "bad base exits 3" 3 $?
out="$(cd "$repo" && "$cross" 2>&1)"; assert_rc "missing base exits 2" 2 $?

printf 'text\nVERDICT: PASS -- all good\n' > "$TMPROOT/v1"
out="$("$verdict" "$TMPROOT/v1")"; rc=$?
assert_rc "pass exits 0" 0 $rc
assert_eq "pass json" PASS "$(printf '%s' "$out" | jq -r .verdict)"
assert_eq "pass line number" 2 "$(printf '%s' "$out" | jq -r .line)"
printf 'VERDICT: FAIL\n' | "$verdict" - > "$TMPROOT/v2.out"; rc=$?
assert_rc "fail exits 1" 1 $rc
printf 'no verdict here\n' | "$verdict" - > "$TMPROOT/v3.out"; rc=$?
assert_rc "none exits 2" 2 $rc
assert_eq "none json" NONE "$(jq -r .verdict "$TMPROOT/v3.out")"
printf 'Reply with VERDICT: PASS|FAIL\nVERDICT: PASS -- ok\n**VERDICT: FAIL** -- later\n' | "$verdict" - > "$TMPROOT/v4.out"; rc=$?
assert_rc "last verdict wins, markdown tolerated" 1 $rc
printf 'VERDICT: FAIL -- but PASS appears in the text\n' | "$verdict" - > "$TMPROOT/v5.out"
assert_eq "word after verdict ignored" FAIL "$(jq -r .verdict "$TMPROOT/v5.out")"
printf 'VERDICT: PASSING\n' | "$verdict" - > /dev/null; assert_rc "partial word not a verdict" 2 $?
"$verdict" "$TMPROOT/missing" 2>/dev/null; assert_rc "missing file exits 2" 2 $?
finish
