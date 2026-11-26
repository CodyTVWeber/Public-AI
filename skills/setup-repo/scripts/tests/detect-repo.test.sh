#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/fixtures.sh"
new_tmp

detect() { "$DETECT" "$@" 2>/dev/null; }
field() { jq -r "$2" <<<"$1"; }

a="$TMPROOT/js"; js_husky_gitlab "$a"
json="$(detect "$a")"; assert_rc "js fixture detects" 0 $?
assert_eq "forge gitlab" "gitlab" "$(field "$json" .git.forge)"
assert_eq "default branch" "main" "$(field "$json" .git.default_branch)"
assert_eq "remote slug present" "true" "$(field "$json" .git.remote_slug_present)"
assert_eq "clean tree" "false" "$(field "$json" .git.dirty)"
assert_eq "commit count" "1" "$(field "$json" .git.commit_count)"
assert_eq "stacks" "node typescript" "$(field "$json" '[.stacks[].name] | join(" ")')"
assert_eq "package manager from lockfile" "pnpm" "$(field "$json" '.stacks[] | select(.name == "node") | .package_manager')"
assert_contains "lockfile is evidence" "$(field "$json" '.stacks[0].evidence | join(" ")')" "pnpm-lock.yaml"
assert_eq "husky detected" "husky" "$(field "$json" '.hook_systems[] | select(.name == "husky") | .name')"
assert_eq "ci provider" "gitlab" "$(field "$json" .ci.provider)"
assert_eq "gitlab includes" "ci/base.yml" "$(field "$json" '.ci.gitlab_includes | join(" ")')"
assert_eq "mr template found" ".gitlab/merge_request_templates/default.md" "$(field "$json" '.templates.gitlab_mr[0]')"
assert_eq "eslint linter" "eslint" "$(field "$json" '.linters[] | select(.name == "eslint") | .name')"
assert_eq "lint command from scripts" "pnpm run lint" "$(field "$json" .commands.lint.command)"
assert_eq "test command source" "package.json:test" "$(field "$json" .commands.test.source)"
assert_eq "build command" "pnpm run build" "$(field "$json" .commands.build.command)"
assert_eq "missing typecheck is null" "null" "$(field "$json" .commands.typecheck)"
assert_eq "loose eslint rule is a conflict" "eslint-max-params" "$(field "$json" '.conflicts[] | select(.id == "eslint-max-params") | .id')"
assert_eq "comment rule is a conflict" "comment-style-rule" "$(field "$json" '.conflicts[] | select(.id == "comment-style-rule") | .id')"
assert_eq "visibility unknown by default" "unknown" "$(field "$json" .visibility)"
assert_eq "recommend husky" "husky" "$(field "$json" .recommend.hooks_via)"
assert_contains "recommend ci with a reason" "$(field "$json" '[.recommend.flags[] | select(.flag == "--with ci") | .reason] | join(" ")')" "gitlab"
assert_eq "profile asked when ci exists" "profile" "$(field "$json" '.recommend.questions[] | select(.id == "profile") | .id')"
assert_eq "ci asked when ci exists" "ci" "$(field "$json" '.recommend.questions[] | select(.id == "ci") | .id')"

b="$TMPROOT/py"; python_precommit_github "$b"
json="$(detect "$b")"
assert_eq "github forge" "github" "$(field "$json" .git.forge)"
assert_eq "python stack" "python" "$(field "$json" '.stacks[0].name')"
assert_contains "uv lock is evidence" "$(field "$json" '.stacks[0].evidence | join(" ")')" "uv.lock"
assert_eq "pre-commit framework" "pre-commit" "$(field "$json" '.hook_systems[] | select(.name == "pre-commit") | .name')"
assert_eq "github workflows" "github" "$(field "$json" .ci.provider)"
assert_eq "ruff linter" "ruff" "$(field "$json" '.linters[] | select(.name == "ruff") | .name')"
assert_eq "ruff lint command" "ruff check ." "$(field "$json" .commands.lint.command)"
assert_eq "pytest command" "pytest" "$(field "$json" .commands.test.command)"
assert_eq "recommend precommit" "precommit" "$(field "$json" .recommend.hooks_via)"

c="$TMPROOT/go"; go_bare "$c"
json="$(detect "$c")"
assert_eq "no remote means forge none" "none" "$(field "$json" .git.forge)"
assert_eq "go stack" "go" "$(field "$json" '.stacks[0].name')"
assert_eq "no ci" "none" "$(field "$json" .ci.provider)"
assert_eq "no hook system" "0" "$(field "$json" '.hook_systems | length')"
assert_eq "recommend githooks" "githooks" "$(field "$json" .recommend.hooks_via)"
assert_contains "ci off with a reason" "$(field "$json" '[.recommend.flags[] | select(.flag == "--without ci") | .reason] | join(" ")')" "local and Claude hooks are the guardrails"
assert_eq "no questions on a plain local repo" "0" "$(field "$json" '.recommend.questions | length')"
assert_eq "go test command" "go test ./..." "$(field "$json" .commands.test.command)"

d="$TMPROOT/kt"; kotlin_maven "$d"
json="$(detect "$d")"
assert_eq "maven stack" "maven" "$(field "$json" '.stacks[0].name')"
assert_eq "kotlin language" "kt" "$(field "$json" '.stacks[0].languages | join(" ")')"
assert_eq "monorepo" "true" "$(field "$json" .monorepo.is_monorepo)"
assert_contains "monorepo marker" "$(field "$json" '.monorepo.markers | join(" ")')" "multiple-manifests"
assert_eq "package dirs" ". svc-a svc-b" "$(field "$json" '.monorepo.package_dirs | join(" ")')"
assert_contains "monorepo note" "$(field "$json" '.recommend.notes | join(" ")')" "monorepo"
assert_eq "maven test command" "mvn -B verify" "$(field "$json" .commands.test.command)"

e="$TMPROOT/sh"; shell_only "$e"
json="$(detect "$e")"
assert_eq "shell-only stack" "shell" "$(field "$json" '.stacks[0].name')"
assert_eq "languages counted" "sh" "$(field "$json" '.languages[0].ext')"

plain="$TMPROOT/plain"; mkdir -p "$plain"; printf 'x\n' > "$plain/a.txt"
json="$(detect "$plain")"; assert_rc "non-git dir detects" 0 $?
assert_eq "non-git dir is not a repo" "false" "$(field "$json" .git.is_repo)"

debt="$TMPROOT/debt"; new_fixture "$debt"
seq 1 450 | sed 's/^/const v/;s/$/ = 1;/' > "$debt/long.ts"
for i in $(seq 1 60); do printf '// note %s\nconst x%s = 1;\n' "$i" "$i"; done > "$debt/chatty.ts"
commit_all "$debt"
json="$(detect "$debt")"
assert_eq "long files counted" "1" "$(field "$json" .legacy_debt.files_over_400_lines)"
assert_eq "comment-heavy files counted" "1" "$(field "$json" .legacy_debt.files_with_comment_density_high)"

foreign="$TMPROOT/foreign"; new_fixture "$foreign"
printf '#!/bin/sh\nexit 0\n' > "$foreign/.git/hooks/pre-commit"; chmod +x "$foreign/.git/hooks/pre-commit"
printf '#!/bin/sh\nexit 0\n' > "$foreign/.git/hooks/pre-push.sample"
json="$(detect "$foreign")"
assert_eq "foreign native hook" "pre-commit" "$(field "$json" '.hook_systems[] | select(.name == "native") | .detail')"
assert_eq "foreign native hook conflict" "foreign-native-hook" "$(field "$json" '.conflicts[0].id')"
git -C "$foreign" config core.hooksPath other-hooks
json="$(detect "$foreign")"
assert_eq "hooksPath conflict" "foreign-hooks-path" "$(field "$json" '.conflicts[] | select(.id == "foreign-hooks-path") | .id')"
assert_eq "hooksPath recommends none" "none" "$(field "$json" .recommend.hooks_via)"

ptr="$TMPROOT/ptr"; new_fixture "$ptr"
printf '# Rules\n' > "$ptr/AGENTS.md"; printf '@AGENTS.md\n' > "$ptr/CLAUDE.md"
mkdir -p "$ptr/.claude"; printf '{"hooks":{"Stop":[]}}\n' > "$ptr/.claude/settings.json"
json="$(detect "$ptr")"
assert_eq "pointer CLAUDE.md" "true" "$(field "$json" .claude.claude_md.pointer_to_agents)"
assert_eq "settings hook events" "Stop" "$(field "$json" '.claude.settings.hook_events | join(" ")')"
assert_eq "agents md present" "true" "$(field "$json" .claude.agents_md)"
printf '# Project\n\nReal content here.\n' > "$ptr/CLAUDE.md"
assert_eq "real CLAUDE.md is not a pointer" "false" "$(field "$(detect "$ptr")" .claude.claude_md.pointer_to_agents)"

fakebin="$TMPROOT/bin"; mkdir -p "$fakebin"
printf '#!/usr/bin/env bash\nprintf %s\n' "'{\"visibility\":\"PUBLIC\"}'" > "$fakebin/gh"; chmod +x "$fakebin/gh"
json="$(PATH="$fakebin:$PATH" detect "$b" --probe-visibility)"
assert_eq "probe reports public" "public" "$(field "$json" .visibility)"
assert_contains "public recommends the approval gate" "$(field "$json" '[.recommend.flags[].flag] | join(" ")')" "approval-gate"
assert_eq "public asks about the gate" "approval-gate" "$(field "$json" '.recommend.questions[] | select(.id == "approval-gate") | .id')"
nodebin="$TMPROOT/nodebin"; mkdir -p "$nodebin"; ln -sf "$(command -v node)" "$nodebin/node"
json="$(PATH="$nodebin:/usr/bin:/bin" detect "$a" --probe-visibility)"
assert_eq "probe without the cli stays unknown" "unknown" "$(field "$json" .visibility)"

before="$(find "$a" -type f -not -path '*/.git/*' | sort | while IFS= read -r f; do cksum "$f"; done)"
detect "$a" >/dev/null
after="$(find "$a" -type f -not -path '*/.git/*' | sort | while IFS= read -r f; do cksum "$f"; done)"
assert_eq "detect writes nothing" "$before" "$after"
assert_eq "detect leaves git clean" "" "$(git -C "$a" status --porcelain)"

"$DETECT" >/dev/null 2>&1; assert_rc "no target is usage" 2 $?
"$DETECT" "$a" --bogus >/dev/null 2>&1; assert_rc "bad flag is usage" 2 $?
"$DETECT" "$TMPROOT/missing" >/dev/null 2>&1; assert_rc "missing dir is precondition" 3 $?
"$DETECT" --help >/dev/null; assert_rc "help" 0 $?
finish
