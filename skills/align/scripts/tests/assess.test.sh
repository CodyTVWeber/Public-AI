#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/../../../../scripts/tests/lib.sh"
new_tmp

tool="$here/../assess.sh"

LARGE_CLEAR='Migrate the auth service and billing service across repos: update the api, database, queue and cache. Acceptance criteria: AC-1 login still works; AC-2 invoices are unchanged. Done when the regression suite passes.'
LARGE_VAGUE='Rebuild the api, database, search, queue and cache layers across repos and ship an admin dashboard and email reports as needed'
MEDIUM_CLEAR='Add a template gallery: the API returns published templates, the frontend lists them in a grid, and the worker rebuilds the search index. Acceptance criteria: AC-1 the grid lists every published template; AC-2 the search finds a template by name. Done when the tests pass.'

table() {
  cat <<EOT
small|low|false|false|Rename the --out flag to --output in cli.sh
small|low|false|false|Fix the typo in the README heading
small|low|false|false|Update the retry delay in client.py to 500 ms
small|high|false|true|Make search better somehow
small|high|false|true|Improve the template gallery, maybe add filters etc. and so on
small|medium|false|false|Add dark mode somehow
small|medium|false|false|TBD
small|low|true|false|Add a modal to the settings page with a close button
small|low|true|false|Add an export button on the reports screen that downloads a CSV; done when the file opens in a spreadsheet
small|low|true|false|Redesign the template gallery page layout with new styles and copy for mobile
medium|low|false|false|$MEDIUM_CLEAR
medium|low|false|false|Refactor the auth service, the billing service and the notification service to share one queue; update docs
large|low|false|false|$LARGE_CLEAR
large|medium|false|true|$LARGE_VAGUE
EOT
}

while IFS='|' read -r size vagueness ui suggest text; do
  out="$("$tool" "$text")"
  assert_eq "size: $text" "$size" "$(jq -r .size <<<"$out")"
  assert_eq "vagueness: $text" "$vagueness" "$(jq -r .vagueness <<<"$out")"
  assert_eq "ui: $text" "$ui" "$(jq -r .ui <<<"$out")"
  assert_eq "suggest: $text" "$suggest" "$(jq -r .suggest_align <<<"$out")"
done < <(table)

out="$("$tool" Make it better)"
assert_eq "args joined into one text" 3 "$(jq -r .signals.words <<<"$out")"

printf 'Make it better\n- one\n- two\n' > "$TMPROOT/task.txt"
out="$("$tool" --file "$TMPROOT/task.txt")"
assert_eq "file input bullets" 2 "$(jq -r .signals.bullets <<<"$out")"
assert_eq "file input vague hits" 1 "$(jq -r .signals.vague <<<"$out")"

out="$("$tool" "$LARGE_VAGUE")"
assert_contains "reasons name the vague phrase" "$(jq -r '.reasons | join(";")' <<<"$out")" "vague phrases"
assert_contains "reasons name the missing criteria" "$(jq -r '.reasons | join(";")' <<<"$out")" "no acceptance"
assert_eq "reasons empty for a clear small task" "[]" "$("$tool" "Rename the --out flag to --output in cli.sh" | jq -c .reasons)"

"$tool" "" >/dev/null 2>&1
assert_rc "empty text" 2 $?
"$tool" "   " >/dev/null 2>&1
assert_rc "blank text" 2 $?
"$tool" >/dev/null 2>&1
assert_rc "no args" 2 $?
"$tool" --file "$TMPROOT/missing.txt" >/dev/null 2>&1
assert_rc "missing file" 2 $?
"$tool" -h >/dev/null 2>&1
assert_rc "help" 0 $?
assert_contains "help lists thresholds" "$("$tool" --help)" "points >= 4 large"

finish
