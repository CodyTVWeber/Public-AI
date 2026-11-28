# Ban worktrees

Git worktrees are not allowed. Never create, use, or merge them.

Merging worktrees together drops changes more than any other workflow seen. Stacked branches and PRs keep the diffs. Split agents onto disjoint scopes so they conflict as little as possible.

**Scope:** every repo that consumes these rules. `setup-repo` copies this file into `.claude/rules/` with the rest.

## Instead

| Would use | Do this |
| --- | --- |
| Parallel worktrees | Stacked branches and PRs; split agents onto disjoint scopes |
| Merge worktrees | Merge stacked PRs through the forge |
| A worktree as a scratch pad | A branch, then commit and push |

## Enforcement

- Agent judgment on every task. No script sees a worktree merge
- `setup-repo` install and bootstrap copy this file into the target `.claude/rules/`
