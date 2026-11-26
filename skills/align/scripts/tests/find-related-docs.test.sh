#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/../../../../scripts/tests/lib.sh"
new_tmp

tool="$here/../find-related-docs.sh"
repo="$TMPROOT/repo"
mkdir -p "$repo/docs/align/template-gallery/adr" "$repo/docs/plans" "$repo/docs/ops" \
  "$repo/node_modules/gallery-kit/docs" "$repo/vendor/docs" "$repo/src"

printf '# Spec: Template gallery\n\nA gallery of templates with preview and search.\n' > "$repo/docs/align/template-gallery/spec.md"
printf '# Use a grid\n\nDate: 2025-01-02\nStatus: accepted\n\nTemplate gallery layout is a grid.\n' > "$repo/docs/align/template-gallery/adr/2025-01-02-use-grid.md"
printf '# Glossary: Template gallery\n\n| Term | Definition |\n| --- | --- |\n| Template | a starter layout |\n' > "$repo/docs/align/template-gallery/glossary.md"
printf '# Plan: gallery search\n\nSearch inside the template gallery.\n' > "$repo/docs/plans/2025-02-03_gallery-search.md"
printf '# Backups\n\nNightly backup of the database.\n' > "$repo/docs/ops/backups.md"
printf '# Gallery kit\n\nTemplate gallery widgets.\n' > "$repo/node_modules/gallery-kit/docs/readme.md"
printf '# Vendored\n\nTemplate gallery vendored.\n' > "$repo/vendor/docs/notes.md"
printf '# Sample\n\nThe template gallery is the home page.\n' > "$repo/README.md"
printf '# Agents\n\nNothing relevant here.\n' > "$repo/AGENTS.md"
printf '# Source note\n\nTemplate gallery code lives here.\n' > "$repo/src/notes.md"

out="$("$tool" template gallery --root "$repo")"
assert_rc "ok" 0 $?
paths="$(jq -r '.results[].path' <<<"$out")"
assert_contains "finds spec" "$paths" "docs/align/template-gallery/spec.md"
assert_contains "finds adr" "$paths" "docs/align/template-gallery/adr/2025-01-02-use-grid.md"
assert_contains "finds glossary" "$paths" "docs/align/template-gallery/glossary.md"
assert_contains "finds plan" "$paths" "docs/plans/2025-02-03_gallery-search.md"
assert_contains "finds readme" "$paths" "README.md"
assert_not_contains "skips node_modules" "$paths" "node_modules"
assert_not_contains "skips vendor" "$paths" "vendor"
assert_not_contains "skips unrelated doc" "$paths" "backups.md"
assert_not_contains "skips files outside doc dirs" "$paths" "src/notes.md"
assert_not_contains "skips zero scores" "$paths" "AGENTS.md"

kind() { jq -r --arg p "$1" '.results[] | select(.path == $p) | .kind' <<<"$out"; }
assert_eq "kind spec" spec "$(kind docs/align/template-gallery/spec.md)"
assert_eq "kind adr" adr "$(kind docs/align/template-gallery/adr/2025-01-02-use-grid.md)"
assert_eq "kind glossary" glossary "$(kind docs/align/template-gallery/glossary.md)"
assert_eq "kind plan" plan "$(kind docs/plans/2025-02-03_gallery-search.md)"
assert_eq "kind readme" readme "$(kind README.md)"

assert_eq "date from filename" 2025-01-02 "$(jq -r '.results[] | select(.kind == "adr") | .date' <<<"$out")"
assert_eq "date absent" null "$(jq -r '.results[] | select(.kind == "spec") | .date' <<<"$out")"
assert_eq "title from heading" "Spec: Template gallery" "$(jq -r '.results[] | select(.kind == "spec") | .title' <<<"$out")"

scores="$(jq -c '[.results[].score]' <<<"$out")"
assert_eq "best first" "$scores" "$(jq -c 'sort | reverse' <<<"$scores")"
assert_eq "spec outranks readme" true "$(jq -r '([.results[] | select(.kind == "spec") | .score][0]) > ([.results[] | select(.kind == "readme") | .score][0])' <<<"$out")"

assert_eq "terms drop stop words" '["gallery","template"]' "$(jq -c .terms <<<"$("$tool" the template and gallery --root "$repo")")"
assert_eq "one quoted argument splits" '["gallery","template"]' "$(jq -c .terms <<<"$("$tool" "template gallery" --root "$repo")")"

many="$TMPROOT/many"
mkdir -p "$many/docs"
for i in $(seq 1 20); do printf '# Topic %s\n\nbasketball\n' "$i" > "$many/docs/n$i.md"; done
assert_eq "caps at 15" 15 "$("$tool" basketball --root "$many" | jq '.results | length')"

assert_eq "no match" "[]" "$("$tool" zebra --root "$repo" | jq -c .results)"

"$tool" --root "$repo" >/dev/null 2>&1
assert_rc "no topic words" 2 $?
"$tool" the and --root "$repo" >/dev/null 2>&1
assert_rc "only stop words" 2 $?
"$tool" gallery --root "$TMPROOT/missing" >/dev/null 2>&1
assert_rc "missing root" 3 $?
"$tool" gallery --bogus >/dev/null 2>&1
assert_rc "unknown option" 2 $?
"$tool" -h >/dev/null 2>&1
assert_rc "help" 0 $?

finish
