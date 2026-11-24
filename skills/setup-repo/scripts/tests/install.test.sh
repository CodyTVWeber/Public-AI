#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/../../../../scripts/tests/lib.sh"
new_tmp

install="$here/../install.sh"

mk() {
  new_repo "$1"
  printf 'x\n' > "$1/f.txt"
  git -C "$1" add -- .
  git -C "$1" commit -qm base
}

a="$TMPROOT/a"; mk "$a"
out="$("$install" "$a" 2>&1)"; assert_rc "default install ok" 0 $?
for f in .claude/rules/ban-comments.md .claude/rules/docs-current-or-dated.md scripts/clean-code/check-clean-code.sh scripts/clean-code/lint-docs.sh .githooks/pre-commit; do
  [ -e "$a/$f" ] && ok || bad "installed $f"
done
assert_eq "hooksPath set" ".githooks" "$(git -C "$a" config --local core.hooksPath)"
assert_contains "claude hooks wired" "$(cat "$a/.claude/settings.json")" "lint-docs.sh --hook"
assert_contains "pre-tool guard wired" "$(cat "$a/.claude/settings.json")" "claude-pre-tool-guard.sh"
assert_contains "snippet in CLAUDE.md" "$(cat "$a/CLAUDE.md")" "## Clean code and small MRs"
for f in scripts/clean-code/code-quality-check.sh scripts/clean-code/cleancode/cli.py scripts/clean-code/cleancode/lexer.py; do
  [ -e "$a/$f" ] && ok || bad "installed $f"
done
[ -x "$a/scripts/clean-code/code-quality-check.sh" ] && ok || bad "analyzer wrapper executable"
[ ! -e "$a/scripts/clean-code/cleancode/__pycache__" ] && ok || bad "no bytecode written"
assert_eq "PostToolUse analyzer matcher" '"Write|Edit|MultiEdit"' "$(jq -c '.hooks.PostToolUse[] | select(.hooks[].command | endswith("code-quality-check.sh --hook")) | .matcher' "$a/.claude/settings.json")"
assert_contains "Stop hook wired" "$(cat "$a/.claude/settings.json")" "code-quality-check.sh --stop-hook"
assert_contains "post-git hook wired on Bash" "$(jq -c '[.hooks.PostToolUse[] | select(.matcher == "Bash") | .hooks[].command]' "$a/.claude/settings.json")" "post-git-check.sh"
assert_eq "Stop group has no matcher" "null" "$(jq -c '.hooks.Stop[0].matcher' "$a/.claude/settings.json")"
assert_contains "installed analyzer runs" "$(cd "$a" && scripts/clean-code/code-quality-check.sh --list-rules)" "param-count"
printf 'export const x = 1;\n// note\n' > "$a/probe.ts"
(cd "$a" && jq -nc --arg f "$a/probe.ts" '{tool_input:{file_path:$f},cwd:"."}' | scripts/clean-code/code-quality-check.sh --hook >/dev/null 2>&1); assert_rc "installed hook blocks an added comment" 2 $?
rm "$a/probe.ts"

out="$("$install" "$a" 2>&1)"; assert_rc "reinstall ok" 0 $?
assert_eq "snippet appended once" "1" "$(grep -c '## Clean code and small MRs' "$a/CLAUDE.md")"
assert_eq "PostToolUse hooks registered once" "3" "$(jq '[.hooks.PostToolUse[].hooks[]] | length' "$a/.claude/settings.json")"
assert_eq "Stop hook registered once" "1" "$(jq '[.hooks.Stop[].hooks[]] | length' "$a/.claude/settings.json")"

b="$TMPROOT/b"; mk "$b"
printf '# Rules\n' > "$b/AGENTS.md"
printf '@AGENTS.md\n' > "$b/CLAUDE.md"
out="$("$install" "$b" --no-githooks 2>&1)"; assert_rc "no-githooks install ok" 0 $?
[ -e "$b/.githooks" ] && bad "githooks skipped" ".githooks exists" || ok
assert_eq "hooksPath untouched" "" "$(git -C "$b" config --local --get core.hooksPath || true)"
assert_contains "snippet in AGENTS.md" "$(cat "$b/AGENTS.md")" "## Clean code and small MRs"
assert_eq "pointer CLAUDE.md untouched" "@AGENTS.md" "$(cat "$b/CLAUDE.md")"

c="$TMPROOT/c"; mk "$c"
out="$("$install" "$c" --no-claude-hook 2>&1)"; assert_rc "no-claude-hook install ok" 0 $?
[ -e "$c/.claude/settings.json" ] && bad "claude hooks skipped" "settings.json exists" || ok

d="$TMPROOT/d"; mk "$d"
mkdir -p "$d/.claude"
cat > "$d/.claude/settings.json" <<'JSON'
{"permissions":{"allow":["Bash(ls)"]},"hooks":{"PostToolUse":[{"matcher":"Write|Edit|MultiEdit","hooks":[{"type":"command","command":"echo mine"}]}],"Stop":[{"hooks":[{"type":"command","command":"echo done"}]}]}}
JSON
out="$("$install" "$d" --no-rules --no-githooks 2>&1)"; assert_rc "no-rules install ok" 0 $?
[ -e "$d/.claude/rules" ] && bad "no-rules skips rules" ".claude/rules exists" || ok
[ -e "$d/scripts/clean-code/cleancode/cli.py" ] && ok || bad "no-rules still installs the analyzer"
assert_eq "existing permissions kept" '["Bash(ls)"]' "$(jq -c '.permissions.allow' "$d/.claude/settings.json")"
assert_eq "existing PostToolUse hook kept and merged into its group" '["echo mine","\"$CLAUDE_PROJECT_DIR\"/scripts/clean-code/code-quality-check.sh --hook"]' "$(jq -c '[.hooks.PostToolUse[] | select(.matcher == "Write|Edit|MultiEdit") | .hooks[].command]' "$d/.claude/settings.json")"
assert_eq "existing Stop hook kept and merged into its group" '["echo done","\"$CLAUDE_PROJECT_DIR\"/scripts/clean-code/code-quality-check.sh --stop-hook"]' "$(jq -c '[.hooks.Stop[0].hooks[].command]' "$d/.claude/settings.json")"
"$install" "$d" --no-rules --no-githooks >/dev/null 2>&1
assert_eq "merge is idempotent" "2" "$(jq '[.hooks.Stop[0].hooks[]] | length' "$d/.claude/settings.json")"

e="$TMPROOT/e"; mk "$e"
json="$("$install" "$e" --dry-run 2>/dev/null)"; assert_rc "dry run ok" 0 $?
assert_eq "dry run flag in JSON" "true" "$(jq -r '.dry_run' <<<"$json")"
assert_eq "dry run lists files as create" "true" "$(jq -r '[.files[].status] | all(. == "create")' <<<"$json")"
assert_eq "dry run reports settings merge" "create" "$(jq -r '.settings.status' <<<"$json")"
[ -e "$e/scripts" ] || [ -e "$e/.claude" ] || [ -e "$e/.githooks" ] && bad "dry run writes nothing" "found files" || ok
assert_eq "dry run leaves hooksPath alone" "" "$(git -C "$e" config --local --get core.hooksPath || true)"
json="$("$install" "$e" 2>/dev/null)"
assert_eq "stdout is one JSON object" "object" "$(jq -r 'type' <<<"$json")"
assert_eq "second run reports same" "true" "$(jq -r '[.files[].status] | all(. == "same")' <<<"$("$install" "$e" 2>/dev/null)")"

f="$TMPROOT/f"; mk "$f"
"$install" "$f" --no-post-git --no-doc --no-githooks >/dev/null 2>&1
assert_not_contains "no-post-git leaves the hook out" "$(cat "$f/.claude/settings.json")" "post-git-check.sh"
[ -e "$f/CLAUDE.md" ] && bad "no-doc writes no doc" "CLAUDE.md exists" || ok
"$install" "$f" --no-githooks --claude-hooks approval-gate,research-ref >/dev/null 2>&1
assert_contains "explicit group registered" "$(cat "$f/.claude/settings.json")" "git-approval-guard.sh"
assert_contains "session group registered" "$(jq -c '.hooks.SessionStart' "$f/.claude/settings.json")" "research-ref.sh --hook"

g="$TMPROOT/g"; mk "$g"
git -C "$g" config --local core.hooksPath custom-hooks
json="$("$install" "$g" 2>/dev/null)"
assert_eq "foreign hooksPath kept" "custom-hooks" "$(git -C "$g" config --local core.hooksPath)"
assert_eq "foreign hooksPath reported" "foreign" "$(jq -r '.git_hooks.status' <<<"$json")"

h="$TMPROOT/h"; mk "$h"
mkdir -p "$h/.claude"; printf '{ not json' > "$h/.claude/settings.json"
json="$("$install" "$h" --no-githooks 2>/dev/null)"; assert_rc "invalid settings does not abort" 0 $?
assert_eq "invalid settings reported" "invalid" "$(jq -r '.settings.status' <<<"$json")"
assert_eq "invalid settings left untouched" "{ not json" "$(cat "$h/.claude/settings.json")"

printf '#!/usr/bin/env bash\necho mine\n' > "$a/scripts/clean-code/check-mr-size.sh"
json="$("$install" "$a" --no-githooks 2>/dev/null)"
assert_eq "differing file kept" "differs" "$(jq -r '.files[] | select(.path == "scripts/clean-code/check-mr-size.sh") | .status' <<<"$json")"
json="$("$install" "$a" --no-githooks --force 2>/dev/null)"
assert_eq "force overwrites" "overwrite" "$(jq -r '.files[] | select(.path == "scripts/clean-code/check-mr-size.sh") | .status' <<<"$json")"

"$install" "$TMPROOT/missing" >/dev/null 2>&1; assert_rc "non-repo target is usage error" 2 $?
"$install" "$a" --bogus >/dev/null 2>&1; assert_rc "bad flag" 2 $?

cmp -s "$here/../../assets/scripts/lint-docs.sh" "$here/../../../../scripts/lint/lint-docs.sh" && ok || bad "assets lint-docs.sh matches scripts/lint/lint-docs.sh"

finish
