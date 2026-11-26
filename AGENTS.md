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

`scripts/check-privacy.sh` fails the commit on internal hostnames/repo slugs, ticket ids, work email,
account ids, version pins, secrets, and binaries. Employer names and hostnames come from your own
untracked patterns file `<git-dir>/info/privacy-patterns` (one extended regex per line); a missing file
warns, and blocks under `--strict` or `PRIVACY_REQUIRE_PATTERNS=1`. It catches *named* patterns only — it cannot detect employer-specific
behaviour or domain rules paraphrased in prose. It reduces the odds of a bad commit; it does not
remove the approval requirement above.

## Automation

Scripts that enforce the rules above mechanically. They are backstops, not substitutes: the
approval gate stands, and a passing hook is not approval. Claude Code hooks are wired in
`.claude/settings.json` (`$CLAUDE_PROJECT_DIR`-relative). Run all tests: `scripts/tests/run-all.sh` (`--fast` skips the files listed in `scripts/tests/slow.list`).

| Script | Enforces | Runs on |
|---|---|---|
| `scripts/guard/git-approval-guard.sh` | Asks before every commit-like command (`commit`, `merge`, `cherry-pick`, `revert`, `am`, `rebase -x`, `commit-tree`, `update-ref`) and push-like command (`push`, `send-pack`) in any spelling (`-C`, `env`, `sh -c`, chained, aliases defined in the same command), naming the gate. Asks on forge writes (`gh`/`glab` pr or mr create and merge, api writes), on command words built at runtime, and on unknown git subcommands. Denies `--no-verify`, `-n` on commit, any `core.hooksPath` write, `CLEAN_CODE_SKIP`/`SKIP`/`HUSKY=0`; parses commands with `git-scan.sh`. Not caught: scripts, Makefiles or package scripts that run git inside, encoded text like `base64 -d \| sh`, plain `rebase` and `pull` | Claude Code `PreToolUse` (Bash) |
| `scripts/guard/research-ref.sh` | Fetches the default branch and reports `{ref, sha, behind, ahead, fetched}`; the hook speaks up only when local is behind | Claude Code `SessionStart` |
| `scripts/lint/lint-explainer.sh` | Explainer HTML: leftover `{{TOKEN}}`, `getElementById` with no matching `id=`, unbalanced `<script>` | Claude Code `PostToolUse` (Write, Edit) |
| `scripts/lint/lint-docs.sh [BASE]` | Docs rule: time-relative wording in added lines of current docs; edits, deletes, or missing `Date:` header on dated `YYYY-MM-DD-*.md` docs ([rules/docs-current-or-dated.md](rules/docs-current-or-dated.md)) | Claude Code `PostToolUse` (Write, Edit), `.md` only |
| `scripts/lint/check-copies.sh` | Every pair in `scripts/lint/copies.list` (`rules/*.md` and `lint-docs.sh` into `skills/setup-repo/assets/`) stays byte-identical; `--fix` copies canonical over the copy | run before commit |
| `scripts/check-privacy.sh` | Privacy patterns in staged content, staged file names, binaries (blocked unless listed in `.privacyallow-binaries`), and the commit message; local patterns from `<git-dir>/info/privacy-patterns` (`--strict` or `PRIVACY_REQUIRE_PATTERNS=1` blocks when missing); `--range REV` scans a commit range (added lines, names, messages, binaries); version pins | git `pre-commit`, `commit-msg`, `pre-push` (`scripts/install-hooks.sh`; pre-push scans `@{u}..HEAD`, then the branch size) |
| `scripts/lint/check-1k-cross.sh <base>` | Files that grow from 1000 lines or fewer to over 1000 | `code-review` skill step |
| `scripts/lint/verdict-parse.sh <file>` | Last `VERDICT: PASS` or `FAIL` in `check-work` output | `check-work` skill step |
| `skills/review/scripts/stages.sh <base>` | Review stage skills (`review-<id>`) that apply to the diff, from changed paths and added lines; `plan` and `proof` always, the rest only on a signal and above a size threshold | `review` skill step 1 |
| `skills/ai-risk/scripts/merge-policy.sh` | Declared merge profile (conservative when missing or unknown) | `ai-risk` skill step |
| `skills/ai-risk/scripts/classify-tier.sh` | Risk tier per path, highest wins, who approves | `ai-risk` skill step |
| `skills/verify-change/scripts/check-pr-body.sh` | PR body matches `assets/pr-body.md` | `verify-change` skill step |
| `skills/setup-repo/assets/scripts/claude-pre-tool-guard.sh` | Blocks push and MR create over the size limit, or with clean-code errors on `merge-base..HEAD` (read through the analyzer's `--range`, never the working tree); installed into target repos | Claude Code `PreToolUse` (Bash) there |
| `skills/setup-repo/assets/scripts/code-quality-check.sh` | Clean-code floor on changed lines only: added comments, TODO, empty catch, function length, params, nesting, file size, magic numbers, parameter mutation, boolean flags ([rules/clean-code.md](rules/clean-code.md)); docstrings and mutation of `res`, `req`, `ctx`, `event`, `self`, `this` are warnings. Modes: `FILE...`, `--staged`, `--changed [BASE]`, `--range BASE..HEAD` (committed text only), `--hook`, `--stop-hook`; `-h` lists thresholds | Claude Code hooks below; git `pre-commit` (`--staged`, via `check-clean-code.sh`) |
| `skills/setup-repo/assets/scripts/post-git-check.sh` | After the git command ran, never blocking it and always exiting 0: analyzer errors on a commit's changed lines (`--range PARENT..HEAD`; a merge commit: its conflict-resolved files), commit subject over 72 chars, branch size, one-PR and watch reminder after `git push`, conflicts left by `git merge` or `git pull` all arrive as `additionalContext` | Claude Code `PostToolUse` (Bash) |
| `skills/setup-repo/assets/scripts/git-scan.sh` | Tags `commit-like`, `push-like`, `forge-write`, `ask-dynamic`, `ask-unknown-git`, `ask-interpreter`, plus `merge`, `pull`, `mr-create` and hook-bypass, in any shell spelling; one scanner shared by the guards above | called by `git-approval-guard.sh`, `claude-pre-tool-guard.sh`, `post-git-check.sh` |
| `skills/setup-repo/scripts/detect-repo.sh` | Read-only repo profile (forge, stacks, linters, commands, hook systems, CI, conflicts, legacy debt) and a recommended profile with questions | `setup-repo` skill step 1 |
| `skills/setup-repo/scripts/bootstrap.sh` | Plans (default) or applies the guardrails by profile `minimal`, `standard`, `factory`, `local` (alias `--local`: tracked files unchanged, hooks in `.claude/settings.local.json` and `.git/hooks`, paths in `.git/info/exclude`) and flags; `--skills core\|core+aliases\|all\|none\|a,b` from `--skills-from` or `$PUBLIC_AI_DIR`; `--upgrade` re-applies only files changed upstream; one file writer, `install.sh`; CI, ai-risk, PR template, approval gate, privacy and research-ref are opt-in add-ons | `setup-repo` skill steps 4-5 |
| `skills/setup-repo/scripts/verify-repo.sh` | Hooks active, settings valid, hook scripts present, analyzer exits 1 then 0 on a seeded file, links resolve; `drift` lists installed files `changed-upstream`, `modified-locally` or `missing` against the install record (source commit and file hashes); local mode also checks git status stays clean | `setup-repo` skill step 6 |
| `.claude/settings.json` code-quality hooks | `PostToolUse` (Write, Edit, MultiEdit) checks the edited file and feeds errors back to the agent (exit 2); `Stop` checks only the files edited this session (tracked files with changes when no session log exists) once (`stop_hook_active` true exits 0, so it never loops); every registered hook sets an explicit `timeout` | Claude Code `PostToolUse`, `Stop` |

The gate covers commit-like and push-like commands as listed in the guard row. Not caught: scripts,
Makefiles or package scripts that run git inside, encoded text such as `base64 -d | sh`, and plain
`rebase` and `pull`; the approval rule still applies to them.

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
