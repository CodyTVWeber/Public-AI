#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib.sh"
new_tmp
unset PRIVACY_REQUIRE_PATTERNS

script="$here/../check-privacy.sh"
repo="$TMPROOT/repo"
new_repo "$repo"
mkdir -p "$repo/scripts"
cp "$script" "$repo/scripts/check-privacy.sh"
: > "$repo/.privacyallow"
git -C "$repo" add -- .
git -C "$repo" commit -q -m init

ticket="AB""C-12"
p1=555
p2=010
p3=0199
phone="$p1-$p2-$p3"
mail="someone""@example.test"
noreply="noreply""@example.test"
homedir="/Us""ers/someone/x"
semver="1.2"".3"
tagpin="somedb:42"".0"
pobox="P.O. B""ox 1234"
street="123 Maple ""Street"
zip=", TX 7""5001"

run() { (cd "$repo" && scripts/check-privacy.sh "$@" 2>&1); }
stage() { printf '%s\n' "$2" > "$repo/$1"; git -C "$repo" add -- "$1"; }
reset() { git -C "$repo" reset -q; git -C "$repo" clean -fdq -- . ':!scripts' ':!.privacyallow'; : > "$repo/.privacyallow"; }

out="$(run)"; assert_rc "empty index passes" 0 $?

stage a.txt "plain generic text"
out="$(run)"; assert_rc "clean content passes" 0 $?
reset

stage a.txt "see $ticket for details"
out="$(run --content)"; rc=$?
assert_rc "ticket 2 digits blocked" 1 $rc
assert_contains "ticket reported with file and line" "$out" "a.txt:1"
reset
stage ac.txt "AC-1 holds, but $ticket still blocks"
out="$(run --content)"; assert_rc "AC id does not hide a ticket on the same line" 1 $?
reset
stage ac.txt "AC-1 the user sees the total"
out="$(run --content)"; assert_rc "acceptance-criteria id alone passes" 0 $?
reset

stage a.txt "see AB""C-7 for details"
out="$(run --content)"; assert_rc "ticket single digit blocked" 1 $?
reset

stage a.txt "uses SHA-256 and UTF-8 and ISO-8601 and ab-12 and px-4"
out="$(run --content)"; assert_rc "known tokens and lowercase pass" 0 $?
reset

stage a.txt "call $phone now"
out="$(run --content)"; assert_rc "phone blocked" 1 $?
assert_contains "phone label" "$out" "phone number"
reset

stage a.txt "write to $mail"
out="$(run --content)"; assert_contains "email label" "$out" "email address"
reset

stage a.txt "path $homedir"
out="$(run --content)"; assert_contains "home path label" "$out" "home directory path"
reset

stage a.txt "box $pobox"
out="$(run --content)"; assert_contains "po box label" "$out" "po box"
reset

stage a.txt "lives at $street"
out="$(run --content)"; assert_contains "street label" "$out" "street address"
reset

stage a.txt "Springfield$zip"
out="$(run --content)"; assert_contains "city state zip label" "$out" "city state zip"
reset

stage a.txt "pin $semver here"
out="$(run --content)"; assert_contains "semver label" "$out" "semver pin"
reset
mkdir -p "$repo/vendor"
printf 'version ^vendor/\n' > "$repo/.privacyexempt"
stage vendor/lock.txt "pin $semver here"
out="$(run --content)"; assert_rc "exempt path skips version checks" 0 $?
stage vendor/t.txt "see $ticket"
out="$(run --content)"; assert_rc "version exempt still blocks tickets" 1 $?
rm -f "$repo/.privacyexempt"
reset

stage a.txt "service uses $tagpin today"
out="$(run --content)"; assert_contains "image-tag style pin outside docker" "$out" "image-tag style pin"
reset

stage a.txt "ratio is 1.5 and time 12:30 and host:8080."
out="$(run --content)"; assert_rc "non-pin colon numbers pass" 0 $?
reset

printf '%s\n' "tagpin allowed: $tagpin" > "$repo/b.txt"
printf '%s\n' 'tagpin allowed' > "$repo/.privacyallow"
git -C "$repo" add -- b.txt
out="$(run --content)"; assert_rc ".privacyallow drops flagged line" 0 $?
reset

mkdir -p "$repo/dir with space"
stage "dir with space/file name.txt" "call $phone"
out="$(run --content)"; rc=$?
assert_rc "spaces in path scanned" 1 $rc
assert_contains "spaces in path reported" "$out" "dir with space/file name.txt:1"
reset

stage "ok name.txt" "fine"
out="$(run --paths)"; assert_rc "paths: clean name with space passes" 0 $?
reset

stage "$ticket-notes.txt" "fine"
out="$(run --paths)"; rc=$?
assert_rc "paths: ticket in name blocked" 1 $rc
assert_contains "paths: reports name" "$out" "$ticket-notes.txt"
out="$(run --content)"; assert_rc "content mode ignores names" 0 $?
reset

msg="$TMPROOT/msg"
printf 'fix: tidy parser\n\n# a comment line with %s\nbody line\n' "$ticket" > "$msg"
out="$(run --message "$msg")"; assert_rc "message: comment lines ignored" 0 $?
printf 'fix: tidy parser for %s\n' "$ticket" > "$msg"
out="$(run --message "$msg")"; rc=$?
assert_rc "message: ticket blocked" 1 $rc
assert_contains "message: location" "$out" "message:1"
printf 'fix: tidy\n\nCo-Authored-By: Helper <%s>\n' "$noreply" > "$msg"
out="$(run --message "$msg")"; assert_rc "message: trailer email tolerated" 0 $?
printf 'fix: mail %s\n' "$mail" > "$msg"
out="$(run --message "$msg")"; assert_rc "message: body email blocked" 1 $?
out="$(run --message "$TMPROOT/missing")"; assert_rc "message: missing file" 3 $?

out="$(run --bogus)"; assert_rc "bad flag" 2 $?
out="$(cd "$TMPROOT" && "$script" 2>&1)"; assert_rc "outside repo" 3 $?

stage a.txt "works at acme""corp"
out="$(run --content)"; assert_rc "employer check off by default" 0 $?
out="$(cd "$repo" && PRIVACY_EMPLOYER_PATTERN='acmecorp' scripts/check-privacy.sh --content 2>&1)"; rc=$?
assert_rc "employer pattern via env" 1 $rc
assert_contains "employer label" "$out" "employer name"
reset

pfile="$repo/.git/info/privacy-patterns"
mkdir -p "$repo/.git/info"
stage a.txt "plain text"
out="$(run --content)"; assert_contains "missing patterns file warns" "$out" "no local patterns file"
assert_rc "missing patterns file does not block" 0 $?
reset

printf '# nomatchword\n\n   \nzorb''co[a-z]*\n' > "$pfile"
stage a.txt "plain text and nomatchword"
out="$(run --content)"; rc=$?
assert_rc "patterns file: comment and blank lines are not patterns" 0 $rc
assert_not_contains "patterns file present: no warning" "$out" "no local patterns file"
reset
stage a.txt "joined zorb""cocorp today"
out="$(run --content)"; rc=$?
assert_rc "local pattern blocks content" 1 $rc
assert_contains "local pattern label" "$out" "local pattern"
reset
stage "zorb""co-notes.txt" "fine"
out="$(run --paths)"; assert_rc "local pattern blocks file names" 1 $?
reset
printf 'fix: tidy zorb''cocorp parser\n' > "$msg"
out="$(run --message "$msg")"; assert_rc "local pattern blocks messages" 1 $?

printf '(\n' > "$pfile"
stage a.txt "plain text"
out="$(run --content)"; rc=$?
assert_rc "invalid pattern blocks" 1 $rc
assert_contains "invalid pattern named" "$out" "invalid regex"
reset

rm -f "$pfile"
stage a.txt "plain text"
out="$(run --strict --content)"; rc=$?
assert_rc "strict: missing patterns file blocks" 1 $rc
assert_contains "strict: names the file" "$out" "info/privacy-patterns"
out="$(cd "$repo" && PRIVACY_REQUIRE_PATTERNS=1 scripts/check-privacy.sh --content 2>&1)"; assert_rc "env: missing patterns file blocks" 1 $?
out="$(cd "$repo" && PRIVACY_REQUIRE_PATTERNS=1 scripts/check-privacy.sh --message "$msg" 2>&1)"; assert_rc "env: message mode blocks too" 1 $?
printf 'zorb''co[a-z]*\n' > "$pfile"
out="$(cd "$repo" && PRIVACY_REQUIRE_PATTERNS=1 scripts/check-privacy.sh --content 2>&1)"; assert_rc "env: file present passes" 0 $?
out="$(run --strict --content)"; assert_rc "strict: file present passes" 0 $?
rm -f "$pfile"
reset

stage a.txt "uses actions/checkout@v""9 here"
out="$(run --content)"; assert_contains "action pin label" "$out" "action version pin"
reset
stage a.txt "model zeta-7"".3 here"
out="$(run --content)"; assert_contains "model token label" "$out" "model version token"
reset
stage a.txt "see zeta-7 and SHA-256 and PDF-1.4 and ab-cd"
out="$(run --content)"; assert_rc "model token ignores non-versions and standards" 0 $?
reset

finish
