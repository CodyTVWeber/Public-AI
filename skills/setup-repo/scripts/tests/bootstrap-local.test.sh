#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/fixtures.sh"
new_tmp
unset PUBLIC_AI_DIR

clone="$TMPROOT/clone"; mkdir -p "$clone"; clone="$(cd "$clone" && pwd -P)"
fake_clone "$clone" write-plan implement review watch plan-implement-review-watch align plan-implement-review verify-change monitor review-plan review-logic review-non-happy-logic review-tests review-security review-data review-ui review-dependencies review-infra review-concurrency review-code-quality review-proof
apply() { local t="$1"; shift; "$BOOTSTRAP" "$t" --apply --yes --skills-from "$clone" "$@" 2>/dev/null; }
status_of() { jq -r --arg id "$2" '.checks[] | select(.id == $id) | .status' <<<"$1"; }

a="$TMPROOT/local"; js_husky_gitlab "$a"
git -C "$a" config --local --unset core.hooksPath 2>/dev/null
rm -rf "$a/.husky"; commit_all "$a" "drop husky"
tracked_before="$(git -C "$a" ls-files | sort | cksum)"
out="$(apply "$a" --profile local)"; assert_rc "local apply ok" 0 $?
assert_eq "no step failed" "0" "$(summary "$out" failed)"
assert_eq "git status is empty after a local apply" "" "$(git -C "$a" status --porcelain --untracked-files=all)"
assert_eq "tracked files unchanged" "$tracked_before" "$(git -C "$a" ls-files | sort | cksum)"
assert_eq "AGENTS.md content unchanged" "# Rules" "$(head -1 "$a/AGENTS.md")"
assert_not_contains "AGENTS.md has no guardrails section" "$(cat "$a/AGENTS.md")" "ai-guardrails"
[ -e "$a/.claude/settings.json" ] && bad "settings.json untouched" || ok
[ -e "$a/CLAUDE.md" ] && bad "no CLAUDE.md pointer" || ok
assert_eq "hooks land in settings.local.json" "true" "$(jq -r '[.hooks.PostToolUse[].hooks[].command] | any(endswith("post-git-check.sh"))' "$a/.claude/settings.local.json")"
assert_eq "every registered hook has a timeout" "true" "$(jq -r '[.hooks[][].hooks[] | has("timeout")] | all' "$a/.claude/settings.local.json")"
assert_contains "note goes to the git dir" "$(cat "$a/.git/info/local-guardrails.md")" "## AI guardrails"
assert_eq "record mode is local" "local" "$(jq -r .mode "$a/.git/info/local-guardrails.json")"
[ -e "$a/.claude/ai-guardrails.json" ] && bad "no tracked-path record" || ok
assert_eq "hooksPath never set" "" "$(git -C "$a" config --local --get core.hooksPath || true)"
[ -x "$a/.git/hooks/pre-commit" ] && [ -x "$a/.git/hooks/pre-push" ] && ok || bad "git hooks live in .git/hooks"
[ -e "$a/.githooks" ] && bad "no .githooks directory" || ok
assert_contains "installed scripts excluded" "$(cat "$a/.git/info/exclude")" "scripts/clean-code/"
assert_contains "rules excluded per file" "$(cat "$a/.git/info/exclude")" ".claude/rules/clean-code.md"
assert_contains "workbench ban excluded per file" "$(cat "$a/.git/info/exclude")" ".claude/rules/ban-workbenches.md"
assert_contains "settings.local.json excluded" "$(cat "$a/.git/info/exclude")" ".claude/settings.local.json"
assert_contains "skill links excluded" "$(cat "$a/.git/info/exclude")" ".claude/skills/review"
assert_eq "skills linked as usual" "$clone/skills/review" "$(readlink "$a/.claude/skills/review")"

out="$(apply "$a" --profile local)"
assert_eq "re-apply creates nothing" "" "$(jq -r '[.steps[] | select(.action == "create") | .id] | join(" ")' <<<"$out")"
assert_eq "re-apply merges nothing" "0" "$(summary "$out" merge)"
assert_eq "git status stays empty" "" "$(git -C "$a" status --porcelain --untracked-files=all)"

printf 'export const ok = 1;\n' > "$a/ok.ts"; git -C "$a" add -- ok.ts
git -C "$a" commit -q -m ok >/dev/null 2>&1; assert_rc "local hooks let a clean commit through" 0 $?
printf 'export const bad = 1;\n// note\n' > "$a/bad.ts"; git -C "$a" add -- bad.ts
git -C "$a" commit -q -m bad >/dev/null 2>&1; assert_rc "local hooks block an added comment" 1 $?
git -C "$a" reset -q; rm -f "$a/bad.ts"

json="$("$VERIFY" "$a" 2>/dev/null)"; assert_rc "local fixture verifies" 0 $?
assert_eq "verify reports local mode" "local" "$(jq -r .mode <<<"$json")"
for id in scripts git-hooks settings hook-scripts analyzer skills agents-doc local-clean drift; do
  assert_eq "$id passes" "pass" "$(status_of "$json" "$id")"
done
rm "$a/.git/info/exclude"
json="$("$VERIFY" "$a" 2>/dev/null)"; assert_rc "unexcluded installed paths fail" 1 $?
assert_eq "local-clean fails" "fail" "$(status_of "$json" local-clean)"

b="$TMPROOT/hookspath"; go_bare "$b"; git -C "$b" config core.hooksPath shared-hooks
json="$("$BOOTSTRAP" "$b" --plan --local --skills none 2>/dev/null)"
assert_eq "foreign hooksPath is a manual step" "manual" "$(step_action "$json" git-hooks)"
apply "$b" --local --skills none >/dev/null
assert_eq "hooksPath kept" "shared-hooks" "$(git -C "$b" config --local core.hooksPath)"
[ -e "$b/.git/hooks/pre-commit" ] && bad "nothing in .git/hooks when it would not run" || ok

c="$TMPROOT/alias"; go_bare "$c"
json="$("$BOOTSTRAP" "$c" --plan --local --skills none 2>/dev/null)"
assert_eq "--local selects the local profile" "local" "$(jq -r .profile <<<"$json")"
"$BOOTSTRAP" "$c" --plan --local --with ci >/dev/null 2>&1; assert_rc "ci is refused in local" 2 $?
"$BOOTSTRAP" "$c" --plan --local --profile factory >/dev/null 2>&1; assert_rc "--local conflicts with another profile" 2 $?
json="$("$BOOTSTRAP" "$c" --plan --profile local --with approval-gate,privacy --skills none 2>/dev/null)"
assert_contains "add-on files are planned" "$(step_ids "$json")" "approval-gate"
apply "$c" --profile local --with approval-gate,privacy,research-ref --skills none >/dev/null
assert_eq "add-ons leave git status empty" "" "$(git -C "$c" status --porcelain --untracked-files=all)"
assert_contains "add-on file excluded" "$(cat "$c/.git/info/exclude")" "scripts/guard/git-approval-guard.sh"
finish
