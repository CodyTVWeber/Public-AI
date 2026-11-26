#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/../../../../scripts/tests/lib.sh"
new_tmp
. "$here/align-fixture.sh"

tool="$here/../check-align.sh"
rules_for() { "$tool" "$1" 2>/dev/null | jq -r '[.violations[].rule] | unique | join(",")'; }

case_dir() { rm -rf "$TMPROOT/c"; write_good "$TMPROOT/c/$NAME"; echo "$TMPROOT/c/$NAME"; }

expect_rule() {
  local rule="$1" out rc
  out="$("$tool" "$2" 2>/dev/null)"; rc=$?
  assert_rc "$rule exits 1" 1 "$rc"
  assert_contains "reports $rule" "$(jq -r '[.violations[].rule] | join(",")' <<<"$out")" "$rule"
}

d="$(case_dir)"
out="$("$tool" "$d")"; rc=$?
assert_rc "good topic" 0 "$rc"
assert_eq "good topic has no violations" "[]" "$(jq -c .violations <<<"$out")"
(cd "$d" && "$tool" >/dev/null 2>&1)
assert_rc "default dir is cwd" 0 $?

d="$(case_dir)"; rm "$d/glossary.md"
expect_rule missing-file "$d"
d="$(case_dir)"; sed -i.bak '/^## Constraints/d' "$d/spec.md"; rm "$d/spec.md.bak"
expect_rule missing-heading "$d"
d="$(case_dir)"; sed -i.bak 's/^- AC-2:/- AC-3:/' "$d/spec.md"; rm "$d/spec.md.bak"
expect_rule ac-number "$d"
d="$(case_dir)"; sed -i.bak 's/^- AC-2: /- /' "$d/spec.md"; rm "$d/spec.md.bak"
expect_rule ac-number "$d"
d="$(case_dir)"; sed -i.bak '/^- AC-/d' "$d/spec.md"; rm "$d/spec.md.bak"
expect_rule ac-number "$d"
d="$(case_dir)"; sed -i.bak 's/^- (non-blocking) Should/- Should/' "$d/spec.md"; rm "$d/spec.md.bak"
expect_rule question-unmarked "$d"
d="$(case_dir)"; sed -i.bak 's/| partial |/| mostly |/' "$d/spec.md"; rm "$d/spec.md.bak"
expect_rule design-authority "$d"
d="$(case_dir)"; sed -i.bak 's/^Build a browsable.*/one\ntwo\nthree\nfour\nfive\nsix/' "$d/alignment.md"; rm "$d/alignment.md.bak"
expect_rule task-too-long "$d"
d="$(case_dir)"; sed -i.bak '/^Aligned:/d' "$d/alignment.md"; rm "$d/alignment.md.bak"
expect_rule aligned-line "$d"
d="$(case_dir)"; sed -i.bak '/^Confirmed by:/d' "$d/alignment.md"; rm "$d/alignment.md.bak"
expect_rule aligned-line "$d"
d="$(case_dir)"; sed -i.bak 's/^- (non-blocking) Should search be fuzzy?/- (blocking) Should search be fuzzy?/' "$d/spec.md"; rm "$d/spec.md.bak"
expect_rule blocking-open "$d"
d="$(case_dir)"; sed -i.bak 's/^Confirmed by: .*/Confirmed by: none/' "$d/alignment.md"; rm "$d/alignment.md.bak"
expect_rule blocking-open "$d"
d="$(case_dir)"
sed -i.bak 's/^- (non-blocking) Should search be fuzzy?/- (blocking) Should search be fuzzy?/; s/^Aligned: yes/Aligned: no/; s/^Confirmed by: .*/Confirmed by: none/' "$d/spec.md" "$d/alignment.md"; rm "$d"/*.bak
assert_eq "blocking is fine while Aligned: no" "" "$(rules_for "$d")"
d="$(case_dir)"; sed -i.bak 's/\[\[member\]\]/[[customer]]/' "$d/spec.md"; rm "$d/spec.md.bak"
expect_rule unknown-term "$d"
d="$(case_dir)"; sed -i.bak 's/\[\[member\]\]/[[MEMBER]]/' "$d/spec.md"; rm "$d/spec.md.bak"
assert_eq "term match ignores case" "" "$(rules_for "$d")"
d="$(case_dir)"; mv "$d/$ADR" "$d/adr/use-grid.md"; sed -i.bak 's#adr/2025-01-02-use-grid.md#adr/use-grid.md#' "$d/spec.md"; rm "$d/spec.md.bak"
expect_rule adr-name "$d"
d="$(case_dir)"; sed -i.bak 's/^Date: 2025-01-02/Date: 2025-01-03/' "$d/$ADR"; rm "$d/$ADR.bak"
expect_rule adr-field "$d"
d="$(case_dir)"; sed -i.bak 's/^Status: accepted/Status: done/' "$d/$ADR"; rm "$d/$ADR.bak"
expect_rule adr-field "$d"
d="$(case_dir)"; sed -i.bak '/^Supersedes:/d' "$d/$ADR"; rm "$d/$ADR.bak"
expect_rule adr-field "$d"
d="$(case_dir)"; sed -i.bak 's#^Supersedes: none#Supersedes: 2024-01-01-old.md#' "$d/$ADR"; rm "$d/$ADR.bak"
expect_rule adr-field "$d"
d="$(case_dir)"; sed -i.bak '/^## Alternatives/d' "$d/$ADR"; rm "$d/$ADR.bak"
expect_rule missing-heading "$d"
d="$(case_dir)"; sed -i.bak 's#(adr/2025-01-02-use-grid.md)#(adr/gone.md)#' "$d/spec.md"; rm "$d/spec.md.bak"
expect_rule broken-link "$d"
d="$(case_dir)"; sed -i.bak 's/^Grid layout/Grid layout {{detail}}/; s/^- Grid layout/- Grid layout {{detail}}/' "$d/alignment.md"; rm "$d/alignment.md.bak"
expect_rule placeholder "$d"

d="$(case_dir)"; printf '\n```\n[x](missing.md) [[nope]]\n```\n' >> "$d/spec.md"
assert_eq "fenced examples ignored" "" "$(rules_for "$d")"

d="$(case_dir)"
printf '\n- [shared](../shared-adr/2025-01-02-shared.md)\n' >> "$d/spec.md"
mkdir -p "$TMPROOT/c/shared-adr"
sed 's/^Date: .*/Date: 2025-01-09/' "$d/$ADR" > "$TMPROOT/c/shared-adr/2025-01-02-shared.md"
expect_rule adr-field "$d"

d="$(case_dir)"
printf '\n' >> "$d/spec.md"
sed 's/^Date: .*/Date: 2025-01-03/' "$d/$ADR" > "$d/adr/2025-01-03-next.md"
sed -i.bak 's#^Supersedes: none#Supersedes: [Use a grid](2025-01-02-use-grid.md)#' "$d/adr/2025-01-03-next.md"; rm "$d/adr/2025-01-03-next.md.bak"
assert_eq "supersedes link resolves" "" "$(rules_for "$d")"

rm -rf "$TMPROOT/s"; mkdir -p "$TMPROOT/s"
for kind in spec glossary alignment; do "$here/../new-doc.sh" "$kind" gallery --root "$TMPROOT/s" >/dev/null; done
out="$("$tool" "$TMPROOT/s/docs/align/gallery" 2>/dev/null)"
assert_contains "scaffold reports placeholders" "$(jq -r '[.violations[].rule] | join(",")' <<<"$out")" "placeholder"

"$tool" "$TMPROOT/missing" >/dev/null 2>&1
assert_rc "missing dir" 3 $?
"$tool" a b >/dev/null 2>&1
assert_rc "two args" 2 $?
"$tool" -h >/dev/null 2>&1
assert_rc "help" 0 $?

finish
