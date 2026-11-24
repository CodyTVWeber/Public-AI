---
name: setup-repo
description: Bootstrap a whole repo with the AI guardrails (clean-code rules and analyzer, git hooks, Claude Code pre and post hooks on git commands, AGENTS.md section, skill links), shaped to what the repo already has. Detect the repo, recommend a profile, plan, apply, verify. Use when the user says "set up this repo", "set up the guardrails", "set up clean code", "ban comments", "enforce small MRs", /setup-repo, or starts a new repo that should follow these standards.
argument-hint: "[target repo path, default: current repo]"
---

# Setup repo

Repo-aware bootstrap. Everything reusable ships in this skill; the scripts read the repo, plan, write,
and verify. Pipeline (CI) pieces are opt-in per repo; hooks on git commands are the default backbone.

## Playbook

Run from this skill's directory. `<t>` is the target (argument, else the current repo; it must be a git repo).

1. **Detect.** `scripts/detect-repo.sh <t>` prints the profile as JSON: forge, stacks, linters, commands,
   hook systems, CI, existing Claude files, conflicts, legacy debt, and a `recommend` block. Add
   `--probe-visibility` only when public vs private matters and `gh` or `glab` is available
2. **Summarize** in 8 lines or fewer: forge and CI, stacks, hook system found, conflicts, legacy debt,
   the recommended profile and flags with their reasons
3. **Ask** only what `recommend.questions[]` lists (profile, ci, approval-gate), through AskUserQuestion
   when available. No questions listed means take the recommended flags
4. **Plan.** `scripts/bootstrap.sh <t> --plan [--profile P] [--with a,b] [--without a,b] [--hooks-via V]`.
   Show a digest of 10 lines or fewer: counts per action, every `manual` step with its reason, the notes
5. **Apply.** `scripts/bootstrap.sh <t> --apply --yes` with the same flags. Never commit for the user
6. **Verify.** `scripts/verify-repo.sh <t>`. A failed check means fix the cause, re-run apply, verify again
7. **Wire the linter** for the detected stack, merging the snippet into existing config rather than replacing it:
   - JS/TS: import `cleanCodeRules` from `assets/lint/eslint.clean-code.js` and spread it into a flat-config entry for `src/**`; relax for tests, generated code, data tables
   - Kotlin/Java: `assets/lint/detekt-clean-code.yml` into the detekt config
   - Python: `assets/lint/ruff-clean-code.toml` into `pyproject.toml`
   - Other: pick a linter that can cap nesting depth, parameter count and function length
   Existing violations surface: set the new rules to `warn` first, or baseline them, so the gate blocks only new debt
8. **Report** in a few lines: profile, steps by action, `manual` steps left, verify result, linter wiring

## Profiles

| Profile | Installs |
|---|---|
| `minimal` | rules, clean-code scripts, git pre-commit and pre-push hooks |
| `standard` (default) | minimal + Claude Code hooks (PreToolUse guard on push and MR create, PostToolUse git check, PostToolUse analyzer and docs lint, Stop analyzer) + AGENTS.md section + core skill symlinks |
| `factory` | standard + ci + ai-risk + pr-template; no approval gate (factories run unattended) |

Add-ons through `--with`: `ci`, `ai-risk`, `pr-template`, `approval-gate`, `privacy`, `research-ref`.
`approval-gate` is for human-gated repos. CI is the control a PR cannot silently delete: local hooks and
`.claude` settings ship in the same diff and can be edited out.

## Reading the plan

- Step actions: `create`, `merge` (an existing file is extended), `skip` (already in place), `manual`
  (a human acts; the step says what). A `manual` step carries a `snippet` when exact text is needed
- Existing files that differ are kept unless `--force`; JSON and AGENTS.md are merged, never replaced
- Hook systems: githooks (`core.hooksPath=.githooks`), husky (call lines appended), native (foreign
  `.git/hooks` chained, kept as `.bak`), lefthook and the pre-commit framework (snippet only). An existing
  different `core.hooksPath` is never overridden
- The AGENTS.md section is replaced between its markers; `CLAUDE.md` pointer files are never edited
- Skills are absolute symlinks into a Public-AI clone (`--skills-from`, else `$PUBLIC_AI_DIR`, else
  `~/code/Public-AI`), listed in `.git/info/exclude` so they stay local. `scripts/link-skills.sh` relinks

## Bare install

`scripts/install.sh <t>` copies rules, scripts and hooks without detection, plan or profile. Flags:
`--force`, `--no-claude-hook`, `--claude-hooks LIST`, `--no-post-git`, `--no-githooks`, `--no-rules`,
`--no-doc`, `--dry-run`. `bootstrap.sh` calls it.

## Rules for this skill

- Reuse the shipped assets; do not rewrite them per repo. Tune thresholds with env vars
  (`MR_SIZE_SOFT`, `MR_SIZE_HARD`, `FILE_SOFT`, `FILE_HARD`, `CC_FUNC_WARN`, `CC_FUNC_ERROR`,
  `CC_PARAMS_ERROR`, `CC_NEST_WARN`, `CC_NEST_ERROR`, `CC_FILE_WARN`, `CC_FILE_ERROR`, `CC_DISABLE`), not by editing scripts
- Never weaken an existing stricter rule in the target
- `CLEAN_CODE_SKIP=1` and `CC_SKIP=1` are one-command overrides; tell the user whenever either is used
- Good start, not a framework: no extra checks beyond what ships unless the user asks
