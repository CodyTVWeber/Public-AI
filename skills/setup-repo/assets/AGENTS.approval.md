### Approval gate

**Never auto-commit. Never auto-push.** Both need explicit approval, separately: approving a commit is not approving a push.

1. Show `git status` and `git diff --staged`, then wait for approval before `git commit`.
2. Ask again before `git push`.

`scripts/guard/git-approval-guard.sh` asks before every commit and push and denies `--no-verify`, `core.hooksPath` overrides and `CLEAN_CODE_SKIP`, `SKIP` and `HUSKY=0`. It backs the gate; it does not replace it. This block is for human-gated repos; unattended pipelines leave it out.

