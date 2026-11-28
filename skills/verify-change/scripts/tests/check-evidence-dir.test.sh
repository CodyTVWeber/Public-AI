#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/../../../../scripts/tests/lib.sh"
new_tmp

tool="$here/../check-evidence-dir.sh"

good="$TMPROOT/good"
mkdir -p "$good/out"
printf '%s\n' '{"kinds":["script"],"reason":"parser change; no UI"}' > "$good/kinds.json"
cat > "$good/evidence.md" <<'EOF'
Date: 2026-11-28
PR: pending

## Proof

| Claim | Kind | Where |
| --- | --- | --- |
| aliases insert verify | script | out/pir-args.json |
EOF
printf '#!/usr/bin/env bash\necho ok\n' > "$good/verify.sh"

out="$("$tool" --allow-pending "$good")"; rc=$?
assert_rc "good pending rc" 0 $rc
assert_eq "good ok" true "$(jq -r .ok <<<"$out")"

out="$("$tool" "$good" 2>/dev/null)"; rc=$?
assert_rc "pending without flag fails" 1 $rc
assert_contains "pending message" "$(jq -r '.missing | join("|")' <<<"$out")" "PR URL"

printf 'https://example.test/pr/1\n' >> "$good/evidence.md"
out="$("$tool" "$good")"; rc=$?
assert_rc "url passes without flag" 0 $rc

none="$TMPROOT/none"
mkdir -p "$none"
printf '%s\n' '{"kinds":[],"reason":"docs only; no runtime behavior"}' > "$none/kinds.json"
cat > "$none/evidence.md" <<'EOF'
Date: 2026-11-28
PR: pending

## Proof

No behavior change.
EOF
out="$("$tool" --allow-pending "$none")"; rc=$?
assert_rc "empty kinds without script" 0 $rc
assert_eq "empty kinds ok" true "$(jq -r .ok <<<"$out")"

bad="$TMPROOT/bad"
mkdir -p "$bad"
cp "$good/evidence.md" "$bad/evidence.md"
printf '%s\n' '{"kinds":["nope"],"reason":"x"}' > "$bad/kinds.json"
printf 'x\n' > "$bad/shot.png"
printf 'x\n' > "$bad/verify.sh"
out="$("$tool" "$bad" 2>/dev/null)"; rc=$?
assert_rc "unknown kind and binary fail" 1 $rc
assert_contains "unknown kind" "$(jq -r '.missing | join("|")' <<<"$out")" "unknown kind nope"
assert_contains "binary" "$(jq -r '.missing | join("|")' <<<"$out")" "binary: shot.png"

noscript="$TMPROOT/noscript"
mkdir -p "$noscript"
printf '%s\n' '{"kinds":["script"],"reason":"needs a script"}' > "$noscript/kinds.json"
cp "$good/evidence.md" "$noscript/evidence.md"
out="$("$tool" "$noscript" 2>/dev/null)"; rc=$?
assert_rc "script kind without sh" 1 $rc
assert_contains "need sh" "$(jq -r '.missing | join("|")' <<<"$out")" "need a .sh"

big="$TMPROOT/big"
mkdir -p "$big"
cp "$good/kinds.json" "$good/evidence.md" "$good/verify.sh" "$big/"
dd if=/dev/zero of="$big/out.bin" bs=32769 count=1 status=none
out="$("$tool" "$big" 2>/dev/null)"; rc=$?
assert_rc "oversize fails" 1 $rc
assert_contains "oversize" "$(jq -r '.missing | join("|")' <<<"$out")" "over 32768B: out.bin"

"$tool" >/dev/null 2>&1
assert_rc "no args" 2 $?
"$tool" "$TMPROOT/missing" >/dev/null 2>&1
assert_rc "missing dir" 2 $?

finish
