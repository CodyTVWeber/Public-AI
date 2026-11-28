#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/cc-lib.sh"
new_tmp

write_long() {
  local dest="$1" n="$2"
  { echo 'export function long(total: number) {'; long_body "$n"; echo '  return total;'; echo '}'; } > "$dest"
}

long_body() { local n="$1" i; for i in $(seq 1 "$n"); do printf '  total = total + %s;\n' "$i"; done; }

severity() {
  local file="$1"
  shift
  env "$@" "$CQ" --all-lines "$file" 2>/dev/null | jq -r --arg r function-length '[.findings[] | select(.rule == $r) | .severity] | unique | join(",")'
}

write_long "$TMPROOT/long21.ts" 20
write_long "$TMPROOT/long41.ts" 40
write_long "$TMPROOT/long46.ts" 45
write_long "$TMPROOT/long51.ts" 50
write_long "$TMPROOT/long81.ts" 80
write_long "$TMPROOT/long86.ts" 85
write_long "$TMPROOT/long101.ts" 100

assert_eq "default b warns at 21" "warn" "$(severity "$TMPROOT/long21.ts")"
assert_eq "default b errors at 41" "error" "$(severity "$TMPROOT/long41.ts")"

assert_eq "profile a warns at 41" "warn" "$(severity "$TMPROOT/long41.ts" CC_FUNC_SIZE=a)"
assert_eq "profile a silent at 21" "" "$(severity "$TMPROOT/long21.ts" CC_FUNC_SIZE=a)"
assert_eq "profile a errors at 81" "error" "$(severity "$TMPROOT/long81.ts" CC_FUNC_SIZE=a)"
assert_eq "profile a still warns at 46" "warn" "$(severity "$TMPROOT/long46.ts" CC_FUNC_SIZE=a)"
assert_eq "profile a errors at 86" "error" "$(severity "$TMPROOT/long86.ts" CC_FUNC_SIZE=a)"

assert_eq "profile c silent at 46" "" "$(severity "$TMPROOT/long46.ts" CC_FUNC_SIZE=c)"
assert_eq "profile c warns at 51" "warn" "$(severity "$TMPROOT/long51.ts" CC_FUNC_SIZE=c)"
assert_eq "profile c errors at 101" "error" "$(severity "$TMPROOT/long101.ts" CC_FUNC_SIZE=c)"

assert_eq "numeric warn override" "warn" "$(severity "$TMPROOT/long21.ts" CC_FUNC_SIZE=c CC_FUNC_WARN=10)"
assert_eq "numeric error override" "error" "$(severity "$TMPROOT/long41.ts" CC_FUNC_SIZE=a CC_FUNC_ERROR=40)"

"$CQ" --all-lines "$TMPROOT/long21.ts" >/dev/null 2>&1
assert_rc "valid default run is not usage" 0 $?
CC_FUNC_SIZE=z "$CQ" --all-lines "$TMPROOT/long21.ts" >/dev/null 2>&1
assert_rc "unknown profile is usage" 2 $?
out="$(CC_FUNC_SIZE=z "$CQ" --all-lines "$TMPROOT/long21.ts" 2>&1 >/dev/null || true)"
assert_contains "unknown profile names a, b, or c" "$out" "want a, b, or c"

repo="$TMPROOT/sized"
make_repo "$repo"
write_long "$repo/long46.ts" 45
printf 'size: a\n' > "$repo/.func-size"
out="$(cd "$repo" && "$CQ" --all-lines long46.ts 2>/dev/null)"
assert_eq "file profile a warns at 46" "warn" "$(jq -r --arg r function-length '[.findings[] | select(.rule == $r) | .severity] | unique | join(",")' <<<"$out")"

printf 'size: c\n' > "$repo/.func-size"
out="$(cd "$repo" && "$CQ" --all-lines long46.ts 2>/dev/null)"
assert_eq "file profile c silent at 46" "" "$(jq -r --arg r function-length '[.findings[] | select(.rule == $r) | .severity] | unique | join(",")' <<<"$out")"

out="$(cd "$repo" && CC_FUNC_SIZE=a "$CQ" --all-lines long46.ts 2>/dev/null)"
assert_eq "env profile wins over file" "warn" "$(jq -r --arg r function-length '[.findings[] | select(.rule == $r) | .severity] | unique | join(",")' <<<"$out")"

printf 'size: z\n' > "$repo/.func-size"
(cd "$repo" && "$CQ" --all-lines long46.ts >/dev/null 2>&1)
assert_rc "unknown file profile is usage" 2 $?

finish
