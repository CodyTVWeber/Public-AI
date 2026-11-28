#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib.sh"
root="$(cd "$here/../.." && pwd)"
consumer="$root/test-consumer"
pkg="$root/packages/public-ai-sync"
new_tmp
later="$TMPROOT/later"
pkg_bak="$(cat "$consumer/package.json")"
gi_bak="$(cat "$consumer/.gitignore")"

cleanup_consumer() {
  printf '%s\n' "$pkg_bak" > "$consumer/package.json"
  printf '%s\n' "$gi_bak" > "$consumer/.gitignore"
  rm -rf "$consumer/.public-ai" "$consumer/node_modules"
  rm -rf "$consumer/rules" "$consumer/skills" "$consumer/.claude" "$consumer/scripts" "$consumer/AI-setup"
  rm -f "$consumer/AGENTS.md" "$consumer/CLAUDE.md" "$consumer/GEMINI.md" "$consumer/PRIVACY.md"
  rm -f "$consumer/.func-size" "$consumer/.mr-size"
  rm -rf "$TMPROOT"
}
trap cleanup_consumer EXIT

rm -rf "$consumer/.public-ai" "$consumer/node_modules"
(
  cd "$consumer"
  npm install --no-package-lock --no-fund --no-audit
) >"$TMPROOT/npm-install.log" 2>&1
assert_rc "npm install in test-consumer" 0 $?
assert_eq "AGENTS.md landed" "$(cat "$consumer/ai-source/AGENTS.md")" "$(cat "$consumer/.public-ai/AGENTS.md")"
assert_eq "rules landed" "$(cat "$consumer/ai-source/rules/sample.md")" "$(cat "$consumer/.public-ai/rules/sample.md")"
[ -f "$consumer/.public-ai/skills/demo/SKILL.md" ] && ok || bad "skills/demo/SKILL.md missing"
[ -f "$consumer/.public-ai/scripts/lint/hello.sh" ] && ok || bad "scripts/lint missing from target"
grep -qxF '.public-ai/' "$consumer/.gitignore" && ok || bad "gitignore missing .public-ai/"
[ -L "$consumer/AGENTS.md" ] && ok || bad "AGENTS.md not linked at consumer root"
assert_eq "AGENTS.md link" ".public-ai/AGENTS.md" "$(readlink "$consumer/AGENTS.md")"
[ -d "$consumer/scripts" ] && [ ! -L "$consumer/scripts" ] && ok || bad "scripts should be a real directory"
[ -L "$consumer/scripts/lint" ] && ok || bad "scripts/lint not linked"
[ -L "$consumer/.claude" ] && ok || bad ".claude not linked"
grep -qxF 'scripts/lint/' "$consumer/.gitignore" && ok || bad "gitignore missing scripts/lint/"
grep -F '"public-ai:code-quality"' "$consumer/package.json" >/dev/null && ok || bad "npm script public-ai:code-quality missing"

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
