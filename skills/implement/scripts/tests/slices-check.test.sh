#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"
sc="$scripts/slices-check.sh"

slices() {
  printf '%s' "$1" >"$tmp/s.json"
  run "$sc" "$tmp/s.json" "${@:2}"
}

slices '{"slices":[{"name":"a","paths":["src/a/**","docs/a.md"]},{"name":"b","paths":["src/b/**","docs/b.md"]}]}'
check disjoint-exit 0 "$rc"
jcheck disjoint-ok .ok true

slices '{"slices":[{"name":"a","paths":["src/a/**"]},{"name":"b","paths":["src/ab/**"]}]}'
check sibling-prefix-exit 0 "$rc"

slices '{"slices":[{"name":"a","paths":["src/**"]},{"name":"b","paths":["src/b/**"]}]}'
check glob-in-glob-exit 1 "$rc"
jcheck glob-in-glob-pair '.overlaps[0] | [.a, .b]' '["a","b"]'
jcheck glob-in-glob-pattern '.overlaps[0].pattern' '"src/** | src/b/**"'

slices '{"slices":[{"name":"a","paths":["src/a/**"]},{"name":"b","paths":["src/a/x.txt"]}]}'
check file-in-glob-exit 1 "$rc"

slices '{"slices":[{"name":"a","paths":["src/a/x.txt"]},{"name":"b","paths":["src/a/x.txt"]}]}'
check same-file-exit 1 "$rc"

slices '{"slices":[{"name":"a","paths":["src/a.md"]},{"name":"b","paths":["src/a"]}]}'
check exact-neighbours-exit 0 "$rc"

slices '{"slices":[{"name":"a","paths":["src/a"]},{"name":"b","paths":["src/a/**"]}]}'
check dir-vs-glob-exit 1 "$rc"

slices '{"slices":[{"name":"a","paths":["src/a/"]},{"name":"b","paths":["./src/a/z.txt"]}]}'
check trailing-slash-exit 1 "$rc"

slices '{"slices":[{"name":"a","paths":["**"]},{"name":"b","paths":["docs/b.md"]}]}'
check catch-all-exit 1 "$rc"

slices '{"slices":[{"name":"a","paths":["x"]},{"name":"a","paths":["y"]}]}'
check duplicate-exit 1 "$rc"
jcheck duplicate-error '.errors[0]' '"duplicate slice name: a"'

slices '{"slices":[{"name":"Bad_Name","paths":["x"]}]}'
check bad-name-exit 1 "$rc"

slices '{"slices":[{"name":"a","paths":[]}]}'
check empty-paths-exit 1 "$rc"

slices '{"slices":[{"name":"a","paths":["/abs"]},{"name":"b","paths":["../up"]}]}'
check bad-paths-exit 1 "$rc"
jcheck bad-paths-count '.errors | length' 2

five='{"slices":[{"name":"a","paths":["a"]},{"name":"b","paths":["b"]},{"name":"c","paths":["c"]},{"name":"d","paths":["d"]},{"name":"e","paths":["e"]}]}'
slices "$five"
check over-max-exit 1 "$rc"
slices "$five" --max-slices 5
check raised-max-exit 0 "$rc"
PIR_MAX_SLICES=2 slices "$five" --max-slices 5
check flag-beats-env 0 "$rc"
PIR_MAX_SLICES=2 slices "$five"
check env-max-exit 1 "$rc"

run "$sc"
check no-args-exit 2 "$rc"
run "$sc" "$tmp/missing.json"
check missing-file-exit 3 "$rc"
printf 'not json' >"$tmp/s.json"
run "$sc" "$tmp/s.json"
check bad-json-exit 3 "$rc"
run "$sc" --help
check help-exit 0 "$rc"

finish
