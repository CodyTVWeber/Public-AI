# setup-clean-code

Prebuilt clean-code rules, a small-MR budget, and the hooks that enforce them, installed into any
git repo with one command. Works with any agent that can run a shell; the Claude Code guard is
optional.

## Install into a repo

```bash
skills/setup-clean-code/scripts/install.sh /path/to/repo
```

Flags: `--force` (overwrite differing files), `--no-claude-hook`. Then follow SKILL.md step 4 to
merge the linter snippet for the repo's stack.

## Use as a skill

Symlink or copy this directory to your agent's skills folder, then ask: "set up clean code in
this repo".

## What it enforces

| Gate | When | Blocks on |
|---|---|---|
| `pre-commit` | each commit | A large file that grows past the hard cap; empty catch blocks; a new comment in production code |
| `pre-push` | each push | Branch over the hard MR size (default 800 changed lines) |
| Claude Code guard | agent runs push or MR/PR create | Same size check, exit 2 to the agent |
| Linter snippets | lint step | Nesting, params, function size, parameter mutation |

Env knobs: `MR_SIZE_SOFT`, `MR_SIZE_HARD`, `FILE_SOFT`, `FILE_HARD`, `MR_BASE`; one-off bypass
`CLEAN_CODE_SKIP=1`.

## Layout

```
SKILL.md        agent instructions
scripts/        install.sh
assets/rules    clean-code.md, ban-comments.md, small-mrs.md
assets/scripts  check-mr-size.sh, check-clean-code.sh, claude-pre-tool-guard.sh
assets/githooks pre-commit, pre-push
assets/lint     eslint, detekt, ruff snippets
```
