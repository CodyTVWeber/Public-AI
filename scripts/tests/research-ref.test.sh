#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib.sh"
new_tmp

tool="$here/../guard/research-ref.sh"
origin="$TMPROOT/origin.git"
work="$TMPROOT/work"
clone="$TMPROOT/clone"

git init -q --bare -b main "$origin"
new_repo "$work"
git -C "$work" checkout -q -b main
printf 'one\n' > "$work/f.txt"
git -C "$work" add -- f.txt
git -C "$work" commit -q -m first
git -C "$work" remote add origin "$origin"
git -C "$work" push -q origin main
git clone -q "$origin" "$clone"

out="$("$tool" "$clone")"; rc=$?
assert_rc "up to date exits 0" 0 $rc
assert_eq "ref" "origin/main" "$(printf '%s' "$out" | jq -r .ref)"
assert_eq "behind 0" "0" "$(printf '%s' "$out" | jq -r .behind)"
assert_eq "fetched" "true" "$(printf '%s' "$out" | jq -r .fetched)"

printf 'two\n' >> "$work/f.txt"
git -C "$work" commit -q -am second
git -C "$work" push -q origin main

out="$("$tool" "$clone")"; rc=$?
assert_rc "behind still exits 0" 0 $rc
assert_eq "behind 1" "1" "$(printf '%s' "$out" | jq -r .behind)"
want="$(git -C "$work" rev-parse HEAD)"
assert_eq "sha is remote head" "$want" "$(printf '%s' "$out" | jq -r .sha)"

printf 'local\n' > "$clone/g.txt"
git -C "$clone" config user.name tester
git -C "$clone" config user.email tester.example
git -C "$clone" add -- g.txt
git -C "$clone" commit -q -m local
out="$("$tool" "$clone")"
assert_eq "ahead 1" "1" "$(printf '%s' "$out" | jq -r .ahead)"

out="$(printf '{"cwd":"%s"}' "$clone" | "$tool" --hook)"; rc=$?
assert_rc "hook exits 0" 0 $rc
ctx="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext')"
assert_contains "hook context names ref" "$ctx" "origin/main @ ${want:0:9}"
assert_contains "hook context behind" "$ctx" "behind 1"
assert_contains "hook context rule" "$ctx" "rules/research-latest-main.md"
assert_eq "hook event" "SessionStart" "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName')"

git -C "$clone" merge -q --no-edit origin/main
out="$(printf '{"cwd":"%s"}' "$clone" | "$tool" --hook)"
assert_eq "hook silent when not behind" "" "$out"

mv "$origin" "$origin.gone"
out="$("$tool" "$clone" 2>/dev/null)"; rc=$?
assert_rc "fetch failure exits 3" 3 $rc
assert_eq "fetched false" "false" "$(printf '%s' "$out" | jq -r .fetched)"
out="$(printf '{"cwd":"%s"}' "$clone" | "$tool" --hook 2>/dev/null)"; assert_rc "hook fails open" 0 $?
mv "$origin.gone" "$origin"

lone="$TMPROOT/lone"
new_repo "$lone"
out="$("$tool" "$lone" 2>&1)"; assert_rc "no origin exits 3" 3 $?
out="$("$tool" "$TMPROOT" 2>&1)"; assert_rc "not a repo exits 3" 3 $?
out="$(printf '{"cwd":"%s"}' "$TMPROOT" | "$tool" --hook 2>/dev/null)"; assert_rc "hook outside repo exits 0" 0 $?
out="$("$tool" --bogus 2>&1)"; assert_rc "bad flag" 2 $?
finish
