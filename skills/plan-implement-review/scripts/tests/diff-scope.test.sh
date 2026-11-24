#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/forge-helpers.sh"
ds="$scripts/diff-scope.sh"

mk_repo "$tmp" "https://gitlab.example.test/grp/proj"
cd "$tmp/work"

scenario() {
  local name=$1
  shift
  git checkout -q -B "t-$name" main
  local f
  for f in "$@"; do
    mkdir -p "$(dirname "$f")"
    printf '%s\n' "$name" >"$f"
  done
  git add -A
  git commit -q --allow-empty -m "$name"
  run "$ds" main
  check "$name exit" 0 "$rc"
}

flags() {
  printf '%s' "$out" | jq -c '[.docs_only, .ui_changed, .backend_changed, .db_changed, .test_only]'
}

scenario docs README.md docs/guide.txt
check "docs flags" '[true,false,false,false,false]' "$(flags)"

scenario ui src/components/Button.tsx styles/app.css
check "ui flags" '[false,true,false,false,false]' "$(flags)"

scenario backend src/main/java/Foo.java
check "backend flags" '[false,false,true,false,false]' "$(flags)"

scenario backendtest src/main/java/Foo.java src/test/java/FooTest.java
check "backend+test flags" '[false,false,true,false,false]' "$(flags)"

scenario testonly src/test/java/FooTest.java web/app.test.ts tests/helper.py
check "test-only flags" '[false,false,false,false,true]' "$(flags)"

scenario db db/migrations/001_init.sql
check "db flags" '[false,false,false,true,false]' "$(flags)"

scenario mixed README.md web/pages/index.tsx server/app.go db/schema.sql
check "mixed flags" '[false,true,true,true,false]' "$(flags)"

scenario upper README.MD DOCS/Notes.TXT
check "case-insensitive docs" '[true,false,false,false,false]' "$(flags)"

scenario spaces "docs/my file.md"
jcheck "space file listed" .files '["docs/my file.md"]'
check "space docs" '[true,false,false,false,false]' "$(flags)"

git checkout -q -B t-empty main
run "$ds" main
check "empty flags" '[false,false,false,false,false]' "$(flags)"
jcheck "empty files" .files '[]'

run "$ds" origin/main
check "remote-tracking base" 0 "$rc"
run "$ds" nope
check "bad base exit" 3 "$rc"
run "$ds"
check "no args exit" 2 "$rc"
run "$ds" --help
check "help exit" 0 "$rc"

finish
