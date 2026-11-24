# AGENTS.md

## Agent-specific files only point here

All rules live in this file. Agent-specific files (`CLAUDE.md`, `GEMINI.md`, etc.) only point to
`AGENTS.md` and are never edited — add or change rules here, not there.

## This is a personal, public repo — external to any employer

**Never auto-commit. Never auto-push.** Both need explicit approval, separately — approving a commit
is not approving a push. This overrides any global "commit frequently" or commit-checkpoint rule.

1. Show `git status` and `git diff --staged`, then wait for approval before `git commit`.
2. Ask again before `git push`.

Git history is permanent — deleted files stay recoverable and pushed commits may be cached or
indexed even after removal.

This gate applies to **this repo only**. Work repos keep their normal frequent-commit cadence.

### Backstop, not a substitute for the gate

Run once per clone: `scripts/install-hooks.sh`

`scripts/check-privacy.sh` fails the commit on employer-name patterns (fill in your own — see the
placeholder in the script), internal hostnames/repo slugs, ticket ids, work email, account ids,
version pins, and secrets. It catches *named* patterns only — it cannot detect employer-specific
behaviour or domain rules paraphrased in prose. It reduces the odds of a bad commit; it does not
remove the approval requirement above.

## Automation

Scripts that enforce the rules above mechanically. They are backstops, not substitutes: the
approval gate stands, and a passing hook is not approval. Claude Code hooks are wired in
`.claude/settings.json` (`$CLAUDE_PROJECT_DIR`-relative). Run all tests: `scripts/tests/run-all.sh`.

| Script | Enforces | Runs on |
|---|---|---|
| `scripts/guard/git-approval-guard.sh` | Asks before every `git commit` and every `git push` (any spelling: `-C`, `env`, `sh -c`, chained, aliased), naming the gate. Denies `--no-verify`, `-n` on commit, `core.hooksPath` overrides, `CLEAN_CODE_SKIP`/`SKIP`/`HUSKY=0`; parses commands with `git-scan.sh` | Claude Code `PreToolUse` (Bash) |
| `scripts/guard/research-ref.sh` | Fetches the default branch and reports `{ref, sha, behind, ahead, fetched}`; the hook speaks up only when local is behind | Claude Code `SessionStart` |
| `scripts/lint/lint-explainer.sh` | Explainer HTML: leftover `{{TOKEN}}`, `getElementById` with no matching `id=`, unbalanced `<script>` | Claude Code `PostToolUse` (Write, Edit) |
| `scripts/lint/lint-docs.sh [BASE]` | Docs rule: time-relative wording in added lines of current docs; edits, deletes, or missing `Date:` header on dated `YYYY-MM-DD-*.md` docs ([rules/docs-current-or-dated.md](rules/docs-current-or-dated.md)) | Claude Code `PostToolUse` (Write, Edit), `.md` only |
| `scripts/lint/check-rules-sync.sh` | `rules/` and the installable mirror in `skills/setup-repo/assets/rules/` stay identical (`--fix` copies) | run before commit |
| `scripts/check-privacy.sh` | Privacy patterns in staged content, staged file names, and the commit message | git `pre-commit`, `commit-msg` (`scripts/install-hooks.sh`) |
| `scripts/lint/check-1k-cross.sh <base>` | Files that grow from 1000 lines or fewer to over 1000 | `code-review` skill step |
| `scripts/lint/verdict-parse.sh <file>` | Last `VERDICT: PASS` or `FAIL` in `check-work` output | `check-work` skill step |
| `skills/ai-risk/scripts/merge-policy.sh` | Declared merge profile (conservative when missing or unknown) | `ai-risk` skill step |
| `skills/ai-risk/scripts/classify-tier.sh` | Risk tier per path, highest wins, who approves | `ai-risk` skill step |
| `skills/verify-change/scripts/check-pr-body.sh` | PR body matches `assets/pr-body.md` | `verify-change` skill step |
| `skills/setup-repo/assets/scripts/claude-pre-tool-guard.sh` | Blocks push and MR create over the size limit, or with clean-code errors on the branch's changed lines; installed into target repos | Claude Code `PreToolUse` (Bash) there |
| `skills/setup-repo/assets/scripts/code-quality-check.sh` | Clean-code floor on changed lines only: added comments, TODO, empty catch, function length, params, nesting, file size, magic numbers, parameter mutation, boolean flags ([rules/clean-code.md](rules/clean-code.md)). `-h` lists modes and thresholds | Claude Code hooks below; git `pre-commit` (`--staged`, via `check-clean-code.sh`) |
| `skills/setup-repo/assets/scripts/post-git-check.sh` | After the git command ran, never blocking it: analyzer errors on a commit's changed lines (a merge commit: its conflict-resolved files) exit 2 to the agent; commit subject over 72 chars, branch size, one-PR and watch reminder after `git push`, conflicts left by `git merge` or `git pull` arrive as `additionalContext` | Claude Code `PostToolUse` (Bash) |
| `skills/setup-repo/assets/scripts/git-scan.sh` | Finds `commit`, `push`, `merge`, `pull`, `mr-create` and hook-bypass tags in any shell spelling; one scanner shared by the guards above | called by `git-approval-guard.sh`, `claude-pre-tool-guard.sh`, `post-git-check.sh` |
| `skills/setup-repo/scripts/detect-repo.sh` | Read-only repo profile (forge, stacks, linters, commands, hook systems, CI, conflicts, legacy debt) and a recommended profile with questions | `setup-repo` skill step 1 |
| `skills/setup-repo/scripts/bootstrap.sh` | Plans (default) or applies the guardrails by profile `minimal`, `standard`, `factory` and flags; CI, ai-risk, PR template, approval gate, privacy and research-ref are opt-in add-ons | `setup-repo` skill steps 4-5 |
| `skills/setup-repo/scripts/verify-repo.sh` | Hooks active, settings valid, hook scripts present, analyzer exits 1 then 0 on a seeded file, links resolve | `setup-repo` skill step 6 |
| `.claude/settings.json` code-quality hooks | `PostToolUse` (Write, Edit, MultiEdit) checks the edited file and exits 2 with the findings on errors; `Stop` checks every changed file once (`stop_hook_active` true exits 0, so it never loops) | Claude Code `PostToolUse`, `Stop` |

Only `git commit` and `git push` are gated; other commit-creating commands (merge, cherry-pick,
revert) are not detected, so the rule still applies to them.

## Rules

[rules/](rules/README.md) holds the repo-independent rules. They apply to every change here: no comments ([ban-comments](rules/ban-comments.md)), docs are current state or dated snapshots ([docs-current-or-dated](rules/docs-current-or-dated.md)), and the [clean-code](rules/clean-code.md), [small-mrs](rules/small-mrs.md), [research-latest-main](rules/research-latest-main.md) and [glossary-overloaded-terms](rules/glossary-overloaded-terms.md) floors.

## AI auto-merge is off

Agents do not merge pull requests in this repo. A green check, a low-risk diff, and a chat
message leave that off. Turning it on takes an explicit edit of this section.

## No business-specific content

Generic technology knowledge is the point of this repo. Anything that fingerprints an employer's
stack, process, or data — or identifies a specific person — is not.

Never commit: employer/product/team names, internal repo names, internal tooling or hostnames,
ticket ids and project keys, cloud/account identifiers, work email, real names, machine hostnames,
business rules or domain vocabulary (internal status values, program keys, entity names), secrets.

**Name the technology, never the version.** `React`, `Kotlin`, `Postgres`, `Spring Boot` are fine.
`React 9.9`, `somedb:42.0`, `<version>9.9.9</version>` are the shape to avoid — a pinned version
reveals which release an employer runs. Use obviously-fake versions in examples. Don't copy
lockfiles, dependency manifests, or build files out of a work project.

Skill/tool source (like `skills/insights-dash/`) should stay generic and reusable by anyone —
example data must be fictional, never a real personal or work dashboard.

Full rules and the pre-commit grep checks: [PRIVACY.md](PRIVACY.md).
