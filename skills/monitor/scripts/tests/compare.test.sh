#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/../../../../scripts/tests/lib.sh"
new_tmp

tool="$here/../compare.sh"
baseline='{"errors":2,"sigs":["TimeoutError","NotFound"],"rows":100,"flag":"on","p95":400,"load":10}'
echo "$baseline" >"$TMPROOT/base.json"

compare() {
  echo "$1" >"$TMPROOT/cur.json"
  echo "$2" >"$TMPROOT/rules.json"
  out="$("$tool" "$TMPROOT/base.json" "$TMPROOT/cur.json" "$TMPROOT/rules.json" 2>&1)"
  rc=$?
}

status_of() { jq -r --arg n "$1" '.signals[] | select(.name == $n) | .status' <<<"$out"; }

compare '{"errors":3}' '[{"name":"errors","kind":"max_ratio","limit":2}]'
assert_rc "max_ratio within" 0 "$rc"
assert_eq "max_ratio ok" ok "$(status_of errors)"
assert_eq "healthy verdict" healthy "$(jq -r .verdict <<<"$out")"

compare '{"errors":5}' '[{"name":"errors","kind":"max_ratio","limit":2}]'
assert_rc "max_ratio breach" 1 "$rc"
assert_eq "max_ratio fail" fail "$(status_of errors)"
assert_eq "degraded verdict" degraded "$(jq -r .verdict <<<"$out")"

compare '{"errors":5}' '[{"name":"errors","kind":"max_ratio","limit":2,"allow_noise_abs":4}]'
assert_rc "noise absorbs a small delta" 0 "$rc"
assert_eq "noise ok" ok "$(status_of errors)"

compare '{"errors":9}' '[{"name":"errors","kind":"max_ratio","limit":2,"allow_noise_abs":4}]'
assert_eq "delta above noise still fails" fail "$(status_of errors)"

compare '{"errors":3}' '[{"name":"errors","kind":"max_ratio","limit":2,"warn":1.2}]'
assert_eq "soft bound warns" warn "$(status_of errors)"
assert_rc "warn alone is healthy" 0 "$rc"

compare '{"p95":900}' '[{"name":"p95","kind":"max_abs","limit":800}]'
assert_eq "max_abs fail" fail "$(status_of p95)"
compare '{"p95":800}' '[{"name":"p95","kind":"max_abs","limit":800}]'
assert_eq "max_abs boundary ok" ok "$(status_of p95)"

compare '{"rows":40}' '[{"name":"rows","kind":"min_abs","limit":50}]'
assert_eq "min_abs fail" fail "$(status_of rows)"
compare '{"rows":60}' '[{"name":"rows","kind":"min_abs","limit":50,"warn":70}]'
assert_eq "min_abs warn" warn "$(status_of rows)"

compare '{"flag":"on"}' '[{"name":"flag","kind":"equals","value":"on"}]'
assert_eq "equals ok" ok "$(status_of flag)"
compare '{"flag":"off"}' '[{"name":"flag","kind":"equals","value":"on"}]'
assert_eq "equals fail" fail "$(status_of flag)"

compare '{"sigs":["TimeoutError","DeadlockError"]}' '[{"name":"sigs","kind":"forbid_new_keys"}]'
assert_eq "unseen signature fails" fail "$(status_of sigs)"
assert_contains "names the signature" "$out" "DeadlockError"
compare '{"sigs":["NotFound"]}' '[{"name":"sigs","kind":"forbid_new_keys"}]'
assert_eq "subset of baseline ok" ok "$(status_of sigs)"

compare '{}' '[{"name":"errors","kind":"max_ratio","limit":2}]'
assert_eq "missing current is unknown" unknown "$(status_of errors)"
assert_rc "unknown exits 3" 3 "$rc"
assert_eq "unknown verdict" unknown "$(jq -r .verdict <<<"$out")"

compare '{"errors":null}' '[{"name":"errors","kind":"max_abs","limit":9}]'
assert_eq "null current is unknown" unknown "$(status_of errors)"

compare '{"errors":"n/a"}' '[{"name":"errors","kind":"max_abs","limit":9}]'
assert_eq "non-number is unknown" unknown "$(status_of errors)"

compare '{"fresh":5}' '[{"name":"fresh","kind":"max_ratio","limit":2}]'
assert_eq "no baseline is unknown" unknown "$(status_of fresh)"

compare '{"errors":1}' '[{"name":"errors","kind":"median"}]'
assert_eq "unknown kind is unknown" unknown "$(status_of errors)"

compare '{"errors":1}' '[]'
assert_rc "no rules is never healthy" 3 "$rc"

compare '{"errors":99,"rows":60}' '[{"name":"errors","kind":"max_ratio","limit":2},{"name":"load","kind":"max_abs","limit":5}]'
assert_rc "fail outranks unknown" 1 "$rc"
assert_eq "verdict degraded" degraded "$(jq -r .verdict <<<"$out")"

compare '{"errors":2,"load":1}' '[{"name":"errors","kind":"max_ratio","limit":2},{"name":"load","kind":"max_abs","limit":5}]'
assert_eq "signal fields" '["baseline","name","reason","rule","status","value"]' "$(jq -c '.signals[0] | keys' <<<"$out")"

echo '{' >"$TMPROOT/bad.json"
out="$("$tool" "$TMPROOT/bad.json" "$TMPROOT/cur.json" "$TMPROOT/rules.json" 2>&1)"
assert_rc "invalid json" 2 "$?"
out="$("$tool" "$TMPROOT/base.json" "$TMPROOT/missing.json" "$TMPROOT/rules.json" 2>&1)"
assert_rc "missing file" 2 "$?"
out="$("$tool" "$TMPROOT/base.json" 2>&1)"
assert_rc "wrong arg count" 2 "$?"
echo '{"name":"x"}' >"$TMPROOT/rules.json"
out="$("$tool" "$TMPROOT/base.json" "$TMPROOT/cur.json" "$TMPROOT/rules.json" 2>&1)"
assert_rc "rules not an array" 2 "$?"
out="$("$tool" -h)"
assert_contains "help lists kinds" "$out" "forbid_new_keys"

finish
