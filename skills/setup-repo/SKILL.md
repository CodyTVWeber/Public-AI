---
name: setup-repo
description: Bootstrap a whole repo with the AI guardrails (clean-code rules and analyzer, git hooks, Claude Code pre and post hooks on git commands, AGENTS.md section, skill links), shaped to what the repo already has. Detect the repo, recommend a profile, plan, apply, verify. Use when the user says "set up this repo", "set up the guardrails", "set up clean code", "ban comments", "enforce small MRs", /setup-repo, or starts a new repo that should follow these standards.
argument-hint: "[target repo path, default: current repo]"
---

# Setup repo

Repo-aware bootstrap. Reusable pieces ship in this skill; scripts read the repo, plan, write, verify. CI pieces are opt-in per repo; git-command hooks are the default backbone.

## Playbook

Run from this skill's directory. `<t>` = target (argument, else current repo; must be a git repo).

1. **Detect.** `scripts/detect-repo.sh <t>` → profile JSON: forge, stacks, linters, commands, hook systems, CI, existing Claude files, conflicts, legacy debt, `recommend` block. Add `--probe-visibility` only when public vs private matters and `gh` or `glab` is available
2. **Summarize** ≤8 lines: forge + CI, stacks, hook system, conflicts, legacy debt, recommended profile + flags with reasons
3. **Ask** only what `recommend.questions[]` lists (profile, ci, approval-gate), via AskUserQuestion when available. None listed → take recommended flags
   - Ask again when the team has not agreed to guardrails: `--profile local` installs without touching tracked files (hooks in `.claude/settings.local.json` and `.git/hooks`, note in `.git/info/local-guardrails.md`, paths in `.git/info/exclude`)
   - Skills: default `--skills core` (6 plus 15 support skills). `core+aliases`, `all`, `none`, or a comma list are opt-in. Source: `--skills-from PATH` or `$PUBLIC_AI_DIR`; neither set → `manual` step
4. **Plan.** `scripts/bootstrap.sh <t> --plan [--profile P|--local] [--with a,b] [--without a,b] [--hooks-via V] [--skills SET] [--skills-from PATH]`. Digest ≤10 lines: counts per action, every `manual` step with reason, notes
5. **Apply.** `scripts/bootstrap.sh <t> --apply --yes` with the same flags. Never commit for the user
6. **Verify.** `scripts/verify-repo.sh <t>`. Failed check → fix cause, re-apply, verify again
   - `drift` lists installed files `changed-upstream`, `modified-locally`, `removed-upstream`, `missing`
   - Take new upstream versions: `bootstrap.sh <t> --apply --yes --upgrade` (modified files untouched unless `--force`; reported)
7. **Wire the linter** for the detected stack. Merge snippet into existing config; never replace it
   - JS/TS: import `cleanCodeRules` from `assets/lint/eslint.clean-code.js`, spread into a flat-config entry for `src/**`; relax for tests, generated code, data tables
   - Kotlin/Java: `assets/lint/detekt-clean-code.yml` into detekt config
   - Python: `assets/lint/ruff-clean-code.toml` into `pyproject.toml`
   - Other: pick a linter that can cap nesting depth, parameter count, function length
   - Existing violations: set new rules to `warn` first, or baseline them, so the gate blocks only new debt
8. **Report** in a few lines: profile, steps by action, `manual` steps left, verify result, linter wiring

## Profiles

| Profile | Installs |
|---|---|
| `minimal` | rules, clean-code scripts, git pre-commit and pre-push hooks, AGENTS.md section (floors, and that a miss fails the check) |
| `standard` (default) | minimal + Claude Code hooks (PreToolUse guard on push and MR create, PostToolUse git check, PostToolUse analyzer and docs lint, Stop analyzer) + core skill symlinks |
| `factory` | standard + ci + ai-risk + pr-template; no approval gate (factories run unattended) |
| `local` | standard guardrails, tracked files unchanged: `settings.local.json`, `.git/hooks`, `.git/info/exclude`, note in `.git/info/local-guardrails.md`; no `ci` |

- Add-ons via `--with`: `ci`, `ai-risk`, `pr-template`, `approval-gate`, `privacy`, `research-ref`
- `approval-gate`: human-gated repos only
- CI is the control a PR cannot silently delete. Local hooks and `.claude` settings ship in the same diff and can be edited out

## Reading the plan

- Actions: `create`, `merge` (existing file extended), `skip` (already in place), `manual` (human acts; step says what). `manual` carries a `snippet` when exact text is needed
- Differing existing files kept unless `--force`. JSON and AGENTS.md merged, never replaced
- Hook systems:
  - githooks (`core.hooksPath=.githooks`)
  - husky (call lines appended)
  - native (foreign `.git/hooks` chained, kept as `.bak`)
  - lefthook, pre-commit framework (snippet only)
  - An existing different `core.hooksPath` is never overridden
- AGENTS.md section replaced between its markers. Vendor pointer files (`CLAUDE.md`, `GEMINI.md`) never edited
- Skills: absolute symlinks into a Public-AI clone (`--skills-from`, else `$PUBLIC_AI_DIR`; no other default). One `.git/info/exclude` entry per link keeps them local; the team's own skills stay visible. `scripts/link-skills.sh` relinks
- `--upgrade` also replaces record-less `stale-copy` files (target blob matches a past upstream version); without it the plan says rerun with `--upgrade`
- Install record (`.claude/ai-guardrails.json`; local: `.git/info/local-guardrails.json`): source commit + hash per file. `--upgrade` re-applies upstream-changed files only

## Bare install

`scripts/install.sh <t>` copies rules, scripts, hooks. No detection, plan, or profile. Flags: `--force`, `--no-claude-hook`, `--claude-hooks LIST`, `--no-post-git`, `--no-githooks`, `--no-rules`, `--no-doc`, `--dry-run`, `--copy SRC DEST`, `--overwrite DEST`. Only code that copies files into a target; `bootstrap.sh` decides and calls it.

## Rules for this skill

- Reuse shipped assets; do not rewrite per repo. Tune with env vars (`MR_SIZE_SOFT`, `MR_SIZE_HARD`, `FILE_SOFT`, `FILE_HARD`, `CC_FUNC_WARN`, `CC_FUNC_ERROR`, `CC_PARAMS_ERROR`, `CC_NEST_WARN`, `CC_NEST_ERROR`, `CC_FILE_WARN`, `CC_FILE_ERROR`, `CC_DISABLE`), not script edits
- Never weaken an existing stricter rule in the target
- `CLEAN_CODE_SKIP=1` and `CC_SKIP=1` are one-command overrides. Tell the user whenever either is used
- A check (git hook, Claude hook, CI, linter snippet) ships with the AGENTS guardrails section, so the agent sees the floors while editing and knows a miss fails the check. `--without agents-doc` is named in the plan; the hooks still fail the change
- Good start, not a framework: no checks beyond what ships unless the user asks
