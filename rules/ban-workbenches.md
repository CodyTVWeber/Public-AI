# Ban workbenches

Workbenches are not allowed. Never create, use, or merge them.

Merging workbenches together drops changes more than any other workflow seen. Ordinary branches, PRs, and `implement` workers (worktrees) keep the diffs.

**Scope:** every repo that consumes these rules. `setup-repo` copies this file into `.claude/rules/` with the rest.

## Instead

| Would use | Do this |
| --- | --- |
| Parallel workbenches | Parallel `implement` workers on branches or worktrees |
| Merge workbenches | Merge branches or PRs through the forge |
| A workbench as a scratch pad | A branch, then commit and push |

## Enforcement

- Agent judgment on every task. No script sees a workbench merge
- `setup-repo` install and bootstrap copy this file into the target `.claude/rules/`
