#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib.sh"
new_tmp

lint="$here/../lint/lint-docs.sh"
repo="$TMPROOT/repo"
new_repo "$repo"
mkdir -p "$repo/docs/log"
printf 'The cache holds sessions for an hour.\n' > "$repo/docs/cache.md"
printf 'Date: 2026-01-05\n\nAs of 2026-01-05 the cache holds sessions for ten minutes.\n' > "$repo/docs/log/2026-01-05-cache-ttl.md"
git -C "$repo" add -A
git -C "$repo" commit -qm base

run() { (cd "$repo" && "$lint" "$@" 2>&1); }

out="$(run)"; rc=$?
assert_rc "clean tree passes" 0 $rc
assert_eq "clean tree json" '{"violations":[]}' "$out"

printf 'The cache holds sessions for an hour.\nThe cache previously held them for ten minutes.\n' > "$repo/docs/cache.md"
out="$(run)"; rc=$?
assert_rc "time-relative added line fails" 1 $rc
assert_contains "term file reported" "$out" '"file":"docs/cache.md"'
assert_contains "rule named" "$out" "current-doc-time-relative"
assert_contains "line number" "$out" '"line":2'

printf 'The cache holds sessions for an hour.\nThe cache keeps sessions in memory.\n' > "$repo/docs/cache.md"
out="$(run)"; assert_rc "present-tense edit passes" 0 $?

git -C "$repo" checkout -q -- docs/cache.md
printf 'Sessions expire after an hour. Use the helper that is no longer needed.\n' > "$repo/docs/new.md"
out="$(run)"; rc=$?
assert_rc "untracked current doc scanned" 1 $rc
assert_contains "untracked reported" "$out" "docs/new.md"
rm "$repo/docs/new.md"

printf 'Date: 2026-01-05\n\nAs of 2026-01-05 the cache holds sessions for twenty minutes.\n' > "$repo/docs/log/2026-01-05-cache-ttl.md"
out="$(run)"; rc=$?
assert_rc "dated doc edit fails" 1 $rc
assert_contains "dated edit named" "$out" "dated-doc-edited"

git -C "$repo" checkout -q -- docs/log/2026-01-05-cache-ttl.md
printf 'Date: 2026-01-05\n\nAs of 2026-01-05 the cache holds sessions for ten minutes.\n\n' > "$repo/docs/log/2026-01-05-cache-ttl.md"
out="$(run)"; assert_rc "whitespace-only dated edit passes" 0 $?

git -C "$repo" checkout -q -- docs/log/2026-01-05-cache-ttl.md
rm "$repo/docs/log/2026-01-05-cache-ttl.md"
out="$(run)"; rc=$?
assert_rc "dated doc delete fails" 1 $rc
assert_contains "dated delete named" "$out" "dated-doc-deleted"
git -C "$repo" checkout -q -- docs/log/2026-01-05-cache-ttl.md

printf 'Date: 2026-02-01\n\nAs of 2026-02-01 sessions last twenty minutes. Supersedes: docs/log/2026-01-05-cache-ttl.md\n' > "$repo/docs/log/2026-02-01-cache-ttl.md"
out="$(run)"; assert_rc "new dated doc with header passes" 0 $?

printf 'As of 2026-02-01 sessions last twenty minutes.\n' > "$repo/docs/log/2026-02-01-cache-ttl.md"
out="$(run)"; rc=$?
assert_rc "dated doc without header fails" 1 $rc
assert_contains "missing header named" "$out" "dated-doc-missing-date"

printf 'Date: 2026-03-01\n\nAs of 2026-02-01 sessions last twenty minutes.\n' > "$repo/docs/log/2026-02-01-cache-ttl.md"
out="$(run)"; rc=$?
assert_rc "dated doc with wrong header date fails" 1 $rc
assert_contains "mismatch named" "$out" "dated-doc-date-mismatch"
rm "$repo/docs/log/2026-02-01-cache-ttl.md"

printf '## Release notes\nPreviously the cache was ten minutes.\n' > "$repo/CHANGELOG.md"
out="$(run)"; assert_rc "changelog skipped" 0 $?
rm "$repo/CHANGELOG.md"

printf 'Currently unsupported.\n' > "$repo/docs/other.md"
out="$(DOCS_LINT_SKIP=1 run)"; assert_rc "skip env passes" 0 $?
out="$(DOCS_LINT_SKIP_PATHS='^docs/other\.md$' run)"; assert_rc "skip paths passes" 0 $?
rm "$repo/docs/other.md"

printf 'The cache previously held ten minutes.\n' > "$repo/docs/hooked.md"
printf 'Fine sentence.\n' > "$repo/docs/other-clean.md"
hook() { printf '{"tool_input":{"file_path":"%s"}}' "$1" | (cd "$repo" && "$lint" --hook 2>&1); }
out="$(hook "$repo/docs/hooked.md")"; rc=$?
assert_rc "hook flags the edited file" 2 $rc
assert_contains "hook names rule" "$out" "docs/hooked.md"
out="$(hook "$repo/docs/other-clean.md")"; assert_rc "hook ignores other files' violations" 0 $?
out="$(hook "$repo/docs/script.sh")"; assert_rc "hook ignores non-markdown" 0 $?
out="$(printf '{}' | (cd "$repo" && "$lint" --hook 2>&1))"; assert_rc "hook without path passes" 0 $?
rm "$repo/docs/hooked.md" "$repo/docs/other-clean.md"

out="$(run bogus-ref)"; assert_rc "bad base is usage error" 2 $?
out="$(cd "$TMPROOT" && "$lint" 2>&1)"; assert_rc "outside repo exits 3" 3 $?

finish
