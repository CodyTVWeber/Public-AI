#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib.sh"
new_tmp
unset PRIVACY_REQUIRE_PATTERNS

repo="$TMPROOT/repo"
new_repo "$repo"
mkdir -p "$repo/scripts"
cp "$here/../check-privacy.sh" "$repo/scripts/check-privacy.sh"
: > "$repo/.privacyallow"
git -C "$repo" add -- .
git -C "$repo" commit -q -m init
git -C "$repo" branch -M main

ticket="AB""C-12"
run() { (cd "$repo" && scripts/check-privacy.sh "$@" 2>&1); }
commit_file() {
  printf '%s\n' "$2" > "$repo/$1"
  git -C "$repo" add -- "$1"
  git -C "$repo" commit -q -m "${COMMIT_MSG:-add $1}"
}

commit_file a.txt "see $ticket"
out="$(run --range HEAD~1..HEAD)"; rc=$?
assert_rc "range: bad added line blocked" 1 $rc
assert_contains "range: location" "$out" "a.txt:1"
git -C "$repo" rm -q a.txt
git -C "$repo" commit -q -m "drop a"
out="$(run --range HEAD~2..HEAD)"; assert_rc "range: content removed later still blocked" 1 $?
out="$(run --range HEAD~1..HEAD)"; assert_rc "range: clean tail passes" 0 $?

COMMIT_MSG="mention $ticket" commit_file b.txt "fine"
out="$(run --range HEAD~1..HEAD)"; rc=$?
assert_rc "range: bad commit message blocked" 1 $rc
assert_contains "range: message location" "$out" "commit "
commit_file "$ticket-name.txt" "fine"
out="$(run --range HEAD~1..HEAD)"; rc=$?
assert_rc "range: bad file name blocked" 1 $rc
assert_contains "range: file name reported" "$out" "$ticket-name.txt"
out="$(run --range nope..HEAD)"; assert_rc "range: bad range" 3 $?
out="$(run --range)"; assert_rc "range: value required" 2 $?

commit_file c.txt "clean"
out="$(run --range auto)"; assert_rc "auto without remote scans the last commit only" 0 $?
git init -q --bare "$TMPROOT/origin.git"
git -C "$repo" remote add origin "$TMPROOT/origin.git"
git -C "$repo" push -q -u origin main 2>/dev/null
commit_file d.txt "see $ticket"
out="$(run --range auto)"; rc=$?
assert_rc "auto with upstream scans the unpushed commit" 1 $rc
assert_contains "auto: location" "$out" "d.txt:1"
git -C "$repo" branch -q --unset-upstream
out="$(run --range auto)"; assert_rc "auto falls back to origin/default" 1 $?
commit_file e.txt "clean"
out="$(run --range auto)"; assert_rc "auto: older unpushed bad commit still scanned" 1 $?

empty="$TMPROOT/empty"
new_repo "$empty"
cp "$here/../check-privacy.sh" "$empty/check-privacy.sh"
out="$(cd "$empty" && ./check-privacy.sh --range auto 2>&1)"; assert_rc "auto with no commits passes" 0 $?

git -C "$repo" reset -q --hard HEAD
printf '\x89PNG\0\0\0' > "$repo/pic.png"
printf 'text only\n' > "$repo/notes.PDF"
printf 'a\0b\n' > "$repo/blob.dat"
printf 'plain\n' > "$repo/plain.txt"
git -C "$repo" add -- pic.png notes.PDF blob.dat plain.txt
out="$(run)"; rc=$?
assert_rc "staged binaries blocked" 1 $rc
assert_contains "binary label" "$out" "binary file"
assert_contains "extension match" "$out" "pic.png"
assert_contains "extension match is case-insensitive" "$out" "notes.PDF"
assert_contains "numstat binary without known extension" "$out" "blob.dat"
assert_not_contains "text file not reported" "$out" "plain.txt"
out="$(run --content)"; assert_rc "content mode skips binaries" 0 $?
printf '# reviewed\npic.png\nnotes.PDF\nblob.dat\n' > "$repo/.privacyallow-binaries"
out="$(run)"; assert_rc ".privacyallow-binaries lists reviewed paths" 0 $?
git -C "$repo" commit -q -m "add binaries"
rm -f "$repo/.privacyallow-binaries"
out="$(run --range HEAD~1..HEAD)"; rc=$?
assert_rc "range: binaries blocked" 1 $rc
assert_contains "range: binary reported" "$out" "pic.png"

finish
