#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/../../../../scripts/tests/lib.sh"
new_tmp

tool="$here/../new-doc.sh"

fresh() { rm -rf "$TMPROOT/r"; mkdir -p "$TMPROOT/r"; r="$TMPROOT/r"; }

fresh
out="$("$tool" spec "Template Gallery" --root "$r")"
assert_rc "spec ok" 0 $?
assert_eq "spec path" docs/align/template-gallery/spec.md "$(jq -r .path <<<"$out")"
assert_eq "default convention" "default docs/, topic adr/" "$(jq -r .convention <<<"$out")"
assert_contains "title filled" "$(cat "$r/docs/align/template-gallery/spec.md")" "# Spec: Template Gallery"
assert_contains "fill-ins stay" "$(cat "$r/docs/align/template-gallery/spec.md")" "{{one sentence"

"$tool" spec "Template Gallery" --root "$r" >/dev/null 2>&1
assert_rc "spec exists" 3 $?
printf 'mine\n' > "$r/docs/align/template-gallery/glossary.md"
"$tool" glossary "Template Gallery" --root "$r" >/dev/null 2>&1
assert_rc "glossary exists" 3 $?
assert_eq "existing file untouched" mine "$(cat "$r/docs/align/template-gallery/glossary.md")"

for kind in glossary alignment; do
  fresh
  out="$("$tool" "$kind" "Template Gallery" --root "$r")"
  assert_eq "$kind path" "docs/align/template-gallery/$kind.md" "$(jq -r .path <<<"$out")"
done

fresh
out="$("$tool" adr "Template Gallery" --slug use-grid --date 2025-01-02 --root "$r")"
assert_eq "adr path" docs/align/template-gallery/adr/2025-01-02-use-grid.md "$(jq -r .path <<<"$out")"
body="$(cat "$r/docs/align/template-gallery/adr/2025-01-02-use-grid.md")"
assert_contains "adr date" "$body" "Date: 2025-01-02"
assert_contains "adr status" "$body" "Status: proposed"
assert_contains "adr supersedes" "$body" "Supersedes: none"
assert_contains "adr title from slug" "$body" "# use grid"
out="$("$tool" adr "Template Gallery" --slug use-grid --date 2025-01-02 --root "$r")"
assert_eq "same-day collision" docs/align/template-gallery/adr/2025-01-02-use-grid-2.md "$(jq -r .path <<<"$out")"
out="$("$tool" adr "Template Gallery" --slug use-grid --date 2025-01-02 --root "$r")"
assert_eq "second collision" docs/align/template-gallery/adr/2025-01-02-use-grid-3.md "$(jq -r .path <<<"$out")"
assert_contains "first adr kept" "$(cat "$r/docs/align/template-gallery/adr/2025-01-02-use-grid.md")" "# use grid"
out="$("$tool" adr "Template Gallery" --date 2025-03-04 --root "$r")"
assert_eq "slug defaults to topic" docs/align/template-gallery/adr/2025-03-04-template-gallery.md "$(jq -r .path <<<"$out")"

fresh
mkdir -p "$r/doc"
out="$("$tool" spec gallery --root "$r")"
assert_eq "existing doc/ used" doc/align/gallery/spec.md "$(jq -r .path <<<"$out")"
assert_eq "doc/ convention" "existing doc/, topic adr/" "$(jq -r .convention <<<"$out")"

fresh
mkdir -p "$r/docs/adr"
out="$("$tool" adr gallery --slug use-grid --date 2025-01-02 --root "$r")"
assert_eq "shared docs/adr used" docs/adr/2025-01-02-use-grid.md "$(jq -r .path <<<"$out")"
assert_eq "shared adr convention" "existing docs/, shared existing docs/adr/" "$(jq -r .convention <<<"$out")"
assert_eq "spec stays in topic dir" docs/align/gallery/spec.md "$("$tool" spec gallery --root "$r" | jq -r .path)"

fresh
mkdir -p "$r/adr"
assert_eq "shared adr/ used" adr/2025-01-02-use-grid.md "$("$tool" adr gallery --slug use-grid --date 2025-01-02 --root "$r" | jq -r .path)"

"$tool" bogus gallery --root "$r" >/dev/null 2>&1
assert_rc "unknown kind" 2 $?
"$tool" spec --root "$r" >/dev/null 2>&1
assert_rc "missing topic" 2 $?
"$tool" spec '!!!' --root "$r" >/dev/null 2>&1
assert_rc "unusable topic" 2 $?
"$tool" adr gallery --date soon --root "$r" >/dev/null 2>&1
assert_rc "bad date" 2 $?
"$tool" spec gallery --root "$TMPROOT/missing" >/dev/null 2>&1
assert_rc "missing root" 3 $?
"$tool" -h >/dev/null 2>&1
assert_rc "help" 0 $?

finish
