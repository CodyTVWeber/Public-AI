#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/../../../../scripts/tests/lib.sh"
new_tmp

tool="$here/../check-plan.sh"
template="$here/../../assets/templates/monitoring-plan.md"
plan="$TMPROOT/plan.md"

check() { out="$("$tool" "$plan" 2>&1)"; rc=$?; }
has_rule() { jq -e --arg r "$1" 'any(.violations[]; .rule == $r)' <<<"$out" >/dev/null; }
expect_rule() { has_rule "$2" && ok || bad "$1" "no $2 in: $out"; }

write_plan() {
  local touches="$1" rows="$2"
  {
    printf '# Plan\n\n- AC1: pages load\n- AC2: items are saved\n\nTouches data: %s\n\n## Signals\n\n' "$touches"
    printf '| Signal | Kind | Criteria | Source | Query or command | Baseline | Threshold rule | Cadence | Failure means | Action or owner |\n'
    printf '|---|---|---|---|---|---|---|---|---|---|\n%s\n' "$rows"
  } >"$plan"
}

errors_row='| err_rate | error | AC1 | apm | 5xx per minute | prior hour | max_ratio 1.5 | 10m | users see failures | on-call rolls back |'
data_row='| item_rows | data | AC2 | sql | `SELECT count(*) FROM items` | prior count | min_abs 1 | 10m | table emptied | owner inspects |'

check_template() {
  cp "$template" "$plan"
  check
  assert_rc "shipped template passes" 0 "$rc"
  assert_eq "no violations" '{"violations":[]}' "$out"
}
check_template

write_plan yes "$errors_row
$data_row"
check
assert_rc "good plan" 0 "$rc"

write_plan no "$errors_row
| probe | works | AC2 | probe | GET the page | 200 | equals 200 | 5m | page down | on-call decides |"
check
assert_rc "no data signal needed without data" 0 "$rc"

write_plan yes "$errors_row"
check
assert_rc "uncovered and no data" 1 "$rc"
expect_rule "data signal required" no-data-signal
expect_rule "AC2 uncovered" uncovered-criterion

write_plan yes "$data_row"
check
expect_rule "error signal required" no-error-signal

write_plan no "${errors_row/max_ratio 1.5/}"
check
expect_rule "empty threshold" empty-cell

write_plan no "${errors_row/max_ratio 1.5/stay low}"
check
expect_rule "unknown threshold rule" bad-threshold

write_plan no "${errors_row/on-call rolls back/}"
check
expect_rule "action required" empty-cell

write_plan no "${errors_row/users see failures/<what a failure means>}"
check
expect_rule "placeholder" placeholder

write_plan no "${errors_row/| error |/| mystery |}"
check
expect_rule "bad kind" bad-kind

dash_row='| err_rate | error | AC-1 | apm | 5xx per minute | prior hour | max_ratio 1.5 | 10m | users see failures | on-call rolls back |'
dash_plan() {
  printf '# Plan\n\n- AC-1: pages load\n- AC-2: items are saved\n\n## Signals\n\n| Signal | Kind | Criteria | Source | Query or command | Baseline | Threshold rule | Cadence | Failure means | Action or owner |\n|---|---|---|---|---|---|---|---|---|---|\n%s\n' "$1" >"$plan"
}
dash_plan "$dash_row"
check
assert_rc "AC-2 uncovered" 1 "$rc"
expect_rule "dashed id uncovered" uncovered-criterion
dash_plan "$dash_row
| probe | works | AC-2 | probe | GET the page | 200 | equals 200 | 5m | page down | on-call decides |"
check
assert_rc "dashed ids covered" 0 "$rc"

printf '# Plan\n\n- AC1: pages load\n\nNo table here.\n' >"$plan"
check
assert_rc "no table" 1 "$rc"
expect_rule "no table reported" no-table

printf '| Signal | Kind |\n|---|---|\n| a | error |\n' >"$plan"
check
expect_rule "missing columns" missing-column

out="$("$tool" "$TMPROOT/absent.md" 2>&1)"
assert_rc "missing file" 3 "$?"
out="$("$tool" 2>&1)"
assert_rc "no args" 2 "$?"
out="$("$tool" -h)"
assert_contains "help lists rules" "$out" "uncovered-criterion"

finish
