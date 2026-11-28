#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/fixtures.sh"
new_tmp

mkdir -p "$TMPROOT/clone"
clone="$(cd "$TMPROOT/clone" && pwd -P)"
fake_clone "$clone" write-plan implement review watch ai-risk setup-repo
mkdir -p "$clone/skills/nameless"
plan() { local t="$1"; shift; "$BOOTSTRAP" "$t" --plan --skills-from "$clone" "$@" 2>/dev/null; }
apply() { local t="$1"; shift; "$BOOTSTRAP" "$t" --apply --yes --skills-from "$clone" "$@" 2>/dev/null; }
tree_hash() { (cd "$1" && find . -type f -not -path './.git/*' | sort | while IFS= read -r f; do cksum "$f"; done); }

a="$TMPROOT/plain"; go_bare "$a"
before="$(tree_hash "$a")"
json="$("$BOOTSTRAP" "$a" --skills-from "$clone" 2>/dev/null)"; assert_rc "default mode plans" 0 $?
assert_eq "default mode is plan" "plan" "$(jq -r .mode <<<"$json")"
assert_eq "plan does not apply" "false" "$(jq -r .applied <<<"$json")"
assert_eq "plan writes nothing" "$before" "$(tree_hash "$a")"
assert_eq "plan leaves hooksPath alone" "" "$(git -C "$a" config --local --get core.hooksPath || true)"
assert_eq "every step has the contract fields" "true" "$(jq -r '[.steps[] | has("id","action","path","reason")] | all' <<<"$json")"
assert_eq "actions come from the contract" "true" "$(jq -r '[.steps[].action] | all(. == "create" or . == "merge" or . == "skip" or . == "manual")' <<<"$json")"

json="$(plan "$a" --profile minimal)"
assert_eq "minimal steps" "rules scripts git-hooks agents-doc agents-doc:pointer agents-doc:gemini manifest" "$(step_ids "$json")"
json="$(plan "$a")"
assert_eq "standard steps" "rules scripts git-hooks claude-hooks post-git-hook skills agents-doc agents-doc:pointer agents-doc:gemini manifest" "$(step_ids "$json")"
assert_eq "standard has no ci step" "" "$(step_action "$json" ci)"
assert_contains "no-pipeline note" "$(jq -r '.notes | join(" ")' <<<"$json")" "No pipeline jobs installed: local and Claude hooks are the guardrails"
json="$(plan "$a" --profile factory)"
assert_contains "factory has ai-risk" "$(step_ids "$json")" "ai-risk:policy"
assert_contains "factory has the pr template" "$(step_ids "$json")" "pr-template"
assert_not_contains "factory has no approval gate" "$(step_ids "$json")" "approval-gate"
assert_eq "factory without a forge asks for a manual ci step" "manual" "$(step_action "$json" ci)"
assert_contains "ci control note" "$(jq -r '.notes | join(" ")' <<<"$json")" "a PR cannot silently delete"
json="$(plan "$a" --profile minimal --with approval-gate,privacy,research-ref)"
assert_contains "add-ons via --with" "$(step_ids "$json")" "approval-gate"
assert_contains "privacy add-on" "$(step_ids "$json")" "privacy:check-privacy.sh"
assert_eq "without removes a feature" "false" "$(jq -r '.features | index("agents-doc") != null' <<<"$(plan "$a" --without agents-doc)")"
assert_contains "agents-doc opt-out is named" "$(jq -r '.notes | join(" ")' <<<"$(plan "$a" --without agents-doc)")" "without the AGENTS section"

"$BOOTSTRAP" "$a" --profile bogus >/dev/null 2>&1; assert_rc "bad profile is usage" 2 $?
"$BOOTSTRAP" "$a" --with nonsense >/dev/null 2>&1; assert_rc "unknown feature is usage" 2 $?
"$BOOTSTRAP" "$TMPROOT/nope" >/dev/null 2>&1; assert_rc "missing target is precondition" 3 $?
"$BOOTSTRAP" "$TMPROOT" >/dev/null 2>&1; assert_rc "non-repo target is precondition" 3 $?
"$BOOTSTRAP" --help >/dev/null 2>&1; assert_rc "help" 0 $?
printf 'dirty\n' > "$a/scratch.txt"
"$BOOTSTRAP" "$a" --apply --skills-from "$clone" >/dev/null 2>&1; assert_rc "apply on a dirty tree needs --yes" 3 $?
rm "$a/scratch.txt"

out="$(apply "$a")"; assert_rc "apply ok" 0 $?
assert_eq "apply reports applied" "true" "$(jq -r .applied <<<"$out")"
assert_eq "no step failed" "0" "$(summary "$out" failed)"
assert_eq "hooksPath set" ".githooks" "$(git -C "$a" config --local core.hooksPath)"
for f in .claude/rules/clean-code.md .claude/rules/ban-workbenches.md scripts/clean-code/post-git-check.sh scripts/clean-code/gitscan/cli.mjs .githooks/pre-push .claude/settings.json .claude/ai-guardrails.json AGENTS.md CLAUDE.md GEMINI.md; do
  [ -e "$a/$f" ] && ok || bad "applied $f"
done
assert_eq "pointer CLAUDE.md" "@AGENTS.md" "$(cat "$a/CLAUDE.md")"
assert_eq "pointer GEMINI.md" "@AGENTS.md" "$(cat "$a/GEMINI.md")"
assert_eq "skills linked with absolute paths" "$clone/skills/review" "$(readlink "$a/.claude/skills/review")"
assert_contains "each link has its own exclude entry" "$(cat "$a/.git/info/exclude")" ".claude/skills/review"
assert_not_contains "no directory-wide exclude hides team skills" "$(cat "$a/.git/info/exclude")" ".claude/skills/"$'\n'
[ -e "$a/.claude/skills/nameless" ] && bad "skill without SKILL.md is skipped" || ok
assert_contains "links stay local" "$(cat "$a/.git/info/exclude")" ".claude/skills/"
assert_eq "settings registers the git check" "true" "$(jq -r '[.hooks.PostToolUse[] | select(.matcher == "Bash") | .hooks[].command] | any(endswith("post-git-check.sh"))' "$a/.claude/settings.json")"
assert_eq "agents section once" "1" "$(grep -c 'ai-guardrails:begin' "$a/AGENTS.md")"
assert_contains "no-ci line in the guardrails section" "$(cat "$a/AGENTS.md")" "No pipeline jobs installed: local and Claude hooks are the guardrails"
assert_contains "while-editing line in the guardrails section" "$(cat "$a/AGENTS.md")" "While editing"
assert_contains "guardrails section names the workbench ban" "$(cat "$a/AGENTS.md")" "ban-workbenches"
assert_contains "while-editing forbids workbenches" "$(cat "$a/AGENTS.md")" "no workbenches"
assert_not_contains "section records no absolute home path" "$(cat "$a/AGENTS.md")" "$clone"
assert_contains "section names the skills source variable" "$(cat "$a/AGENTS.md")" '$PUBLIC_AI_DIR'

out="$(apply "$a")"
assert_eq "second apply creates nothing" "0" "$(summary "$out" create)"
assert_eq "second apply merges nothing" "0" "$(summary "$out" merge)"
assert_eq "second apply fails nothing" "0" "$(summary "$out" failed)"
assert_eq "agents section still once" "1" "$(grep -c 'ai-guardrails:begin' "$a/AGENTS.md")"
assert_eq "tree is stable on re-apply" "$(tree_hash "$a")" "$(tree_hash "$a")"

printf 'export const ok = 1;\n' > "$a/ok.ts"; git -C "$a" add -- ok.ts
git -C "$a" commit -q -m 'add ok' >/dev/null 2>&1; assert_rc "hooks let a clean commit through" 0 $?
printf 'export const bad = 1;\n// note\n' > "$a/bad.ts"; git -C "$a" add -- bad.ts
git -C "$a" commit -q -m 'add bad' >/dev/null 2>&1; assert_rc "hooks block an added comment" 1 $?
git -C "$a" reset -q
rm -f "$a/bad.ts"

printf 'mine\n' > "$a/.claude/rules/ban-comments.md"
out="$(plan "$a")"
assert_eq "differing rule is manual" "manual" "$(step_action "$out" "rules:.claude/rules/ban-comments.md")"
apply "$a" >/dev/null
assert_eq "differing rule kept" "mine" "$(cat "$a/.claude/rules/ban-comments.md")"
apply "$a" --force >/dev/null
assert_contains "force overwrites" "$(cat "$a/.claude/rules/ban-comments.md")" "comment"

f="$TMPROOT/foreign"; go_bare "$f"
printf '#!/bin/sh\ntouch "%s/foreign-ran"\nexit 0\n' "$TMPROOT" > "$f/.git/hooks/pre-commit"; chmod +x "$f/.git/hooks/pre-commit"
json="$(plan "$f")"
assert_eq "foreign hook plan chains" "merge" "$(step_action "$json" git-hooks:pre-commit)"
apply "$f" >/dev/null
assert_eq "hooksPath untouched over a foreign hook" "" "$(git -C "$f" config --local --get core.hooksPath || true)"
[ -x "$f/.git/hooks/pre-commit.bak" ] && ok || bad "foreign hook kept as .bak"
printf 'export const k = 1;\n' > "$f/k.ts"; git -C "$f" add -- k.ts
git -C "$f" commit -q -m k >/dev/null 2>&1; assert_rc "chained hooks pass" 0 $?
[ -e "$TMPROOT/foreign-ran" ] && ok || bad "foreign hook still runs"
printf 'export const k2 = 1;\n// note\n' > "$f/k2.ts"; git -C "$f" add -- k2.ts
git -C "$f" commit -q -m k2 >/dev/null 2>&1; assert_rc "chained hooks block comments" 1 $?
out="$(apply "$f")"; assert_eq "native re-apply creates nothing" "0" "$(summary "$out" create)"
assert_eq "native re-apply merges nothing" "0" "$(summary "$out" merge)"

h="$TMPROOT/hookspath"; go_bare "$h"; git -C "$h" config core.hooksPath other-hooks
json="$(plan "$h")"
assert_eq "foreign hooksPath is a manual step" "manual" "$(step_action "$json" git-hooks)"
apply "$h" >/dev/null
assert_eq "foreign hooksPath kept" "other-hooks" "$(git -C "$h" config --local core.hooksPath)"

p="$TMPROOT/pointer"; new_fixture "$p"
printf '# Team rules\n\nBe kind.\n' > "$p/AGENTS.md"; printf '@AGENTS.md\n' > "$p/CLAUDE.md"; commit_all "$p"
apply "$p" >/dev/null
assert_eq "existing pointer untouched" "@AGENTS.md" "$(cat "$p/CLAUDE.md")"
assert_eq "missing GEMINI.md redirect added" "@AGENTS.md" "$(cat "$p/GEMINI.md")"
assert_contains "existing rules kept" "$(cat "$p/AGENTS.md")" "Be kind."
assert_contains "section appended" "$(cat "$p/AGENTS.md")" "## AI guardrails"
assert_eq "section is current after re-apply" "skip" "$(step_action "$(plan "$p")" agents-doc)"

c="$TMPROOT/claude"; new_fixture "$c"
printf '# Project notes\n\nReal content.\n' > "$c/CLAUDE.md"; commit_all "$c"
apply "$c" >/dev/null
assert_contains "real CLAUDE.md gets the section when no AGENTS.md exists" "$(cat "$c/CLAUDE.md")" "ai-guardrails:begin"
[ -e "$c/AGENTS.md" ] && bad "no AGENTS.md created beside a real CLAUDE.md" || ok
[ -e "$c/GEMINI.md" ] && bad "no GEMINI.md redirect beside a real CLAUDE.md" || ok

j="$TMPROOT/husky"; js_husky_gitlab "$j"
json="$(plan "$j" --without skills)"
assert_eq "auto picks husky" "husky" "$(jq -r .hooks_via <<<"$json")"
assert_eq "husky pre-commit is merged" "merge" "$(step_action "$json" git-hooks:pre-commit)"
assert_eq "husky pre-push is created" "create" "$(step_action "$json" git-hooks:pre-push)"
apply "$j" --without skills >/dev/null
assert_contains "husky keeps its own line" "$(cat "$j/.husky/pre-commit")" "npx lint-staged"
assert_contains "husky gets the clean-code call" "$(cat "$j/.husky/pre-commit")" "scripts/clean-code/check-clean-code.sh"
assert_contains "husky pre-push gets the gate" "$(cat "$j/.husky/pre-push")" "scripts/clean-code/pre-push-gate.sh"
assert_eq "husky leaves hooksPath alone" "" "$(git -C "$j" config --local --get core.hooksPath || true)"
assert_eq "husky call added once" "1" "$(grep -c 'check-clean-code.sh' "$j/.husky/pre-commit")"
assert_eq "ci stays off for standard" "" "$(step_action "$(plan "$j")" ci)"
assert_eq "existing gitlab ci untouched in standard" "stages:" "$(head -1 "$j/.gitlab-ci.yml")"

k="$TMPROOT/gitlab"; js_husky_gitlab "$k"
json="$(plan "$k" --with ci --without skills)"
assert_eq "gitlab job file planned" "create" "$(step_action "$json" ci)"
assert_eq "include merge planned" "merge" "$(step_action "$json" ci:include)"
apply "$k" --with ci --without skills >/dev/null
assert_contains "job file calls the installed scripts" "$(cat "$k/.gitlab/ci/ai-guardrails.yml")" "scripts/clean-code/code-quality-check.sh --changed"
assert_contains "stage resolved from the repo" "$(cat "$k/.gitlab/ci/ai-guardrails.yml")" "stage: test"
assert_contains "include added after the existing one" "$(sed -n '/^include:/,/^$/p' "$k/.gitlab-ci.yml")" "  - local: .gitlab/ci/ai-guardrails.yml"
assert_contains "existing include kept" "$(cat "$k/.gitlab-ci.yml")" "local: ci/base.yml"
assert_contains "agents section names the job file" "$(cat "$k/AGENTS.md")" ".gitlab/ci/ai-guardrails.yml"
assert_not_contains "agents section drops the no-ci line" "$(cat "$k/AGENTS.md")" "No pipeline jobs installed"
out="$(apply "$k" --with ci --without skills)"
assert_eq "ci re-apply merges nothing" "0" "$(summary "$out" merge)"
assert_eq "ci re-apply creates nothing" "0" "$(summary "$out" create)"
assert_eq "include listed once" "1" "$(grep -c 'ai-guardrails.yml' "$k/.gitlab-ci.yml")"

g="$TMPROOT/gitlab-fresh"; new_fixture "$g" "$GITLAB_REMOTE"; printf 'x\n' > "$g/a.txt"; commit_all "$g"
apply "$g" --with ci --without skills >/dev/null
assert_eq "minimal gitlab ci created" "include:" "$(head -1 "$g/.gitlab-ci.yml")"
s="$TMPROOT/gitlab-scalar"; new_fixture "$s" "$GITLAB_REMOTE"; printf 'include: other.yml\n' > "$s/.gitlab-ci.yml"; commit_all "$s"
assert_eq "scalar include is manual" "manual" "$(step_action "$(plan "$s" --with ci)" ci:include)"

gh="$TMPROOT/github"; python_precommit_github "$gh"
json="$(plan "$gh" --profile factory --without skills)"
assert_eq "factory github workflow" "create" "$(step_action "$json" ci)"
assert_eq "factory github hooks via precommit is manual" "manual" "$(step_action "$json" git-hooks)"
assert_contains "pre-commit snippet is exact" "$(jq -r '.steps[] | select(.id == "git-hooks") | .snippet' <<<"$json")" "entry: scripts/clean-code/check-clean-code.sh"
apply "$gh" --profile factory --without skills >/dev/null
assert_eq "own workflow written" "ai-guardrails" "$(sed -n 1p "$gh/.github/workflows/ai-guardrails.yml" | sed 's/name: //')"
assert_eq "existing workflow untouched" "name: ci" "$(head -1 "$gh/.github/workflows/ci.yml")"
assert_eq "pre-commit config untouched" "repos: []" "$(cat "$gh/.pre-commit-config.yaml")"
assert_contains "pr template for github" "$(cat "$gh/.github/pull_request_template.md")" "## Review guide"
assert_contains "pr body check runs in ci" "$(cat "$gh/.github/workflows/ai-guardrails.yml")" "check-pr-body.sh"
assert_eq "ai-risk policy is conservative" "Merge policy: conservative" "$(grep '^Merge policy:' "$gh/docs/rules/ai-merge-policy.md")"
[ -x "$gh/scripts/ai-risk/classify-tier.sh" ] && ok || bad "ai-risk scripts installed"
assert_eq "ai-risk scripts run" "conservative" "$(cd "$gh" && scripts/ai-risk/merge-policy.sh | jq -r .profile)"
assert_eq "factory has no approval gate in settings" "false" "$(jq -r '[.. | .command? // empty] | any(contains("git-approval-guard"))' "$gh/.claude/settings.json")"

m="$TMPROOT/gate"; go_bare "$m"
apply "$m" --with approval-gate,privacy,research-ref --without skills >/dev/null
assert_eq "approval gate registered" "true" "$(jq -r '[.hooks.PreToolUse[].hooks[].command] | any(endswith("git-approval-guard.sh"))' "$m/.claude/settings.json")"
assert_eq "research ref registered" "true" "$(jq -r '[.hooks.SessionStart[].hooks[].command] | any(contains("research-ref.sh"))' "$m/.claude/settings.json")"
assert_contains "approval wording in the section" "$(cat "$m/AGENTS.md")" "Commit and ship"
[ -x "$m/scripts/check-privacy.sh" ] && ok || bad "privacy gate installed"
assert_contains "privacy script reads the local patterns file" "$(cat "$m/scripts/check-privacy.sh")" "info/privacy-patterns"
[ -x "$m/scripts/lint/check-languages.sh" ] && ok || bad "language check installed"
assert_eq "privacy patterns manual step is listed" "manual" "$(step_action "$(plan "$m" --with privacy)" privacy:patterns)"
assert_contains "patterns step names the strict switch" "$(plan "$m" --with privacy | jq -r '.steps[] | select(.id == "privacy:patterns") | .reason')" "PRIVACY_REQUIRE_PATTERNS=1"
decision="$(jq -nc --arg c 'git push' '{tool_name:"Bash",tool_input:{command:$c}}' | (cd "$m" && scripts/guard/git-approval-guard.sh) | jq -r '.hookSpecificOutput.permissionDecision')"
assert_eq "installed approval gate asks on push" "ask" "$decision"

q="$TMPROOT/privacy-chain"; go_bare "$q"
mkdir -p "$q/scripts"; cp "$SCRIPTS/../../../scripts/check-privacy.sh" "$q/scripts/"; commit_all "$q" privacy
apply "$q" --without skills >/dev/null
ticket="AB""C-12"
printf 'see %s\n' "$ticket" > "$q/net.txt"; git -C "$q" add -- net.txt
git -C "$q" commit -q -m net >/dev/null 2>&1; assert_rc "existing privacy gate runs first in the git hook" 1 $?
git -C "$q" reset -q
qh="$TMPROOT/privacy-husky"; js_husky_gitlab "$qh"
mkdir -p "$qh/scripts"; cp "$SCRIPTS/../../../scripts/check-privacy.sh" "$qh/scripts/"; commit_all "$qh" privacy
apply "$qh" --without skills >/dev/null
assert_contains "husky chains the privacy gate" "$(cat "$qh/.husky/pre-commit")" "scripts/check-privacy.sh"
assert_contains "husky checks the commit message" "$(cat "$qh/.husky/commit-msg")" "check-privacy.sh --message"

n="$TMPROOT/nopython-skills"; go_bare "$n"
out="$("$BOOTSTRAP" "$n" --apply --yes --skills-from "$TMPROOT/no-such-clone" 2>/dev/null)"
assert_eq "missing clone is a manual skills step" "manual" "$(step_action "$out" skills)"

link_out="$("$LINK" "$n" --skills-from "$clone" --skills core 2>/dev/null)"; assert_rc "link-skills ok" 0 $?
assert_eq "link-skills reports links" "create" "$(jq -r '.links[] | select(.name == "review") | .status' <<<"$link_out")"
assert_contains "link-skills warns on a name with no skill" "$(jq -r '.warnings | join(" ")' <<<"$link_out")" "skipped plan-implement-review-watch"
assert_eq "link-skills is idempotent" "same" "$(jq -r '.links[] | select(.name == "review") | .status' <<<"$("$LINK" "$n" --skills-from "$clone" 2>/dev/null)")"
all_out="$("$LINK" "$n" --skills-from "$clone" --skills all 2>/dev/null)"
assert_eq "all links every skill with a SKILL.md" "6" "$(jq -r '[.links[] | select(.status != "skipped")] | length' <<<"$all_out")"
"$LINK" "$n" --skills-from "$TMPROOT/nowhere" >/dev/null 2>&1; assert_rc "link-skills without a clone" 3 $?
"$LINK" >/dev/null 2>&1; assert_rc "link-skills usage" 2 $?
finish
