#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib.sh"
new_tmp

tree="$TMPROOT/tree"
mkdir -p "$tree/scripts/tests" "$tree/skills/demo"
cp "$here/run-all.sh" "$tree/scripts/tests/run-all.sh"
printf '#!/usr/bin/env bash\necho ran-quick\n' > "$tree/scripts/tests/quick.test.sh"
printf '#!/usr/bin/env bash\necho ran-slowpoke\n' > "$tree/skills/demo/slowpoke.test.sh"
printf 'slowpoke.test.sh\n' > "$tree/scripts/tests/slow.list"
runner="$tree/scripts/tests/run-all.sh"

out="$("$runner" 2>&1)"; rc=$?
assert_rc "default run passes" 0 $rc
assert_contains "default run includes quick tests" "$out" "ran-quick"
assert_contains "default run includes listed slow tests" "$out" "ran-slowpoke"
assert_contains "default run counts both" "$out" "2 test files, 0 failed, 0 skipped"

out="$("$runner" --fast 2>&1)"; rc=$?
assert_rc "fast run passes" 0 $rc
assert_contains "fast run includes quick tests" "$out" "ran-quick"
assert_not_contains "fast run skips listed tests" "$out" "ran-slowpoke"
assert_contains "fast run reports the skip" "$out" "1 test files, 0 failed, 1 skipped"

rm "$tree/scripts/tests/slow.list"
out="$("$runner" --fast 2>&1)"; assert_contains "fast run without a list runs everything" "$out" "ran-slowpoke"

printf '#!/usr/bin/env bash\nexit 1\n' > "$tree/scripts/tests/broken.test.sh"
"$runner" --fast >/dev/null 2>&1; assert_rc "a failing test fails the run" 1 $?

assert_contains "help documents the fast tier" "$("$runner" --help)" "--fast"
"$runner" --bogus >/dev/null 2>&1; assert_rc "unknown flag is a usage error" 2 $?
finish
