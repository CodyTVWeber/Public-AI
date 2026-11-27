# AGENTS.md

## Pointers

- Agent files (`CLAUDE.md`, `GEMINI.md`, ...) only point here. Never edit them ([agent-source](rules/agent-source.md))
- Add or change rules here only
- Experimental, opt-in, not a floor: [context-reuse](skills/experimental/context-reuse/)

## Personal public repo, external to any employer

Low-risk repo (`.mr-size` `risk: low`): commit, push, and merge finished work without asking, per [commit-and-ship](rules/commit-and-ship.md). Never bypass hooks or force-push.

- Public repo: git history is permanent; deleted files stay recoverable; pushed commits may stay cached or indexed after removal. Privacy checks below run on every commit and push

### Privacy backstop

- Run once per clone: `scripts/install-hooks.sh`
- `scripts/check-privacy.sh` fails commit on: internal hostnames/repo slugs, ticket ids, work email, account ids, version pins, secrets, binaries
- Employer names and hostnames: untracked `<git-dir>/info/privacy-patterns` (one extended regex per line)
  - Missing file → warns; blocks under `--strict` or `PRIVACY_REQUIRE_PATTERNS=1`
- Catches *named* patterns only. Misses employer-specific behaviour and domain rules paraphrased in prose
- Lowers odds of a bad commit; review content before shipping

## Automation

- Scripts decide every check they implement. Run the script; do not re-judge its result. AI judges only what no script covers ([deterministic-checks](rules/deterministic-checks.md))
- Claude Code hooks: `.claude/settings.json` (`$CLAUDE_PROJECT_DIR`-relative)
- All tests: `scripts/tests/run-all.sh` (`--fast` skips files in `scripts/tests/slow.list`)

| Script | Enforces | Runs on |
|---|---|---|
| `scripts/guard/git-approval-guard.sh` | Low-risk repo (`.mr-size` `risk: low`, command stays in repo): allows commit, push, merge, forge writes; denies force/delete push. Elsewhere asks before commit-like (`commit`, `merge`, `cherry-pick`, `revert`, `am`, `rebase -x`, `commit-tree`, `update-ref`) and push-like (`push`, `send-pack`) commands in any spelling (`-C`, `env`, `sh -c`, chained, aliases defined in same command), naming the gate. Asks on forge writes (`gh`/`glab` pr or mr create and merge, api writes), runtime-built command words, unknown git subcommands. Denies `--no-verify`, `-n` on commit, `core.hooksPath` writes, `CLEAN_CODE_SKIP`/`SKIP`/`HUSKY=0`. Parses via `git-scan.sh`. Not caught: scripts, Makefiles, package scripts running git inside; encoded text like `base64 -d \| sh`; plain `rebase` and `pull` | Claude Code `PreToolUse` (Bash) |
| `scripts/guard/research-ref.sh` | Fetches default branch; reports `{ref, sha, behind, ahead, fetched}`. Hook speaks up only when local is behind | Claude Code `SessionStart` |
| `scripts/lint/lint-explainer.sh` | Explainer HTML: leftover `{{TOKEN}}`, `getElementById` with no matching `id=`, unbalanced `<script>` | Claude Code `PostToolUse` (Write, Edit) |
| `scripts/lint/lint-docs.sh [BASE]` | Docs rule: time-relative wording in added lines of Current docs; edits, deletes, or missing `Date:` header on dated `YYYY-MM-DD-*.md` docs ([rules/docs-current-or-dated.md](rules/docs-current-or-dated.md)) | Claude Code `PostToolUse` (Write, Edit), `.md` only |
| `scripts/lint/check-copies.sh` | Every pair in `scripts/lint/copies.list` (`rules/*.md` and `lint-docs.sh` into `skills/setup-repo/assets/`) stays byte-identical. `--fix` copies canonical over copy | Run before commit |
| `scripts/lint/check-languages.sh [--staged \| --range REV]` | Added files in a language other than Bash or JavaScript ([rules/scripting-languages.md](rules/scripting-languages.md)); skips regexes in `.languageexempt` | git `pre-commit` (`scripts/install-hooks.sh`) |
| `scripts/check-privacy.sh` | Privacy patterns in staged content, staged file names, binaries (blocked unless in `.privacyallow-binaries`), commit message; local patterns from `<git-dir>/info/privacy-patterns` (`--strict` or `PRIVACY_REQUIRE_PATTERNS=1` blocks when missing). `--range REV` scans commit range (added lines, names, messages, binaries). Version pins | git `pre-commit`, `commit-msg`, `pre-push` (`scripts/install-hooks.sh`; pre-push scans `@{u}..HEAD`, then the app, support, and docs size checks) |
| `scripts/lint/check-duplicates.sh <repo>` | Files in `<repo>` byte-identical to a tracked file here and absent from its install record (LICENSE allowed); JSON `{duplicates}` | Run on downstream repos |
| `scripts/lint/check-1k-cross.sh <base>` | Files growing from ≤1000 lines to over 1000 | `code-review` skill step |
| `scripts/lint/verdict-parse.sh <file>` | Last `VERDICT: PASS` or `FAIL` in `check-work` output | `check-work` skill step |
| `skills/review/scripts/stages.sh <base>` | Review stage skills (`review-<id>`) applying to diff, from changed paths and added lines. `plan` and `proof` always; rest only on signal and above size threshold | `review` skill step 1 |
| `skills/ai-risk/scripts/merge-policy.sh` | Declared merge profile (conservative when missing or unknown) | `ai-risk` skill step |
| `skills/ai-risk/scripts/classify-tier.sh` | Risk tier per path, highest wins, who approves | `ai-risk` skill step |
| `skills/verify-change/scripts/check-pr-body.sh` | PR body matches `assets/pr-body.md` | `verify-change` skill step |
| `skills/setup-repo/assets/scripts/claude-pre-tool-guard.sh` | Blocks push and MR create over size limit, or with clean-code errors on `merge-base..HEAD` (read via analyzer `--range`, never working tree). Installed into target repos | Claude Code `PreToolUse` (Bash) there |
| `skills/setup-repo/assets/scripts/code-quality-check.sh` | Clean-code floor on changed lines only: added comments, TODO, empty catch, function length, params, nesting, function order, guard clauses, file size, magic numbers, parameter mutation, boolean flags ([rules/clean-code.md](rules/clean-code.md)). Docstrings and mutation of `res`, `req`, `ctx`, `event`, `self`, `this` are warnings. Modes: `FILE...`, `--staged`, `--changed [BASE]`, `--range BASE..HEAD` (committed text only), `--hook`, `--stop-hook`. `-h` lists thresholds | Claude Code hooks below; git `pre-commit` (`--staged`, via `check-clean-code.sh`) |
| `skills/setup-repo/assets/scripts/post-git-check.sh` | After git command ran; never blocks, always exits 0. Analyzer errors on commit's changed lines (`--range PARENT..HEAD`; merge commit: conflict-resolved files), commit subject over 72 chars, branch size, one-PR and watch reminder after `git push`, conflicts from `git merge` or `git pull`. All arrive as `additionalContext` | Claude Code `PostToolUse` (Bash) |
| `skills/setup-repo/assets/scripts/git-scan.sh` | Tags `commit-like`, `push-like`, `forge-write`, `ask-dynamic`, `ask-unknown-git`, `ask-interpreter`, plus `merge`, `pull`, `mr-create`, hook-bypass, in any shell spelling. One scanner shared by guards above | Called by `git-approval-guard.sh`, `claude-pre-tool-guard.sh`, `post-git-check.sh` |
| `skills/setup-repo/scripts/detect-repo.sh` | Read-only repo profile (forge, stacks, linters, commands, hook systems, CI, conflicts, legacy debt); recommended profile with questions | `setup-repo` skill step 1 |
| `skills/setup-repo/scripts/bootstrap.sh` | Plans (default) or applies guardrails by profile `minimal`, `standard`, `factory`, `local` (alias `--local`: tracked files unchanged; hooks in `.claude/settings.local.json` and `.git/hooks`; paths in `.git/info/exclude`). Flags: `--skills core\|core+aliases\|all\|none\|a,b` from `--skills-from` or `$PUBLIC_AI_DIR`; `--upgrade` re-applies only files changed upstream. One file writer, `install.sh`. CI, ai-risk, PR template, approval gate, privacy, research-ref are opt-in add-ons | `setup-repo` skill steps 4-5 |
| `skills/setup-repo/scripts/verify-repo.sh` | Hooks active, settings valid, hook scripts present, analyzer exits 1 then 0 on seeded file, links resolve. `drift` lists installed files `changed-upstream`, `modified-locally`, `missing` vs install record (source commit, file hashes). Local mode also checks git status stays clean | `setup-repo` skill step 6 |
| `.claude/settings.json` code-quality hooks | `PostToolUse` (Write, Edit, MultiEdit) checks edited file, feeds errors back (exit 2). `Stop` checks only files edited this session (tracked files with changes when no session log) once (`stop_hook_active` true exits 0, never loops). Every registered hook sets explicit `timeout` | Claude Code `PostToolUse`, `Stop` |

The gate covers commit-like and push-like commands per the guard row. Not caught: scripts, Makefiles, or package scripts running git inside; encoded text such as `base64 -d | sh`; plain `rebase` and `pull`. Approval rule still applies to them.

## Rules

[rules/](rules/README.md) holds repo-independent rules. Apply to every change. Write to these floors on every touched line, before a check runs. Analyzer, docs lint, language check, privacy check, and git hooks fail the edit, commit, or push on a miss. Fix the code; never skip the check.

- No comments: [ban-comments](rules/ban-comments.md)
- Docs are current state or dated snapshot: [docs-current-or-dated](rules/docs-current-or-dated.md)
- Floors: [clean-code](rules/clean-code.md), [small-mrs](rules/small-mrs.md), [research-latest-main](rules/research-latest-main.md), [glossary-overloaded-terms](rules/glossary-overloaded-terms.md), [delegate-work](rules/delegate-work.md)
- Thinking stays telegraphic: [ai-thinking-dense](rules/ai-thinking-dense.md)
- Scripts, CI, hooks = skeleton; AI = muscles (glue and judgment): [muscles-and-skeleton](rules/muscles-and-skeleton.md)
- Context cap 175000 tokens (175k); autocompact at the cap unless a user message, skill, or repo rule names another: [context-window](rules/context-window.md)
- Frustration or vague "work harder": the agent's setup is the likely fault. Suggest rules, skills, hooks, model, effort, strategy, guidance, or `setup-repo`. Then cleanup rounds: extract shared copies, group by domain. Vague "better UI" also needs a reference screen and the terms for it: [frustration-fix-agent](rules/frustration-fix-agent.md)
- Scripts are Bash or JavaScript: [scripting-languages](rules/scripting-languages.md)
- Commit, push, open MR by default; merge in low-risk repos: [commit-and-ship](rules/commit-and-ship.md)
- Root `.mr-size` = `risk: low`: each size hard block (app, support, docs) → advisory. Low-risk repos only ([small-mrs](rules/small-mrs.md#low-risk-repos))

## No business-specific content

Generic tech knowledge is the point. Anything fingerprinting an employer's stack, process, or data, or identifying a person, stays out.

Never commit:

- Employer, product, team names; internal repo names, tooling, hostnames
- Ticket ids, project keys; cloud/account identifiers
- Work email, real names, machine hostnames
- Business rules or domain vocabulary (internal status values, program keys, entity names)
- Secrets

**Name the technology, never the version.** `React`, `Kotlin`, `Postgres`, `Spring Boot` are fine. `React 9.9`, `somedb:42.0`, `<version>9.9.9</version>` are the shape to avoid: a pinned version reveals which release an employer runs. Use obviously-fake versions in examples. Don't copy lockfiles, dependency manifests, or build files from a work project.

Skill/tool source (like `skills/insights-dash/`) stays generic and reusable by anyone. Example data is fictional, never a real personal or work dashboard.

Full rules and pre-commit grep checks: [PRIVACY.md](PRIVACY.md).
