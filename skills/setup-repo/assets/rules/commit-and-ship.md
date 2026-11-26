# Commit and ship

Default unless the user says otherwise: finished work is committed, pushed, and in review.

| Step | Rule |
|---|---|
| Commit | Every green logical change, one concern per commit |
| Push | Right after the commit |
| MR/PR | Open or update one per branch |
| Merge, low-risk repo (`.mr-size` `risk: low`) | Merge when the user asked for the work; no extra approval |
| Merge, any other repo | Repo's normal approval and checks |

## Never

- `--no-verify`, `CLEAN_CODE_SKIP`, `SKIP`, `HUSKY=0`, `core.hooksPath` writes
- Force or delete push
- Leaving finished work uncommitted "to be safe"

## Parallel workers

- Each worker commits on its own branch or worktree ([implement §Parallel slices](../skills/implement/implement.md))
- Lead merges slices, then pushes and ships per the table

## Enforcement

- `scripts/guard/git-approval-guard.sh`: in a low-risk repo allows commit, push, merge; denies force push and hook bypasses; asks elsewhere
- Pre-commit and pre-push hooks still run; a blocked hook means fix, not bypass
