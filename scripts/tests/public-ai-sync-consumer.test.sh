#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib.sh"
root="$(cd "$here/../.." && pwd)"
consumer="$root/test-consumer"
pkg="$root/packages/public-ai-sync"
new_tmp
later="$TMPROOT/later"

rm -rf "$consumer/.public-ai" "$consumer/node_modules"
(
  cd "$consumer"
  npm install --no-package-lock --no-fund --no-audit
) >"$TMPROOT/npm-install.log" 2>&1
assert_rc "npm install in test-consumer" 0 $?
assert_eq "AGENTS.md landed" "$(cat "$consumer/ai-source/AGENTS.md")" "$(cat "$consumer/.public-ai/AGENTS.md")"
assert_eq "rules landed" "$(cat "$consumer/ai-source/rules/sample.md")" "$(cat "$consumer/.public-ai/rules/sample.md")"
[ -f "$consumer/.public-ai/skills/demo/SKILL.md" ] && ok || bad "skills/demo/SKILL.md missing"
grep -qxF '.public-ai/' "$consumer/.gitignore" && ok || bad "gitignore missing .public-ai/"

cp -a "$consumer/ai-source" "$later"
printf 'later-body\n' >"$later/rules/sample.md"
printf 'extra-body\n' >"$later/rules/extra.md"
rm -rf "$later/skills"
(
  cd "$consumer"
  PUBLIC_AI_SYNC_SOURCE="$later" node "$pkg/bin/sync.mjs"
) >"$TMPROOT/resync.log" 2>&1
assert_rc "second sync" 0 $?
assert_eq "sample replaced" "later-body" "$(tr -d '\n' <"$consumer/.public-ai/rules/sample.md")"
assert_eq "extra landed" "extra-body" "$(tr -d '\n' <"$consumer/.public-ai/rules/extra.md")"
[ ! -e "$consumer/.public-ai/skills/demo/SKILL.md" ] && ok || bad "stale skill remained"

finish
