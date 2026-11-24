#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$here/lib-forge.sh"

usage() {
  cat <<'USAGE'
usage: diff-scope.sh <base>
Classify files changed in `git diff <base>...HEAD` by path glob (case-insensitive, first match wins):
  test     */test/* */tests/* */__tests__/* */spec/* */e2e/* *.test.* *.spec.* *_test.* *_spec.* test_*
           *Test.* *Tests.* *IT.java *IT.kt
  docs     *.md *.mdx *.rst *.txt *.adoc docs/* */docs/* LICENSE* CHANGELOG*
  db       *.sql *.prisma */migrations/* */migration/* */db/migrate/* db/* */flyway/* */liquibase/*
  ui       *.tsx *.jsx *.vue *.svelte *.html *.css *.scss *.sass *.less *.svg *.png *.jpg *.gif *.webp *.ico *.hbs
           *.erb *.ftl *.stories.* */components/* */pages/* */views/* */templates/* */styles/* */assets/*
  backend  *.java *.kt *.kts *.scala *.go *.py *.rb *.rs *.cs *.php *.ex *.exs *.swift *.ts *.js *.mjs *.cjs
           (after test/docs/db/ui) plus */src/main/* */server/* */api/* */services/*
stdout: {docs_only, ui_changed, backend_changed, db_changed, test_only, files[]}
docs_only/test_only: every changed file is docs/test (false when nothing changed).
exit: 0 ok, 2 usage, 3 precondition (not a repo, bad base)
USAGE
}

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
  "" | -*)
    usage >&2
    exit 2
    ;;
esac
[ "$#" -eq 1 ] || {
  usage >&2
  exit 2
}

base=$1
git_init
git rev-parse --verify --quiet "$base^{commit}" >/dev/null || die 3 "base ref not found: $base"

is_test() {
  case "$1" in
    test/* | tests/* | spec/* | e2e/* | __tests__/* | */test/* | */tests/* | */__tests__/* | */spec/* | */e2e/*) return 0 ;;
    *.test.* | *.spec.* | *_test.* | *_spec.* | test_* | */test_* | *Test.* | *Tests.* | *IT.java | *IT.kt) return 0 ;;
  esac
  return 1
}

is_docs() {
  case "$1" in
    *.md | *.mdx | *.rst | *.txt | *.adoc | docs/* | */docs/* | LICENSE* | */LICENSE* | CHANGELOG* | */CHANGELOG*) return 0 ;;
  esac
  return 1
}

is_db() {
  case "$1" in
    *.sql | *.prisma | migrations/* | */migrations/* | migration/* | */migration/* | */db/migrate/* | db/* | */flyway/* | */liquibase/*) return 0 ;;
  esac
  return 1
}

is_ui() {
  case "$1" in
    *.tsx | *.jsx | *.vue | *.svelte | *.html | *.css | *.scss | *.sass | *.less | *.svg | *.png | *.jpg | *.jpeg | *.gif | *.webp | *.ico | *.hbs | *.erb | *.ftl) return 0 ;;
    *.stories.* | */components/* | */pages/* | */views/* | */templates/* | */styles/* | */assets/*) return 0 ;;
  esac
  return 1
}

is_backend() {
  case "$1" in
    *.java | *.kt | *.kts | *.scala | *.go | *.py | *.rb | *.rs | *.cs | *.php | *.ex | *.exs | *.swift | *.ts | *.js | *.mjs | *.cjs) return 0 ;;
    */src/main/* | src/main/* | */server/* | server/* | */api/* | api/* | */services/* | services/*) return 0 ;;
  esac
  return 1
}

shopt -s nocasematch
total=0 docs=0 tests=0 ui=false be=false db=false
list=$(mktemp)
trap 'rm -f "$list"' EXIT
while IFS= read -r -d '' f; do
  total=$((total + 1))
  printf '%s\n' "$f" >>"$list"
  if is_test "$f"; then
    tests=$((tests + 1))
  elif is_docs "$f"; then
    docs=$((docs + 1))
  elif is_db "$f"; then
    db=true
  elif is_ui "$f"; then
    ui=true
  elif is_backend "$f"; then
    be=true
  fi
done < <(git diff --name-only -z "$base...HEAD")

docs_only=false
test_only=false
[ "$total" -gt 0 ] && [ "$docs" -eq "$total" ] && docs_only=true
[ "$total" -gt 0 ] && [ "$tests" -eq "$total" ] && test_only=true

jq -Rnc --argjson d "$docs_only" --argjson u "$ui" --argjson b "$be" --argjson s "$db" --argjson t "$test_only" \
  '{docs_only: $d, ui_changed: $u, backend_changed: $b, db_changed: $s, test_only: $t, files: [inputs]}' <"$list"
