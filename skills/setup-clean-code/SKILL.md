---
name: setup-clean-code
description: Set up clean-code enforcement in a repo, including the comment ban and the small-MR budget. Copy prebuilt rules, scripts and git/Claude hooks, then wire the project's linter. Use when the user says "set up clean code", "ban comments", "enforce small MRs", /setup-clean-code, or starts a new repo that should follow these standards.
argument-hint: "[target repo path, default: current repo]"
---

# Setup clean code

Installs prebuilt standards into a repo and wires enforcement. Everything reusable ships in this
skill's `assets/`; the installer copies it, you wire the linter.

## What ships

| Asset | Lands in the target repo as | Job |
|---|---|---|
| `assets/rules/clean-code.md` | `.claude/rules/clean-code.md` | Floor for new and touched code |
| `assets/rules/ban-comments.md` | `.claude/rules/ban-comments.md` | No new comments in production code |
| `assets/rules/small-mrs.md` | `.claude/rules/small-mrs.md` | One concern per MR, size budget |
| `assets/scripts/check-mr-size.sh` | `scripts/clean-code/` | Branch size vs base: warn > 400, block > 800 lines |
| `assets/scripts/check-clean-code.sh` | `scripts/clean-code/` | Staged files: file growth past the hard cap, empty catch, added comments |
| `assets/scripts/claude-pre-tool-guard.sh` | `scripts/clean-code/` | Blocks `git push` / PR or MR creation when over the hard limit |
| `assets/githooks/pre-commit`, `pre-push` | `.githooks/` | Run the two checks above |
| `assets/lint/*` | merged by hand | Nesting, params, function size in the project's linter |
| `assets/CLAUDE.snippet.md` | appended to `CLAUDE.md` | Points the agent at the rules |

## Steps

1. **Target.** Use the argument, else the current repo. It must be a git repo. Note uncommitted
   changes; the installer only adds files and appends to `CLAUDE.md`
2. **Install.** Run `scripts/install.sh <target>` from this skill's directory. Flags:
   `--force` overwrites differing files, `--no-claude-hook` skips the Claude guard. It sets
   `core.hooksPath=.githooks` unless the repo already uses another hooks path
3. **Check the report.** Skipped files mean the repo already had its own copy: diff them and keep
   the stricter value. If `core.hooksPath` points elsewhere, call `.githooks/pre-commit` and
   `pre-push` from that setup
4. **Wire the linter** for the detected stack, merging the snippet into existing config rather
   than replacing it:
   - JS/TS: `assets/lint/eslint.clean-code.js` into the flat ESLint config; relax for tests,
     generated code and data tables
   - Kotlin/Java: `assets/lint/detekt-clean-code.yml` into the detekt config
   - Python: `assets/lint/ruff-clean-code.toml` into `pyproject.toml`
   - Other: pick a linter that can cap nesting depth, parameter count and function length
   Existing violations will surface: set the new rules to `warn` first, or baseline them, so the
   gate blocks only new debt
5. **Verify.** In the target repo: run `scripts/clean-code/check-mr-size.sh` (expect 0 or 2);
   stage a file with an empty `catch {}` and a file with a new `// note` and confirm the
   pre-commit hook blocks both; run the linter
   and confirm the new rules load
6. **Report** in a few lines: files installed, hooks active, linter wired or not, anything
   skipped. Do not commit for the user unless asked

## Rules for this skill

- Reuse the shipped assets; do not rewrite them per repo. Tune thresholds with env vars
  (`MR_SIZE_SOFT`, `MR_SIZE_HARD`, `FILE_SOFT`, `FILE_HARD`), not by editing scripts
- Never weaken an existing stricter rule in the target
- `CLEAN_CODE_SKIP=1` is a one-command override; tell the user whenever it is used
- Good start, not a framework: no extra checks beyond what ships unless the user asks
